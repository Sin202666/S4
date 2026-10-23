--[[
	Module: LineGuide
	Description: 新手引导场景表现：引导线（ModelRes/Guide/引导线，Beam 从目标连到本地角色）与场景高光（ModelRes/Guide/引导高光）
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- Apply(lineCfg, highlightCfg)：按 workspace 下点分路径找目标；引导线指到目标可见位置（属性 Pivot，否则包围盒中心；WorldPivot 可能脱离几何），Beam.Attachment1 接角色 HumanoidRootPart
	- 目标未流入客户端（StreamingEnabled）时按 RESOLVE_RETRY 重试，阶段切换即作废旧查找
	- line.gui：PlayerGui 下 SurfaceGui 内控件路径（如门上解锁按钮 "GateDisplay_2.Holder.UnlockBtn"），引导线改指控件中心
	  按 SurfaceGui.Face 把控件在画布中的位置换算到承载部件侧面（外移 FACE_OFFSET）；只支持 Front/Back/Left/Right，顶 / 底面或控件未找到时指可见位置
	- 角色重生后自动重挂角色端 Attachment
	- SetVisible：整体显隐（对局中由 SystemGuide 关闭），不丢目标

	约束：
	- 纯表现：只摆本模块克隆出的引导线 Part，不写角色位姿 / 镜头；资源模板克隆一份使用，不移动 ReplicatedStorage 内原件

	加载（仅 SystemGuide 内部使用）：
		local LineGuide = require(script.LineGuide)
		LineGuide.Init()
		LineGuide.Apply({ path = "World.Zone_1.Tables.Table_L1_1" }, nil)
		LineGuide.SetVisible(false)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Workspace = game:GetService("Workspace")
local LocalPlayer = Utils.LocalPlayer
local AssetPaths = Utils.AssetPaths
local Log = Utils.Log

local LineGuide = {}

local GUIDE_RES_PATH = "ModelRes/Guide"
local LINE_TEMPLATE_NAME = "引导线"
local HIGHLIGHT_TEMPLATE_NAME = "引导高光"
local BEAM_NAME = "Beam"
local PLAYER_ATTACHMENT_NAME = "GuideLine_PlayerAttachment"
local RESOLVE_RETRY = 1
local ROOT_WAIT_SEC = 10
-- 引导线终点离开表面的距离，避免与门面 SurfaceGui 重叠闪烁
local FACE_OFFSET = 0.5
-- 侧面在部件局部空间的外法线与画布 X 正方向（从外侧看向该面时的右方）；画布上方恒为局部 +Y
local FACE_AXES = {
	[Enum.NormalId.Front] = { normal = Vector3.new(0, 0, -1), right = Vector3.new(-1, 0, 0) },
	[Enum.NormalId.Back] = { normal = Vector3.new(0, 0, 1), right = Vector3.new(1, 0, 0) },
	[Enum.NormalId.Left] = { normal = Vector3.new(-1, 0, 0), right = Vector3.new(0, 0, 1) },
	[Enum.NormalId.Right] = { normal = Vector3.new(1, 0, 0), right = Vector3.new(0, 0, -1) },
}

local _inited = false
local _visible = true
local _version = 0
local _line: BasePart? = nil
local _beam: Beam? = nil
local _highlight: Highlight? = nil
local _lineTarget: Instance? = nil
local _lineGui: GuiObject? = nil
local _lineGuiConn: RBXScriptConnection? = nil
local _highlightTarget: Instance? = nil
local _playerAttachment: Attachment? = nil

--[[
	按 "A.B.C" 从 workspace 查找实例
	@param path string - workspace 下点分路径
	@return Instance? - 找到的 Model / BasePart；未流入或不存在为 nil
]]
local function _findWorld(path: string): Instance?
	local node: Instance? = Workspace
	for _, name in ipairs(string.split(path, ".")) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	if node and node:IsA("PVInstance") then
		return node
	end
	return nil
end

--[[
	按 "A.B.C" 从 PlayerGui 查找界面控件
	@param path string - PlayerGui 下点分路径
	@return GuiObject? - 找到的控件；不存在为 nil
]]
local function _findGui(path: string): GuiObject?
	local node: Instance? = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for _, name in ipairs(string.split(path, ".")) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	if node and node:IsA("GuiObject") then
		return node
	end
	return nil
end

--[[
	引导线要落到的世界位姿。比赛桌 WorldPivot 统一停在空中（几何在地面），不能用 GetPivot。
	@param target Instance - workspace 下的 Model / BasePart
	@return CFrame - 引导线 Part 的位姿；有 Vector3 属性 Pivot 时用它（桌面中心），Model 否则用包围盒中心
]]
local function _getAimCFrame(target: Instance): CFrame
	local marked = target:GetAttribute("Pivot")
	if typeof(marked) == "Vector3" then
		return CFrame.new(marked)
	end
	if target:IsA("Model") then
		local ok, cf = pcall(function()
			return target:GetBoundingBox()
		end)
		if ok and typeof(cf) == "CFrame" then
			return cf
		end
	end
	return (target :: PVInstance):GetPivot()
end

--[[
	SurfaceGui 内控件中心对应的世界 CFrame（只支持侧面；朝向沿用部件）
	@param gui GuiObject - SurfaceGui 内的控件
	@param fallback Instance - 引导线 path 目标；SurfaceGui 无 Adornee 时用作承载部件
	@return CFrame? - 控件中心外移 FACE_OFFSET 后的世界 CFrame；顶 / 底面、未布局或找不到部件为 nil
]]
local function _getSurfacePoint(gui: GuiObject, fallback: Instance): CFrame?
	local surface = gui:FindFirstAncestorWhichIsA("SurfaceGui")
	if not surface then
		return nil
	end
	local part = surface.Adornee or surface.Parent
	if not (part and part:IsA("BasePart")) then
		part = fallback
	end
	if not (part and part:IsA("BasePart")) then
		return nil
	end
	local axes = FACE_AXES[surface.Face]
	local canvas = surface.AbsoluteSize
	if not axes or canvas.X <= 0 or canvas.Y <= 0 then
		return nil
	end
	local center = gui.AbsolutePosition + gui.AbsoluteSize / 2
	local u = center.X / canvas.X - 0.5
	local v = 0.5 - center.Y / canvas.Y
	local size = part.Size
	local depth = math.abs(axes.normal:Dot(size)) / 2 + FACE_OFFSET
	local width = math.abs(axes.right:Dot(size))
	local offset = axes.normal * depth + axes.right * (u * width) + Vector3.yAxis * (v * size.Y)
	return part.CFrame * CFrame.new(offset)
end

--[[
	克隆引导线与高光模板（只建一次）
]]
local function _createVisuals()
	local res = AssetPaths.Resolve(GUIDE_RES_PATH, AssetPaths.Scope.Shared)
	local lineTemplate = res and res:FindFirstChild(LINE_TEMPLATE_NAME)
	if lineTemplate and lineTemplate:IsA("BasePart") then
		local line = lineTemplate:Clone()
		local beam = line:FindFirstChild(BEAM_NAME)
		_line = line
		_beam = if beam and beam:IsA("Beam") then beam else nil
	else
		Log.warn("LineGuide 找不到引导线模板", GUIDE_RES_PATH, LINE_TEMPLATE_NAME)
	end
	local highlightTemplate = res and res:FindFirstChild(HIGHLIGHT_TEMPLATE_NAME)
	if highlightTemplate and highlightTemplate:IsA("Highlight") then
		_highlight = highlightTemplate:Clone()
	else
		Log.warn("LineGuide 找不到高光模板", GUIDE_RES_PATH, HIGHLIGHT_TEMPLATE_NAME)
	end
end

--[[
	按显隐开关与目标写引导线 / 高光的 Parent 与连接
]]
local function _applyVisible()
	local line = _line
	if line then
		local target = _lineTarget
		local show = _visible and target ~= nil and target.Parent ~= nil
		if show and target then
			local gui = _lineGui
			local point = gui and _getSurfacePoint(gui, target)
			line:PivotTo(point or _getAimCFrame(target))
		end
		if _beam then
			_beam.Attachment1 = _playerAttachment
		end
		line.Parent = if show then Workspace else nil
	end
	local highlight = _highlight
	if highlight then
		local target = _highlightTarget
		local show = _visible and target ~= nil and target.Parent ~= nil
		highlight.Adornee = if show then target else nil
		highlight.Enabled = show
		highlight.Parent = if show then Workspace else nil
	end
end

--[[
	角色就绪后在 HumanoidRootPart 下挂角色端 Attachment，接到 Beam.Attachment1
	@param character Model - 本地角色
]]
local function _bindCharacter(character: Model)
	_playerAttachment = nil
	_applyVisible()
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", ROOT_WAIT_SEC)
		if not root or LocalPlayer.Character ~= character then
			return
		end
		local attachment = Instance.new("Attachment")
		attachment.Name = PLAYER_ATTACHMENT_NAME
		attachment.Parent = root
		_playerAttachment = attachment
		_applyVisible()
	end)
end

--[[
	异步查找目标（未流入 / 未创建时周期重试），找到后回调；版本变化即放弃
	@param path string - 点分路径
	@param version number - 发起时的阶段版本
	@param find (string) -> Instance? - 查找函数（_findWorld / _findGui）
	@param onFound (Instance) -> () - 找到后的回调
]]
local function _resolveAsync(path: string, version: number, find: (string) -> Instance?, onFound: (Instance) -> ())
	task.spawn(function()
		local target = find(path)
		while not target do
			task.wait(RESOLVE_RETRY)
			if version ~= _version then
				return
			end
			target = find(path)
		end
		if version == _version then
			onFound(target)
		end
	end)
end

--[[
	读取配置里的路径
	@param cfg any - { path: string } 或 nil
	@return string? - 非空路径；无配置为 nil
]]
local function _getPath(cfg: any): string?
	if type(cfg) == "table" and type(cfg.path) == "string" and cfg.path ~= "" then
		return cfg.path
	end
	return nil
end

--[[
	切换到某阶段的引导线 / 场景高光（先清除旧目标）
	@param lineCfg table? - 阶段 line 配置 { path: string, gui: string? }；gui 为 PlayerGui 下贴在 path 部件侧面的 SurfaceGui 控件路径，找到前先指可见位置；nil 不显示引导线
	@param highlightCfg table? - 阶段 worldHighlight 配置 { path: string }；nil 不显示高光
]]
function LineGuide.Apply(lineCfg: { [string]: any }?, highlightCfg: { [string]: any }?)
	_version += 1
	_lineTarget = nil
	_lineGui = nil
	if _lineGuiConn then
		_lineGuiConn:Disconnect()
		_lineGuiConn = nil
	end
	_highlightTarget = nil
	_applyVisible()
	local version = _version
	local linePath = _getPath(lineCfg)
	if linePath then
		_resolveAsync(linePath, version, _findWorld, function(target: Instance)
			_lineTarget = target
			_applyVisible()
		end)
		local guiPath = lineCfg and lineCfg.gui
		if type(guiPath) == "string" and guiPath ~= "" then
			_resolveAsync(guiPath, version, _findGui, function(gui: Instance)
				_lineGui = gui :: GuiObject
				_lineGuiConn = (gui :: GuiObject):GetPropertyChangedSignal("AbsolutePosition"):Connect(_applyVisible)
				_applyVisible()
			end)
		end
	end
	local highlightPath = _getPath(highlightCfg)
	if highlightPath then
		_resolveAsync(highlightPath, version, _findWorld, function(target: Instance)
			_highlightTarget = target
			_applyVisible()
		end)
	end
end

--[[
	整体显隐（不丢目标，恢复时直接显示）
	@param visible boolean - true 显示；false 隐藏
]]
function LineGuide.SetVisible(visible: boolean)
	_visible = visible
	_applyVisible()
end

--[[
	启动：克隆资源并监听角色重生（重复调用忽略）
]]
function LineGuide.Init()
	if _inited then
		return
	end
	_inited = true
	_createVisuals()
	LocalPlayer.CharacterAdded:Connect(_bindCharacter)
	if LocalPlayer.Character then
		_bindCharacter(LocalPlayer.Character)
	end
end

return LineGuide
