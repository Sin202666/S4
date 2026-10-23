--[[
	Module: UISetMgr/StrokeAdapt
	Description: UISetMgr 描边自适应：白名单判定、屏幕档/设备倍率、下限钳制、子树收集；祖先积跳过弹窗 AdaptScale 与 HUD 直写层
	Author: 林奥宇
	Created: 2026-09-02
	Last Modified: 2026-10-09

	仅供同目录 init require(script.StrokeAdapt)。业务请走 Utils.UISetMgr，不要直接 require 本文件。

	功能：
	- Enabled 总开关；false 时不收集、不改 Thickness（ScreenGui contain 缩放不受影响）
	- TagName：CollectionService 标签；打在 BillboardGui / SurfaceGui、其子节点、或父级 Model/Part 均可（不要打在 workspace 根或超大地图 Model）
	- BindStrokeTree 先听 DescendantAdded 再扫，并 defer 补扫（标签/流送到达时子树可能尚未 replicate）
	- ParentTypes / RootTypes 白名单 + SkipStrokeAdapt 决定是否适配
	- Thickness = BaseThickness × 祖先 UIScale 积（跳过窗口层 AdaptScale 与 HUD 直写）× ViewportContain(仅世界空间) × DisplaySizeScale × DeviceTypeScale，再按 DeviceTypeMinThickness 钳下限
	- 窗口层：ScreenGui/TipsGui 直接子弹窗 UIScale，以及 Main（或 ContentClip）下一层带 Mobie_Scale/PC_Scale 的名为 UIScale 的节点，不计入祖先积；根 contain 与嵌套控件 UIScale 仍乘
	- 世界空间 ViewportContain 与 ScreenGui 根 contain 同一套设计分辨率，不写 UIScale / Size / Adornee / CFrame
	- EnsureViewportListener：ViewportDisplaySize 刷全部；相机 ViewportSize 只刷世界空间描边
	- 一条 UIStroke 只属于最近 LayerCollector，扫描不穿越嵌套 BillboardGui/SurfaceGui
	- RefreshStrokes 只入队，返回时 Thickness 可能尚未写完（分片见 StrokeRefreshPump）
	- 单条入树仍立即 Apply；泵每帧只对预算内条目现算倍率并写入
	- 会计入祖先积的 UIScale：Scale 变化后停稳再补写 Thickness；Scale≤0 不乘进 Thickness，停在正数后再补。窗口层不监听、不补写
	- ThicknessEps：新旧粗细差不超过该值则跳过写入

	对 init 导出：IsEnabled / GetTagName / GetDesignSize / FindChildUIScale / IsRootTypeEnabled / IsWatchableCollector / UpdateUIStroke / BindStrokeTree / RefreshStrokes / ReleaseTrackedStrokes / EnsureViewportListener / DisconnectViewportListener

	加载方式（仅 UISetMgr/init）：
		local StrokeAdapt = require(script.StrokeAdapt)
]]

-- ============================================================================
-- 服务 / 模块引用
-- ============================================================================

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local GuiService = Utils.GuiService
local Log = Utils.Log
local StrokeRefreshPump = require(script.Parent.StrokeRefreshPump)
-- Utils 无 Workspace 键，顶部缓存服务
local Workspace = game:GetService("Workspace")

-- ============================================================================
-- 模块定义
-- ============================================================================

local StrokeAdapt = {}

-- ============================================================================
-- 常量 / 配置
-- ============================================================================

local BASE_THICKNESS_ATTR = "BaseThickness"
local SKIP_STROKE_ADAPT_ATTR = "SkipStrokeAdapt"
local UI_SCALE_CHILD_NAME = "UIScale"
local MOBILE_SCALE_ATTR = "Mobie_Scale"
local PC_SCALE_ATTR = "PC_Scale"
local MAIN_FRAME_NAME = "Main"
local CONTENT_CLIP_NAME = "ContentClip"
local FALLBACK_DESIGN_SIZE = Vector2.new(1920, 1021)
local DEFAULT_THICKNESS_EPS = 0.01
-- 长于一帧，短于业务停手：Tween 逐帧改 Scale 时只保留最后一次，停稳后再算
local SCALE_SETTLE_SEC = 0.05
-- 与弹窗动画跳过阈值同量级：近零倍率不写入，停稳后的目标倍率仍写
local SCALE_WRITE_MIN = 0.01

export type StrokeHost = {
	isAdaptEnabled: () -> boolean,
	strokes: { [UIStroke]: boolean },
	strokeRootsBound: { [Instance]: boolean },
	connections: { RBXScriptConnection },
	isLive: () -> boolean,
}

export type ViewportHooks = {
	onDisplaySizeChanged: () -> (),
	onWorldSpaceViewportChanged: () -> (),
}

--[[
	描边自适应配置（程序调参，不进 Excel）
	- Enabled：总开关；false 时不收集 UIStroke、不改 Thickness
	- TagName：CollectionService 标签名；打在 Gui 自身、其子节点、或父级 Model/Part 均可
	- ParentTypes：stroke.Parent.ClassName 列在表中才启用
	- RootTypes：最近 LayerCollector 类型列在表中才启用
	- WorldSpaceUseViewportContain：BillboardGui/SurfaceGui 再乘视口 contain（与 ScreenGui 根缩放同一设计分辨率）
	- DesignSize：世界空间 contain 与 ScreenGui 根缩放共用的设计分辨率（init 经 GetDesignSize 读取）
	- DisplaySizeScale：ViewportDisplaySize 屏幕物理尺寸档倍率（非手机/PC 身份）
	- DeviceTypeScale / DeviceTypeMinThickness：Utils.DeviceType 输入设备倍率与最终 Thickness 下限（0 = 不钳制）
	- RefreshPerFrame：分片刷新每帧最多写多少条（<=0 表示本帧不按条数截断）
	- RefreshTimeBudget：分片刷新单帧秒数上限（<=0 表示不按时间截断）
	- ThicknessEps：|新-旧|<=该值则不写 Thickness
]]
local STROKE_ADAPT_CONFIG = {
	Enabled = true,
	TagName = "StrokeAdapt",
	WorldSpaceUseViewportContain = true,
	DesignSize = FALLBACK_DESIGN_SIZE,
	RefreshPerFrame = 250,
	RefreshTimeBudget = 0.002,
	ThicknessEps = DEFAULT_THICKNESS_EPS,
	ParentTypes = {
		Frame = false,
		ScrollingFrame = false,
		CanvasGroup = false,
		TextLabel = true,
		TextButton = false,
		TextBox = false,
		ImageLabel = false,
		ImageButton = false,
		ViewportFrame = false,
		VideoFrame = false,
	},
	RootTypes = {
		ScreenGui = true,
		BillboardGui = true,
		SurfaceGui = true,
	},
	DisplaySizeScale = {
		[Enum.DisplaySize.Small] = 1,
		[Enum.DisplaySize.Medium] = 1,
		[Enum.DisplaySize.Large] = 1,
	},
	DeviceTypeScale = {
		Mobile = 1,
		Pc = 1,
		Gamepad = 1,
	},
	DeviceTypeMinThickness = {
		Mobile = 0,
		Pc = 0,
		Gamepad = 0,
	},
}

-- ============================================================================
-- 私有变量
-- ============================================================================

-- DeviceType 延迟取短名，避免 UISetMgr 加载期与 Utils 成环
local _deviceType: any = nil
local _viewportHooks: ViewportHooks? = nil
local _viewportConn: RBXScriptConnection? = nil
local _cameraConn: RBXScriptConnection? = nil
local _cameraChangedConn: RBXScriptConnection? = nil

type ScaleWatch = {
	strokes: { [UIStroke]: boolean },
	conn: RBXScriptConnection,
	token: number,
}

-- 计入祖先积的 UIScale → 依赖它的描边。窗口层不进入此表
local _scaleWatches: { [UIScale]: ScaleWatch } = {}
local _strokeScales: { [UIStroke]: { [UIScale]: boolean } } = {}
local _strokeDestroyConn: { [UIStroke]: RBXScriptConnection } = {}

-- 停稳回调在函数体之后赋值，避免与祖先积计算互相引用
local _applyStrokeScale: (UIStroke) -> ()

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	延迟取 DeviceType 短名
	@return any - Utils.DeviceType（IsMobile / IsPc / IsGamepad）
]]
local function _getDeviceType(): any
	if not _deviceType then
		_deviceType = Utils.DeviceType
	end
	return _deviceType
end

--[[
	解析当前输入设备键（Mobile > Pc > Gamepad）；三者皆非时 nil
	@return string? - "Mobile" / "Pc" / "Gamepad"；无法判定时 nil
]]
local function _getDeviceTypeKey(): string?
	local deviceType = _getDeviceType()
	if deviceType.IsMobile() then
		return "Mobile"
	end
	if deviceType.IsPc() then
		return "Pc"
	end
	if deviceType.IsGamepad() then
		return "Gamepad"
	end
	return nil
end

--[[
	读取 ViewportDisplaySize 对应的描边倍率
	@return number - 配置倍率；未知档回退 1
]]
local function _getDisplaySizeScale(): number
	local scale = STROKE_ADAPT_CONFIG.DisplaySizeScale[GuiService.ViewportDisplaySize]
	if typeof(scale) == "number" then
		return scale
	end
	return 1
end

--[[
	读取 DeviceType 对应的描边倍率
	@return number - 配置倍率；无法判定时 1
]]
local function _getDeviceTypeScale(): number
	local key = _getDeviceTypeKey()
	if not key then
		return 1
	end
	local scale = STROKE_ADAPT_CONFIG.DeviceTypeScale[key]
	if typeof(scale) == "number" then
		return scale
	end
	return 1
end

--[[
	读取 DeviceType 对应的最终 Thickness 下限
	@return number - 下限像素；无法判定或未配置时 0
]]
local function _getDeviceMinThickness(): number
	local key = _getDeviceTypeKey()
	if not key then
		return 0
	end
	local minThickness = STROKE_ADAPT_CONFIG.DeviceTypeMinThickness[key]
	if typeof(minThickness) == "number" then
		return minThickness
	end
	return 0
end

--[[
	读取配置中的设计分辨率（非法时回退 FALLBACK_DESIGN_SIZE）
	@return Vector2 - 设计宽高
]]
local function _getDesignSize(): Vector2
	local design = STROKE_ADAPT_CONFIG.DesignSize
	if typeof(design) == "Vector2" and design.X > 0 and design.Y > 0 then
		return design
	end
	return FALLBACK_DESIGN_SIZE
end

--[[
	读取世界空间视口 contain（与 ScreenGui 根缩放同一设计分辨率）
	@return number - contain 倍率；无相机或尺寸非法时 1
]]
local function _getViewportContainScale(): number
	if STROKE_ADAPT_CONFIG.WorldSpaceUseViewportContain ~= true then
		return 1
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return 1
	end
	local vp = cam.ViewportSize
	if vp.X <= 0 or vp.Y <= 0 then
		return 1
	end
	local design = _getDesignSize()
	return math.min(vp.X / design.X, vp.Y / design.Y)
end

--[[
	由设计粗细与祖先 UIScale 积计算最终 Thickness（含屏幕档、设备倍率与下限）
	@param base number - BaseThickness（1K 设计值）
	@param uiScale number - 祖先 UIScale 乘积（自动路径已跳过窗口层；世界空间调用方已乘 ViewportContain）
	@return number - 最终像素 Thickness
]]
local function _computeThickness(base: number, uiScale: number): number
	local scaled = base * uiScale * _getDisplaySizeScale() * _getDeviceTypeScale()
	local minThickness = _getDeviceMinThickness()
	if minThickness > 0 then
		return math.max(minThickness, scaled)
	end
	return scaled
end

--[[
	新旧 Thickness 差不超过配置 eps 则跳过写入，避免无意义布局失效
	@param obj UIStroke - 目标描边
	@param newThickness number - 计算后的像素粗细
]]
local function _trySetThickness(obj: UIStroke, newThickness: number)
	local eps = STROKE_ADAPT_CONFIG.ThicknessEps
	if typeof(eps) ~= "number" or eps < 0 then
		eps = DEFAULT_THICKNESS_EPS
	end
	if math.abs(obj.Thickness - newThickness) <= eps then
		return
	end
	obj.Thickness = newThickness
end

--[[
	查找 Parent 下的 UIScale（优先名称为 UIScale 的子节点）
	@param parent Instance - 查找起点
	@return UIScale? - 找到的 UIScale，不存在时 nil
]]
local function _findChildUIScale(parent: Instance): UIScale?
	local named = parent:FindFirstChild(UI_SCALE_CHILD_NAME)
	if named and named:IsA("UIScale") then
		return named
	end
	local any = parent:FindFirstChildOfClass("UIScale")
	if any and any:IsA("UIScale") then
		return any
	end
	return nil
end

--[[
	从 inst 向上找到最近的 LayerCollector
	@param inst Instance - 起点（通常为 UIStroke 或其 Parent）
	@return LayerCollector? - 最近根；无祖先时 nil
]]
local function _getNearestLayerCollector(inst: Instance): LayerCollector?
	local current: Instance? = inst
	while current do
		if current:IsA("LayerCollector") then
			return current
		end
		current = current.Parent
	end
	return nil
end

--[[
	描边是否归属指定扫描根（最近 LayerCollector == root）
	@param stroke UIStroke - 目标描边
	@param root Instance - 绑定的 LayerCollector 根
	@return boolean - 归属该根时 true
]]
local function _isOwnedByRoot(stroke: UIStroke, root: Instance): boolean
	return _getNearestLayerCollector(stroke) == root
end

--[[
	是否应对该 UIStroke 做自动 Thickness 适配
	@param stroke UIStroke - 目标描边
	@return boolean - 满足白名单且未 SkipStrokeAdapt 时 true
]]
local function _shouldAdaptStroke(stroke: UIStroke): boolean
	if STROKE_ADAPT_CONFIG.Enabled ~= true then
		return false
	end
	if stroke:GetAttribute(SKIP_STROKE_ADAPT_ATTR) == true then
		return false
	end
	local parent = stroke.Parent
	if not parent then
		return false
	end
	if STROKE_ADAPT_CONFIG.ParentTypes[parent.ClassName] ~= true then
		return false
	end
	local root = _getNearestLayerCollector(stroke)
	if not root then
		return false
	end
	return STROKE_ADAPT_CONFIG.RootTypes[root.ClassName] == true
end

--[[
	是否为全屏比例 Frame（与 UISetMgr 弹窗二次适配跳过条件一致）
	@param frame Frame - 待判定 Frame
	@return boolean - Size 的 Scale 均为 1 时 true
]]
local function _isFullScreenFrame(frame: Frame): boolean
	return frame.Size.X.Scale == 1 and frame.Size.Y.Scale == 1
end

--[[
	UIScale 是否带 HUD 直写用的设备倍率属性
	@param scaleInst UIScale - 待检测节点
	@return boolean - Mobie_Scale 或 PC_Scale 为 number 时 true
]]
local function _hasHudDeviceScaleAttr(scaleInst: UIScale): boolean
	local mobileScale = scaleInst:GetAttribute(MOBILE_SCALE_ATTR)
	local pcScale = scaleInst:GetAttribute(PC_SCALE_ATTR)
	return typeof(mobileScale) == "number" or typeof(pcScale) == "number"
end

--[[
	Frame 是否为 Main 或 Main.ContentClip 的直接子（HUD 一层）
	@param host Frame - UIScale 的 Parent
	@return boolean - 位于 HUD 扫描层时 true
]]
local function _isMainHudHost(host: Frame): boolean
	local parent = host.Parent
	if not parent or not parent:IsA("Frame") then
		return false
	end
	if parent.Name == MAIN_FRAME_NAME then
		local collector = parent.Parent
		return collector ~= nil and collector:IsA("ScreenGui")
	end
	if parent.Name == CONTENT_CLIP_NAME then
		local main = parent.Parent
		if not main or main.Name ~= MAIN_FRAME_NAME or not main:IsA("Frame") then
			return false
		end
		local collector = main.Parent
		return collector ~= nil and collector:IsA("ScreenGui")
	end
	return false
end

--[[
	是否为 Main 下一层 HUD 直写 UIScale（不计入描边祖先积）
	@param scaleInst UIScale - 待判定的 UIScale
	@return boolean - HUD 覆盖层时 true
]]
local function _isHudOverlayUiScale(scaleInst: UIScale): boolean
	if scaleInst.Name ~= UI_SCALE_CHILD_NAME then
		return false
	end
	if not _hasHudDeviceScaleAttr(scaleInst) then
		return false
	end
	local host = scaleInst.Parent
	if not host or not host:IsA("Frame") then
		return false
	end
	return _isMainHudHost(host)
end

--[[
	是否为窗口层 UIScale（弹窗 AdaptScale 或 HUD 直写层）
	根 contain 与更深层按钮/红点 UIScale 返回 false，仍计入祖先积
	@param scaleInst UIScale - 待判定的 UIScale
	@return boolean - 属于窗口层时应从描边祖先积中跳过
]]
local function _isWindowUiScale(scaleInst: UIScale): boolean
	local host = scaleInst.Parent
	if host and host:IsA("Frame") then
		local collector = host.Parent
		if collector and collector:IsA("ScreenGui") and not _isFullScreenFrame(host) then
			return true
		end
	end
	return _isHudOverlayUiScale(scaleInst)
end

--[[
	从某颗 UIScale 的监听表移除描边；没有剩余描边时断开监听并作废尚未执行的停稳补写
	@param scaleInst UIScale - 计入祖先积的 UIScale
	@param stroke UIStroke - 不再依赖它的描边
]]
local function _detachStrokeFromScale(scaleInst: UIScale, stroke: UIStroke)
	local watch = _scaleWatches[scaleInst]
	if not watch then
		return
	end
	watch.strokes[stroke] = nil
	if next(watch.strokes) ~= nil then
		return
	end
	watch.token += 1
	watch.conn:Disconnect()
	_scaleWatches[scaleInst] = nil
end

--[[
	卸掉描边在计入项上的监听。销毁或移出适配集合时调用，避免补写已离树的描边
	@param stroke UIStroke - 目标描边
]]
local function _releaseStrokeWatch(stroke: UIStroke)
	local scales = _strokeScales[stroke]
	_strokeScales[stroke] = nil
	if scales then
		for scaleInst in scales do
			_detachStrokeFromScale(scaleInst, stroke)
		end
	end
	local destroyConn = _strokeDestroyConn[stroke]
	if destroyConn then
		_strokeDestroyConn[stroke] = nil
		destroyConn:Disconnect()
	end
end

--[[
	Scale 停稳后再补写依赖这颗 UIScale 的描边。逐帧 Tween 会不断推后，不会把中间倍率写进 Thickness
	@param scaleInst UIScale - 刚发生变化的计入项
]]
local function _scheduleScaleSettle(scaleInst: UIScale)
	local watch = _scaleWatches[scaleInst]
	if not watch then
		return
	end
	watch.token += 1
	local token = watch.token
	task.delay(SCALE_SETTLE_SEC, function()
		local live = _scaleWatches[scaleInst]
		if not live or live.token ~= token then
			return
		end
		local pending: { UIStroke } = {}
		for stroke in live.strokes do
			table.insert(pending, stroke)
		end
		for _, stroke in pending do
			if stroke.Parent then
				_applyStrokeScale(stroke)
			else
				_releaseStrokeWatch(stroke)
			end
		end
	end)
end

--[[
	把描边挂到当前计入祖先积的 UIScale 上。窗口层不挂。Scale≤0 也挂，停到正数后再补写
	@param stroke UIStroke - 目标描边
	@param included { [UIScale]: boolean } - 本次祖先链上计入的 UIScale
]]
local function _syncStrokeScaleWatch(stroke: UIStroke, included: { [UIScale]: boolean })
	local prev = _strokeScales[stroke]
	if prev then
		for scaleInst in prev do
			if not included[scaleInst] then
				_detachStrokeFromScale(scaleInst, stroke)
			end
		end
	end
	if next(included) == nil then
		_strokeScales[stroke] = nil
		local destroyConn = _strokeDestroyConn[stroke]
		if destroyConn then
			_strokeDestroyConn[stroke] = nil
			destroyConn:Disconnect()
		end
		return
	end
	for scaleInst in included do
		local watch = _scaleWatches[scaleInst]
		if not watch then
			local conn = scaleInst:GetPropertyChangedSignal("Scale"):Connect(function()
				_scheduleScaleSettle(scaleInst)
			end)
			local created: ScaleWatch = {
				strokes = {},
				conn = conn,
				token = 0,
			}
			_scaleWatches[scaleInst] = created
			watch = created
		end
		watch.strokes[stroke] = true
	end
	_strokeScales[stroke] = included
	if _strokeDestroyConn[stroke] then
		return
	end
	_strokeDestroyConn[stroke] = stroke.Destroying:Connect(function()
		_releaseStrokeWatch(stroke)
	end)
end

--[[
	从 Parent 走到最近 LayerCollector，连乘沿途各层 UIScale.Scale（跳过弹窗 AdaptScale 与 HUD 直写层）
	顺手把计入项登记到停稳补写。任一计入项 Scale≤SCALE_WRITE_MIN 时第二返回值为 true，调用方不得把该乘积写入 Thickness
	@param stroke UIStroke - 目标描边
	@return number - 祖先 UIScale 乘积（不含窗口层）；无 UIScale 时为 1
	@return boolean - 有计入项仍近零时 true
]]
local function _getAncestorUiScaleProduct(stroke: UIStroke): (number, boolean)
	local product = 1
	local pending = false
	local included: { [UIScale]: boolean } = {}
	local current: Instance? = stroke.Parent
	while current do
		local scaleInst = _findChildUIScale(current)
		if scaleInst and not _isWindowUiScale(scaleInst) then
			included[scaleInst] = true
			if scaleInst.Scale <= SCALE_WRITE_MIN then
				pending = true
			end
			product *= scaleInst.Scale
		end
		if current:IsA("LayerCollector") then
			break
		end
		current = current.Parent
	end
	_syncStrokeScaleWatch(stroke, included)
	return product, pending
end

--[[
	计算泵 / 立即 Apply 共用的 uiScale（祖先积跳过窗口层 × 世界空间 ViewportContain）
	@param stroke UIStroke - 目标描边
	@return number? - 正数倍率；无法计算或非法时 nil
]]
local function _computeQueuedUiScale(stroke: UIStroke): number?
	local product, pending = _getAncestorUiScaleProduct(stroke)
	if pending or product <= 0 then
		return nil
	end
	local root = _getNearestLayerCollector(stroke)
	if root and not root:IsA("ScreenGui") then
		product *= _getViewportContainScale()
	end
	if product <= 0 then
		return nil
	end
	return product
end

--[[
	对单个描边立即应用当前祖先倍率与设备微调（入树路径，允许 FindFirstChild）
	@param stroke UIStroke - 目标描边
]]
_applyStrokeScale = function(stroke: UIStroke)
	local product = _computeQueuedUiScale(stroke)
	if not product then
		return
	end
	StrokeAdapt.UpdateUIStroke(stroke, product)
end

--[[
	将 UIStroke 纳入宿主缓存（白名单 / SkipStrokeAdapt / 归属根 不满足则跳过）
	@param host StrokeHost - 注册项描边宿主
	@param stroke UIStroke - 目标描边
	@param root Instance - 扫描根 LayerCollector
]]
local function _bindStroke(host: StrokeHost, stroke: UIStroke, root: Instance)
	if not _isOwnedByRoot(stroke, root) then
		return
	end
	if not _shouldAdaptStroke(stroke) then
		return
	end
	host.strokes[stroke] = true
end

--[[
	从宿主缓存移除 UIStroke
	@param host StrokeHost - 注册项描边宿主
	@param stroke UIStroke - 目标描边
]]
local function _unbindStroke(host: StrokeHost, stroke: UIStroke)
	host.strokes[stroke] = nil
	_releaseStrokeWatch(stroke)
end

--[[
	扫描 root 下已有 UIStroke 并纳入缓存（不写 Thickness，由 Refresh 统一应用）
	@param host StrokeHost - 注册项描边宿主
	@param root Instance - LayerCollector 根（ScreenGui / TipsGui / BillboardGui / SurfaceGui）
]]
local function _scanStrokes(host: StrokeHost, root: Instance)
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("UIStroke") then
			_bindStroke(host, inst, root)
		end
	end
end

--[[
	绑定当前相机 ViewportSize，供世界空间描边 contain 随窗口变化刷新
]]
local function _bindCurrentCamera()
	if _cameraConn then
		_cameraConn:Disconnect()
		_cameraConn = nil
	end
	local cam = Workspace.CurrentCamera
	if not cam then
		return
	end
	_cameraConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local hooks = _viewportHooks
		if hooks then
			hooks.onWorldSpaceViewportChanged()
		end
	end)
end

-- ============================================================================
-- 公共函数（仅 UISetMgr/init 使用）
-- ============================================================================

--[[
	描边自适应总开关是否打开
	@return boolean - STROKE_ADAPT_CONFIG.Enabled 为 true 时 true
]]
function StrokeAdapt.IsEnabled(): boolean
	return STROKE_ADAPT_CONFIG.Enabled == true
end

--[[
	描边自适应 CollectionService 标签名
	@return string - 配置 TagName；空或缺省时为 StrokeAdapt
]]
function StrokeAdapt.GetTagName(): string
	local tagName = STROKE_ADAPT_CONFIG.TagName
	if typeof(tagName) == "string" and tagName ~= "" then
		return tagName
	end
	return "StrokeAdapt"
end

--[[
	描边 contain / ScreenGui 根缩放共用的设计分辨率
	@return Vector2 - STROKE_ADAPT_CONFIG.DesignSize；非法时回退 1920×1021
]]
function StrokeAdapt.GetDesignSize(): Vector2
	return _getDesignSize()
end

--[[
	查找 Parent 下的 UIScale（优先名称为 UIScale 的子节点）
	@param parent Instance - 查找起点
	@return UIScale? - 找到的 UIScale，不存在时 nil
]]
function StrokeAdapt.FindChildUIScale(parent: Instance): UIScale?
	return _findChildUIScale(parent)
end

--[[
	根 LayerCollector 类型是否在 RootTypes 白名单中
	@param className string - Instance.ClassName
	@return boolean - 配置为 true 时 true
]]
function StrokeAdapt.IsRootTypeEnabled(className: string): boolean
	if not StrokeAdapt.IsEnabled() then
		return false
	end
	return STROKE_ADAPT_CONFIG.RootTypes[className] == true
end

--[[
	是否为 WatchPlayerGui 应自动注册的世界空间 Gui
	@param inst Instance - 待判定实例
	@return boolean - BillboardGui 或 SurfaceGui 且 RootTypes 启用
]]
function StrokeAdapt.IsWatchableCollector(inst: Instance): boolean
	if not inst:IsA("BillboardGui") and not inst:IsA("SurfaceGui") then
		return false
	end
	return StrokeAdapt.IsRootTypeEnabled(inst.ClassName)
end

--[[
	按祖先 UIScale 积、屏幕档与设备倍率更新 Thickness；首次调用写入 BaseThickness
	@param obj UIStroke - 目标描边
	@param uiScale number - 祖先 UIScale 积（不要预乘设备倍率）；自动路径已剔除窗口层且本函数不再乘 ViewportContain；直接调用时自行算好，不会再跳过窗口层或乘 ViewportContain
]]
function StrokeAdapt.UpdateUIStroke(obj: UIStroke, uiScale: number)
	if not StrokeAdapt.IsEnabled() then
		return
	end
	if not obj or not obj:IsA("UIStroke") then
		return
	end
	if typeof(uiScale) ~= "number" or uiScale <= 0 then
		return
	end

	local base = obj:GetAttribute(BASE_THICKNESS_ATTR)
	if typeof(base) ~= "number" then
		base = obj.Thickness
		obj:SetAttribute(BASE_THICKNESS_ATTR, base)
	end
	_trySetThickness(obj, _computeThickness(base :: number, uiScale))
end

--[[
	监听 root 子树的 UIStroke 增删并做首次扫描（对同一 root 幂等）
	@param host StrokeHost - 注册项描边宿主（isAdaptEnabled 须读 entry 实时值）
	@param root Instance - LayerCollector 根
]]
function StrokeAdapt.BindStrokeTree(host: StrokeHost, root: Instance)
	if not StrokeAdapt.IsEnabled() then
		return
	end
	if host.strokeRootsBound[root] then
		return
	end
	host.strokeRootsBound[root] = true

	-- 先听后扫：CollectionService / 流送到达时 Gui 已在 DataModel，子树可能尚未 replicate
	table.insert(host.connections, root.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("UIScale") then
			-- 弹出时才创建的 UIScale：先挂上监听。Scale 仍近零则不写 Thickness
			task.defer(function()
				if not host.isLive() or not host.isAdaptEnabled() or not descendant.Parent then
					return
				end
				local scaleInst = descendant :: UIScale
				if _isWindowUiScale(scaleInst) then
					return
				end
				local hostInst = scaleInst.Parent
				if not hostInst then
					return
				end
				for stroke in host.strokes do
					if stroke.Parent and stroke:IsDescendantOf(hostInst) then
						_applyStrokeScale(stroke)
					end
				end
			end)
			return
		end
		if not descendant:IsA("UIStroke") then
			return
		end
		-- 同帧创建方常在 Parent 之后才写设计 Thickness，defer 再快照 BaseThickness
		task.defer(function()
			if not host.isLive() then
				return
			end
			if not host.isAdaptEnabled() then
				return
			end
			if not descendant.Parent then
				return
			end
			_bindStroke(host, descendant, root)
			if host.strokes[descendant] then
				_applyStrokeScale(descendant)
			end
		end)
	end))

	table.insert(host.connections, root.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("UIStroke") then
			_unbindStroke(host, descendant)
			return
		end
		if not descendant:IsA("UIScale") then
			return
		end
		local scaleInst = descendant :: UIScale
		local watch = _scaleWatches[scaleInst]
		if not watch then
			return
		end
		watch.token += 1
		watch.conn:Disconnect()
		_scaleWatches[scaleInst] = nil
		for stroke in watch.strokes do
			local scales = _strokeScales[stroke]
			if scales then
				scales[scaleInst] = nil
			end
		end
	end))

	_scanStrokes(host, root)
	-- 本帧剩余 replicate 完成后补扫，避免只扫到空壳 BillboardGui/SurfaceGui
	task.defer(function()
		if not host.isLive() then
			return
		end
		if not host.isAdaptEnabled() then
			return
		end
		_scanStrokes(host, root)
		StrokeAdapt.RefreshStrokes(host)
		if root:IsA("ScreenGui") then
			return
		end
		local total = 0
		local bound = 0
		for _, inst in ipairs(root:GetDescendants()) do
			if inst:IsA("UIStroke") then
				total += 1
				if host.strokes[inst] then
					bound += 1
				end
			end
		end
		if total == 0 then
			Log.warn("[UISetMgr] 描边适配已注册但无 UIStroke:", root:GetFullName())
		elseif bound < total then
			Log.warn("[UISetMgr] 描边适配", root:GetFullName(), string.format("%d/%d 条未纳入（检查 ParentTypes / SkipStrokeAdapt）", bound, total))
		end
	end)
end

--[[
	将宿主描边合入分片刷新队列（异步：返回时 Thickness 可能尚未写完；单条入树仍立即 Apply）
	@param host StrokeHost - 注册项描边宿主
]]
function StrokeAdapt.RefreshStrokes(host: StrokeHost)
	StrokeRefreshPump.Schedule(host)
end

--[[
	卸掉一批描边的停稳监听。注销 ScreenGui 或关闭 adaptStrokes 时由 init 调用，避免补写已不再适配的描边
	@param strokes { [UIStroke]: boolean } - 宿主描边集合；函数内不修改该表
]]
function StrokeAdapt.ReleaseTrackedStrokes(strokes: { [UIStroke]: boolean })
	for stroke in strokes do
		_releaseStrokeWatch(stroke)
	end
end

--[[
	确保已监听 ViewportDisplaySize 与相机 ViewportSize（幂等）
	@param hooks ViewportHooks - onDisplaySizeChanged 刷全部；onWorldSpaceViewportChanged 只刷世界空间描边
]]
function StrokeAdapt.EnsureViewportListener(hooks: ViewportHooks)
	_viewportHooks = hooks
	if not _viewportConn then
		_viewportConn = GuiService:GetPropertyChangedSignal("ViewportDisplaySize"):Connect(function()
			local liveHooks = _viewportHooks
			if liveHooks then
				liveHooks.onDisplaySizeChanged()
			end
		end)
	end
	if not _cameraChangedConn then
		_cameraChangedConn = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(_bindCurrentCamera)
		_bindCurrentCamera()
	end
end

--[[
	断开视口与相机监听（无注册项时由 init 调用）
]]
function StrokeAdapt.DisconnectViewportListener()
	_viewportHooks = nil
	StrokeRefreshPump.Stop()
	if _viewportConn then
		_viewportConn:Disconnect()
		_viewportConn = nil
	end
	if _cameraConn then
		_cameraConn:Disconnect()
		_cameraConn = nil
	end
	if _cameraChangedConn then
		_cameraChangedConn:Disconnect()
		_cameraChangedConn = nil
	end
end

StrokeRefreshPump.SetHooks({
	isEnabled = StrokeAdapt.IsEnabled,
	getRefreshPerFrame = function()
		local n = STROKE_ADAPT_CONFIG.RefreshPerFrame
		if typeof(n) ~= "number" or n <= 0 then
			return math.huge
		end
		return n
	end,
	getRefreshTimeBudget = function()
		local n = STROKE_ADAPT_CONFIG.RefreshTimeBudget
		if typeof(n) ~= "number" or n <= 0 then
			return 0
		end
		return n
	end,
	computeUiScale = _computeQueuedUiScale,
	apply = StrokeAdapt.UpdateUIStroke,
})

return StrokeAdapt
