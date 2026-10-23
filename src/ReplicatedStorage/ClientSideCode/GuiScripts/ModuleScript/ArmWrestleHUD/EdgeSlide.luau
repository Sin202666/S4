--[[
	Module: EdgeSlide
	Description: ArmWrestleHUD 弹窗联动：任一弹窗显示时，主界面四周的 UI 分组滑出屏幕边缘，全部弹窗关闭后滑回
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 弹窗判定：PlayerGui.ScreenGui / ScreenGui_Full 下的直接子 Frame（排除 HUD 容器 ArmWrestleHUD、Main 与彩纸片 ArmWrestleStyle.CONFETTI_NAME）Visible=true，
	  以及 HUD 内的离线奖励窗 OfflineReward；运行时新增的弹窗 Frame 经 ChildAdded 自动纳入
	- 边缘分组（节点名为代码契约，改名须同步 EDGE_GROUPS）：
	  ArmWrestleHUD：Left 向左，Cash / Boost / PotionBuff 向下
	  Main（框架层，节点可缺省）：Top 向上，Left 向左，Right 向右，Backpack 向下（按其下「工具栏」测距）
	- 滑出距离按分组当前布局到屏幕边缘的像素实时换算成 Scale，只改 Position.Scale，不动 Offset，分辨率/UIScale 变化后仍准确
	- 只写各分组的 Position；分组显隐仍由 Battle 等模块写 Visible，二者互不覆盖
	- 弹窗状态同步写本地玩家 Attribute EnumMgr.PlayerAttr.PopupOpen（仅本端可见），供客户端 SystemGuide 等表现层隐藏界面箭头

	与相关模块：
	- UIManager：弹窗 PopUp 开始即 Visible=true（立即滑出），PopBack 结束才 Visible=false（随后滑回）
	- ArmWrestleHUD.init：_bindHud 末尾调用 EdgeSlide.Bind()

	加载：
		local EdgeSlide = require(script.EdgeSlide)
		EdgeSlide.Bind()   -- Common.Bind 之后调用一次
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local TweenService = Utils.TweenService
local GuiService = Utils.GuiService
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleStyle = Utils.ArmWrestleStyle
local EnumMgr = Utils.EnumMgr

local Common = require(script.Parent.Common)

local EdgeSlide = {}

local SLIDE_INFO = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
-- 滑出后额外留出的像素，避免描边/阴影露在屏幕边缘
local SLIDE_PAD = 24
-- 布局变化后延迟重算，等待 AbsolutePosition / AbsoluteSize 刷新
local REFRESH_DELAY = 0.1
-- 重算目标与当前 Position.Scale 差异低于此值视为已到位，避免反复补间
local REFRESH_EPSILON = 0.002
local SCREEN_GUI_FULL_NAME = "ScreenGui_Full"
local IGNORED_POPUP_NAMES: { [string]: boolean } = {
	ArmWrestleHUD = true,
	Main = true,
	-- 彩纸片直挂 ScreenGui，飘落期间若算作弹窗会推迟四周 UI 滑回
	[ArmWrestleStyle.CONFETTI_NAME] = true,
}
local HUD_POPUP_NAMES = { "OfflineReward" }
local POPUP_OPEN_ATTR = EnumMgr.PlayerAttr.PopupOpen

type GroupDef = { root: string, name: string, dir: Vector2, measure: string?, optional: boolean? }

local UP = Vector2.new(0, -1)
local DOWN = Vector2.new(0, 1)
local LEFT = Vector2.new(-1, 0)
local RIGHT = Vector2.new(1, 0)

local EDGE_GROUPS: { GroupDef } = {
	{ root = "HUD", name = "Left", dir = LEFT },
	{ root = "HUD", name = "Cash", dir = DOWN },
	{ root = "HUD", name = "Boost", dir = DOWN },
	{ root = "HUD", name = "PotionBuff", dir = DOWN },
	{ root = "Main", name = "Top", dir = UP, optional = true },
	{ root = "Main", name = "Left", dir = LEFT, optional = true },
	{ root = "Main", name = "Right", dir = RIGHT, optional = true },
	{ root = "Main", name = "Backpack", dir = DOWN, measure = "工具栏", optional = true },
}

type Entry = {
	frame: GuiObject,
	dir: Vector2,
	measure: GuiObject,
	rest: UDim2,
	tween: Tween?,
}

local _entries: { Entry } = {}
local _popups: { [GuiObject]: boolean } = {}
local _screenGui: ScreenGui?
local _retracted = false
local _bound = false
local _refreshPending = false
local _scheduleRefresh: () -> ()

--[[
	真实屏幕（整个视口）在 ScreenGui 坐标系下的矩形
	ScreenGui 未忽略 GuiInset 时，其原点在 Roblox 顶栏下方，直接用 ScreenGui 矩形会少算顶栏高度，上滑分组会露出屏幕
	@param screenGui ScreenGui - 分组所在 ScreenGui
	@return Vector2 - 屏幕左上角
	@return Vector2 - 屏幕右下角
]]
local function _screenBounds(screenGui: ScreenGui): (Vector2, Vector2)
	local insetTopLeft = if screenGui.IgnoreGuiInset then Vector2.zero else GuiService:GetGuiInset()
	local screenMin = screenGui.AbsolutePosition - insetTopLeft
	local camera = workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else screenGui.AbsoluteSize + insetTopLeft
	return screenMin, screenMin + viewport
end

--[[
	分组父级像素尺寸（父级可为 Frame 或直挂的 ScreenGui）
	@param frame GuiObject - 分组根
	@return Vector2 - AbsoluteSize；无父级时为零
]]
local function _parentSize(frame: GuiObject): Vector2
	local parent = frame.Parent
	if parent and parent:IsA("GuiBase2d") then
		return parent.AbsoluteSize
	end
	return Vector2.zero
end

--[[
	分组在静止位置时，沿滑出方向移出屏幕所需的像素距离（扣除当前已偏移量，滑动途中重算也准确）
	@param entry Entry - 分组
	@return number - 像素距离
]]
local function _slideDistancePx(entry: Entry): number
	local host = entry.frame:FindFirstAncestorOfClass("ScreenGui") or (_screenGui :: ScreenGui)
	local parentSize = _parentSize(entry.frame)
	local pos = entry.frame.Position
	local shift = Vector2.new(
		(pos.X.Scale - entry.rest.X.Scale) * parentSize.X,
		(pos.Y.Scale - entry.rest.Y.Scale) * parentSize.Y
	)
	local minCorner = entry.measure.AbsolutePosition - shift
	local maxCorner = minCorner + entry.measure.AbsoluteSize
	local screenMin, screenMax = _screenBounds(host)
	local dir = entry.dir
	local dist
	if dir.X < 0 then
		dist = maxCorner.X - screenMin.X
	elseif dir.X > 0 then
		dist = screenMax.X - minCorner.X
	elseif dir.Y < 0 then
		dist = maxCorner.Y - screenMin.Y
	else
		dist = screenMax.Y - minCorner.Y
	end
	return math.max(dist, 0) + SLIDE_PAD
end

--[[
	分组滑出后的目标位置（只改 Scale，像素距离按父级尺寸换算）
	@param entry Entry - 分组
	@return UDim2 - 目标 Position
]]
local function _hiddenPosition(entry: Entry): UDim2
	local parentSize = _parentSize(entry.frame)
	local dist = _slideDistancePx(entry)
	local rest = entry.rest
	local dx = if parentSize.X > 0 then entry.dir.X * dist / parentSize.X else 0
	local dy = if parentSize.Y > 0 then entry.dir.Y * dist / parentSize.Y else 0
	return UDim2.new(rest.X.Scale + dx, rest.X.Offset, rest.Y.Scale + dy, rest.Y.Offset)
end

--[[
	把分组补间到目标位置（打断上一段补间）
	@param entry Entry - 分组
	@param target UDim2 - 目标 Position
]]
local function _tweenTo(entry: Entry, target: UDim2)
	if entry.tween then
		entry.tween:Cancel()
	end
	local tween = TweenService:Create(entry.frame, SLIDE_INFO, { Position = target })
	entry.tween = tween
	-- 滑出到位后按实际布局复核一次，开局布局未稳定时算出的距离可在此修正
	tween.Completed:Connect(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and entry.tween == tween then
			_scheduleRefresh()
		end
	end)
	tween:Play()
end

--[[
	按当前是否有弹窗显示，整体滑出或滑回（状态未变时不重复补间）
]]
local function _update()
	local anyPopup = false
	for frame in pairs(_popups) do
		if frame.Visible then
			anyPopup = true
			break
		end
	end
	if anyPopup == _retracted then
		return
	end
	_retracted = anyPopup
	LocalPlayer:SetAttribute(POPUP_OPEN_ATTR, anyPopup)
	for _, entry in ipairs(_entries) do
		_tweenTo(entry, if anyPopup then _hiddenPosition(entry) else entry.rest)
	end
end

--[[
	收起状态下按最新布局重算滑出位置，与当前位置差异超过阈值才重新补间
	开局弹窗（离线奖励）可能早于顶栏 GuiInset / 视口 / 根 UIScale 适配就绪，首次算出的距离不准，分组会露出一部分
]]
local function _refreshRetracted()
	_refreshPending = false
	if not _retracted then
		return
	end
	for _, entry in ipairs(_entries) do
		local target = _hiddenPosition(entry)
		local current = entry.frame.Position
		if
			math.abs(target.X.Scale - current.X.Scale) > REFRESH_EPSILON
			or math.abs(target.Y.Scale - current.Y.Scale) > REFRESH_EPSILON
		then
			_tweenTo(entry, target)
		end
	end
end

--[[
	合并同一时段的多次布局变化，稍后统一重算（等 AbsolutePosition/AbsoluteSize 刷新）
]]
_scheduleRefresh = function()
	if _refreshPending or not _retracted then
		return
	end
	_refreshPending = true
	task.delay(REFRESH_DELAY, _refreshRetracted)
end

--[[
	监听影响滑出距离的布局变化：视口、GuiInset（体现为 ScreenGui 尺寸/位置）、根 UIScale 适配、各分组自身尺寸
	@param screenGui ScreenGui - 分组所在 ScreenGui
]]
local function _watchLayout(screenGui: ScreenGui)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(_scheduleRefresh)
	screenGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(_scheduleRefresh)
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(_scheduleRefresh)
	end
	local rootScale = screenGui:FindFirstChildOfClass("UIScale")
	if rootScale then
		rootScale:GetPropertyChangedSignal("Scale"):Connect(_scheduleRefresh)
	end
	for _, entry in ipairs(_entries) do
		entry.measure:GetPropertyChangedSignal("AbsoluteSize"):Connect(_scheduleRefresh)
	end
end

--[[
	登记一个弹窗 Frame：监听 Visible，销毁时移除
	@param frame GuiObject - 弹窗根 Frame
]]
local function _watchPopup(frame: GuiObject)
	if _popups[frame] then
		return
	end
	_popups[frame] = true
	frame:GetPropertyChangedSignal("Visible"):Connect(_update)
	frame.Destroying:Connect(function()
		_popups[frame] = nil
		_update()
	end)
end

--[[
	登记某 ScreenGui 下全部弹窗 Frame（含之后新增的）
	@param screenGui ScreenGui - ScreenGui / ScreenGui_Full
]]
local function _watchPopupContainer(screenGui: ScreenGui)
	local function onChild(child: Instance)
		if child:IsA("Frame") and not IGNORED_POPUP_NAMES[child.Name] then
			_watchPopup(child)
			_update()
		end
	end
	for _, child in ipairs(screenGui:GetChildren()) do
		onChild(child)
	end
	screenGui.ChildAdded:Connect(onChild)
end

--[[
	按 EDGE_GROUPS 收集边缘分组并记录静止位置
	@param roots table - { Full: ScreenGui?, HUD: Frame, Main: Frame? }
]]
local function _collectGroups(roots: { [string]: Instance? })
	for _, def in ipairs(EDGE_GROUPS) do
		local root = roots[def.root]
		local frame = if root
			then (if def.optional then root:FindFirstChild(def.name) else Common.Get(root, def.name))
			else nil
		if frame and frame:IsA("GuiObject") then
			local measure = if def.measure then frame:FindFirstChild(def.measure) else frame
			table.insert(_entries, {
				frame = frame,
				dir = def.dir,
				measure = if measure and measure:IsA("GuiObject") then measure else frame,
				rest = frame.Position,
				tween = nil,
			})
		end
	end
end

--[[
	绑定边缘分组与弹窗监听（Common.Bind 之后调用一次；重复调用忽略）
]]
function EdgeSlide.Bind()
	if _bound then
		return
	end
	_bound = true
	local screenGui = Common.screenGui :: ScreenGui
	local hud = Common.gui :: Frame
	local full = Common.screenGuiFull
	if not full then
		local playerGui = LocalPlayer:WaitForChild("PlayerGui")
		local found = playerGui:FindFirstChild(SCREEN_GUI_FULL_NAME)
		if found and found:IsA("ScreenGui") then
			full = found
			Common.screenGuiFull = full
		end
	end
	_screenGui = screenGui
	_collectGroups({ Full = full, HUD = hud, Main = screenGui:FindFirstChild("Main") })

	for _, name in ipairs(HUD_POPUP_NAMES) do
		_watchPopup(Common.Get(hud, name) :: GuiObject)
	end
	_watchPopupContainer(screenGui)
	if full then
		_watchPopupContainer(full)
		_watchLayout(full)
	end
	_watchLayout(screenGui)
	_update()
end

return EdgeSlide
