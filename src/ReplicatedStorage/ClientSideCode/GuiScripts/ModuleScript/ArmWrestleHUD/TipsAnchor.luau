--[[
	Module: TipsAnchor
	Description: 让通用提示区 TipsGui.NewTipsFrame 的顶边贴在 Roblox 顶栏下方
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 按 GuiService:GetGuiInset 把提示区放在 Roblox 顶栏下方，并除以 TipsGui 根 UIScale
	- 监听视口尺寸与 TipsGui 尺寸 / 根 UIScale，实时改写 NewTipsFrame.Position 的 Y
	- 本模块是 NewTipsFrame.Position 的唯一写入方；TipsRenderer 只往容器里挂提示条，不动容器位置

	静态 UI（Studio 维护，节点名为代码契约）：
	- StarterGui.TipsGui（ResetOnSpawn=false，IgnoreGuiInset，含根 UIScale）/ NewTipsFrame（AnchorPoint Y=0）

	加载：
		local TipsAnchor = require(script.TipsAnchor)
		TipsAnchor.Bind()  -- ArmWrestleHUD._bindHud 内调用一次（依赖 Common.Bind 已完成）
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local GuiService = Utils.GuiService

local Common = require(script.Parent.Common)

local TipsAnchor = {}

local TIPS_GUI_NAME = "TipsGui"
local TIPS_FRAME_NAME = "NewTipsFrame"
-- 提示区与 Roblox 顶栏之间的留白（屏幕像素）
local GAP = 8

local _tipsGui: ScreenGui?
local _tipsFrame: Frame?
local _rootScale: UIScale?

--[[
	按 Roblox 顶栏底边重算 NewTipsFrame 的 Y 偏移（X 保持 Studio 原值）
	TipsGui 忽略 GuiInset，原点在视口顶，需加上顶栏高度才不会被顶栏挡住
]]
local function _sync()
	local tipsGui, frame = _tipsGui, _tipsFrame
	if not tipsGui or not frame then
		return
	end
	local targetY = GuiService:GetGuiInset().Y + GAP
	local scale = if _rootScale and _rootScale.Scale > 0 then _rootScale.Scale else 1
	local pos = frame.Position
	frame.Position = UDim2.new(pos.X.Scale, pos.X.Offset, 0, (targetY - tipsGui.AbsolutePosition.Y) / scale)
end

--[[
	绑定提示区贴在 Roblox 顶栏下方（ArmWrestleHUD._bindHud 调一次）
	@return Frame - TipsGui.NewTipsFrame
]]
function TipsAnchor.Bind(): Frame
	local tipsGui = Common.Get(LocalPlayer:WaitForChild("PlayerGui"), TIPS_GUI_NAME) :: ScreenGui
	local frame = Common.Get(tipsGui, TIPS_FRAME_NAME) :: Frame
	_tipsGui = tipsGui
	_tipsFrame = frame
	_rootScale = tipsGui:FindFirstChildOfClass("UIScale")

	tipsGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(_sync)
	tipsGui:GetPropertyChangedSignal("AbsolutePosition"):Connect(_sync)
	if _rootScale then
		_rootScale:GetPropertyChangedSignal("Scale"):Connect(_sync)
	end
	local camera = workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(_sync)
	end
	_sync()
	return frame
end

return TipsAnchor
