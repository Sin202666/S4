--[[
	Module: UIGuide
	Description: 新手引导界面箭头：在目标按钮中心叠加箭头模板（ModelRes/Guide 下 右 / 左 / 左下）并循环缩放
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- Apply(cfg)：按 ui 配置找 PlayerGui 下目标（手机优先 path_Mobile），克隆 cfg.Arrow 模板到独立 ScreenGui「Guide_UIOverlay」
	- cfg.target：在 path 节点的后代中找 Attribute GuideTarget == target 的控件（用于动态克隆、同名的列表卡片按钮，由 UI 渲染方打标记）
	- 箭头锚点每帧跟随目标中心；目标被销毁（列表重渲染）后按 RESOLVE_RETRY 重新查找；目标或其祖先不可见时箭头隐藏
	- 箭头图片以靠近目标一端为基点循环缩放（PULSE_SCALE）
	- 箭头下 GuideText：配置 ZhArrowText 时显示翻译文案，否则隐藏；手机端模板 UIScale 缩到 MOBILE_ARROW_SCALE；小屏（ViewportDisplaySize.Small）仅文案再放大 50%
	- SetVisible：整层显隐（对局中由 SystemGuide 关闭），不销毁箭头

	约束：
	- 纯表现：不拦截点击（锚点 Active = false），不改目标按钮任何属性

	加载（仅 SystemGuide 内部使用）：
		local UIGuide = require(script.UIGuide)
		UIGuide.Apply({ path = "ScreenGui.ArmWrestleHUD.Left.ShopButton", Arrow = "右" })
		UIGuide.SetVisible(false)
		UIGuide.Apply(nil)   -- 清除
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local RunService = Utils.RunService
local TweenService = Utils.TweenService
local DeviceType = Utils.DeviceType
local GuiService = Utils.GuiService
local TranslationHelper = Utils.TranslationHelper
local AssetPaths = Utils.AssetPaths
local Log = Utils.Log

local UIGuide = {}

local GUIDE_RES_PATH = "ModelRes/Guide"
local OVERLAY_NAME = "Guide_UIOverlay"
local ANCHOR_NAME = "HighlightFrame"
local ARROW_TEXT_NAME = "GuideText"
local ARROW_ROT_NAME = "Rot"
local GUIDE_TARGET_ATTR = "GuideTarget"
local OVERLAY_DISPLAY_ORDER = 999
local MOBILE_ARROW_SCALE = 0.5
-- 小屏只放大箭头旁文案，不放大箭头图片
local SMALL_SCREEN_TEXT_SCALE = 1.5
local RESOLVE_RETRY = 1
local PULSE_SCALE = 1.2
local PULSE_INFO = TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local _overlay: ScreenGui? = nil
local _anchor: Frame? = nil
local _followConn: RBXScriptConnection? = nil
local _version = 0
local _visible = true
local _targetShown = false

--[[
	按 "A.B.C" 从 PlayerGui 查找界面节点
	@param path string - PlayerGui 下点分路径
	@return GuiBase? - 找到的界面节点（ScreenGui 或 GuiObject）
]]
local function _findNode(path: string): GuiBase?
	local node: Instance? = LocalPlayer:FindFirstChildOfClass("PlayerGui")
	for _, name in ipairs(string.split(path, ".")) do
		if not node then
			return nil
		end
		node = node:FindFirstChild(name)
	end
	if node and node:IsA("GuiBase") then
		return node
	end
	return nil
end

--[[
	按 ui 配置查找目标控件
	@param path string - PlayerGui 下点分路径
	@param target string? - GuideTarget 标记；nil 时 path 节点本身即目标
	@return GuiObject? - 目标控件；未找到为 nil
]]
local function _findTarget(path: string, target: string?): GuiObject?
	local node = _findNode(path)
	if not node then
		return nil
	end
	if not target then
		return if node:IsA("GuiObject") then node else nil
	end
	for _, child in ipairs(node:GetDescendants()) do
		if child:IsA("GuiObject") and child:GetAttribute(GUIDE_TARGET_ATTR) == target then
			return child
		end
	end
	return nil
end

--[[
	目标是否真正显示在屏幕上（自身与祖先 GuiObject 均 Visible、所属 LayerCollector 启用）
	@param target GuiObject - 目标控件
	@return boolean - 可见为 true
]]
local function _isShown(target: GuiObject): boolean
	local node: Instance? = target
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

--[[
	取或建箭头层 ScreenGui 与跟随锚点
	@return ScreenGui - 箭头层
	@return Frame - 锚点（位于目标中心，箭头模板挂其下）
]]
local function _ensureOverlay(): (ScreenGui, Frame)
	local overlay = _overlay
	local anchor = _anchor
	if overlay and anchor and overlay.Parent and anchor.Parent == overlay then
		return overlay, anchor
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = OVERLAY_NAME
	sg.ResetOnSpawn = false
	sg.IgnoreGuiInset = true
	sg.DisplayOrder = OVERLAY_DISPLAY_ORDER
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.Enabled = false

	local frame = Instance.new("Frame")
	frame.Name = ANCHOR_NAME
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Active = false
	frame.Size = UDim2.fromOffset(0, 0)
	frame.Parent = sg

	sg.Parent = LocalPlayer:WaitForChild("PlayerGui")
	_overlay = sg
	_anchor = frame
	return sg, frame
end

--[[
	给箭头图片加循环缩放（图片锚点在靠近目标一端，缩放时该端不动）
	@param arrow Instance - 克隆出的箭头模板
]]
local function _playPulse(arrow: Instance)
	local rot = arrow:FindFirstChild(ARROW_ROT_NAME)
	local image = rot and rot:FindFirstChildWhichIsA("GuiObject")
	if not image then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Parent = image
	TweenService:Create(scale, PULSE_INFO, { Scale = PULSE_SCALE }):Play()
end

--[[
	克隆箭头模板到锚点，设置文案、手机缩放与缩放动画
	@param anchor Frame - 跟随锚点
	@param cfg table - ui 配置（读 Arrow / ZhArrowText）
]]
local function _attachArrow(anchor: Frame, cfg: { [string]: any })
	local arrowName = cfg.Arrow
	if type(arrowName) ~= "string" or arrowName == "" then
		return
	end
	local res = AssetPaths.Resolve(GUIDE_RES_PATH, AssetPaths.Scope.Shared)
	local template = res and res:FindFirstChild(arrowName)
	if not template then
		Log.warn("UIGuide 找不到箭头模板", GUIDE_RES_PATH, arrowName)
		return
	end
	local arrow = template:Clone()
	if DeviceType.IsMobile() then
		local uiScale = arrow:FindFirstChildOfClass("UIScale")
		if uiScale then
			uiScale.Scale = MOBILE_ARROW_SCALE
		end
	end
	local guideText = arrow:FindFirstChild(ARROW_TEXT_NAME)
	if guideText and guideText:IsA("TextLabel") then
		guideText.Visible = type(cfg.ZhArrowText) == "string"
		if guideText.Visible then
			TranslationHelper.SetText(guideText, cfg.ZhArrowText)
		end
		if GuiService.ViewportDisplaySize == Enum.DisplaySize.Small then
			local textScale = Instance.new("UIScale")
			textScale.Name = "SmallScreenText"
			textScale.Scale = SMALL_SCREEN_TEXT_SCALE
			textScale.Parent = guideText
		end
	end
	_playPulse(arrow)
	arrow.Parent = anchor
end

--[[
	把锚点移到目标中心（箭头层忽略 GuiInset，按两者绝对坐标差换算）
	@param target GuiObject - 目标按钮
	@param overlay ScreenGui - 箭头层
	@param anchor Frame - 锚点
]]
local function _follow(target: GuiObject, overlay: ScreenGui, anchor: Frame)
	local pos = target.AbsolutePosition - overlay.AbsolutePosition
	local size = target.AbsoluteSize
	anchor.Position = UDim2.fromOffset(pos.X + size.X / 2, pos.Y + size.Y / 2)
end

--[[
	按整层显隐、是否在跟随、目标是否可见写 Enabled
]]
local function _applyEnabled()
	local overlay = _overlay
	if overlay then
		overlay.Enabled = _visible and _followConn ~= nil and _targetShown
	end
end

--[[
	清除当前箭头并作废进行中的目标查找
]]
local function _clear()
	_version += 1
	if _followConn then
		_followConn:Disconnect()
		_followConn = nil
	end
	_targetShown = false
	if _anchor then
		_anchor:ClearAllChildren()
	end
	_applyEnabled()
end

--[[
	找到目标后挂箭头并开始逐帧跟随；目标被销毁时节流重找
	@param target GuiObject - 首个找到的目标
	@param cfg table - ui 配置
	@param path string - 目标所在点分路径（重找用）
]]
local function _show(target: GuiObject, cfg: { [string]: any }, path: string)
	local overlay, anchor = _ensureOverlay()
	local targetKey = if type(cfg.target) == "string" then cfg.target else nil
	local current: GuiObject? = target
	local nextResolve = 0
	_attachArrow(anchor, cfg)
	_followConn = RunService.RenderStepped:Connect(function()
		local now = os.clock()
		if (not current or not current.Parent) and now >= nextResolve then
			nextResolve = now + RESOLVE_RETRY
			current = _findTarget(path, targetKey)
		end
		local live = current
		local shown = live ~= nil and live.Parent ~= nil and _isShown(live)
		if shown and live then
			_follow(live, overlay, anchor)
		end
		if shown ~= _targetShown then
			_targetShown = shown
			_applyEnabled()
		end
	end)
	_applyEnabled()
end

--[[
	切换界面箭头（先清除旧箭头）
	@param cfg table? - ui 配置 { path: string, path_Mobile: string?, target: string?, Arrow: string?, ZhArrowText: string? }；target 为 path 下后代控件的 GuideTarget 标记；nil 只清除
]]
function UIGuide.Apply(cfg: { [string]: any }?)
	_clear()
	if type(cfg) ~= "table" then
		return
	end
	local path = if DeviceType.IsMobile() and type(cfg.path_Mobile) == "string" then cfg.path_Mobile else cfg.path
	if type(path) ~= "string" or path == "" then
		return
	end
	local targetKey = if type(cfg.target) == "string" then cfg.target else nil
	local version = _version
	task.spawn(function()
		local target = _findTarget(path, targetKey)
		while not target do
			task.wait(RESOLVE_RETRY)
			if version ~= _version then
				return
			end
			target = _findTarget(path, targetKey)
		end
		if version == _version then
			_show(target, cfg, path)
		end
	end)
end

--[[
	整层显隐（不销毁箭头，恢复时继续跟随）
	@param visible boolean - true 显示；false 隐藏
]]
function UIGuide.SetVisible(visible: boolean)
	_visible = visible
	_applyEnabled()
end

return UIGuide
