--[[
	Module: MenuOfflineHint
	Description: 扳手腕菜单离线奖励提示：Roblox 菜单打开期间在屏幕上下各显示一条「离线也有奖励」横幅，提醒玩家下线也能累积力量
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	功能：
	- 监听 GuiService.MenuOpened / MenuClosed：菜单打开时横幅从屏幕上下边缘滑入并呼吸缩放，菜单关闭即收起
	- 纯展示：文案保持简短，离线结算全在服务端 SystemArmWrestle.Offline
	- 横幅放在屏幕上下边缘，是 Roblox 菜单面板最不容易盖住的区域；菜单（CoreGui）本身仍永远在游戏 UI 之上
	- 与 MenuGift（挽留礼物弹窗）同时触发、互不依赖：已领挽留礼物后横幅照常显示

	静态 UI（Studio 维护于 StarterGui.MenuHintGui，本模块只绑定不新建，节点名为代码契约）：
	- MenuHintGui(ScreenGui，默认 Enabled=false，DisplayOrder 高于 MenuGiftGui，IgnoreGuiInset，ScreenInsets=None，ResetOnSpawn=false)
	  - Top（顶部横幅，AnchorPoint Y=0）/ UIScale（脚本写入）、Bar（金色积木底条）、Label（标题，Icon=sleep）
	  - Bottom（底部横幅，AnchorPoint Y=1）/ UIScale、Bar、Label（说明，Icon=strength）

	与相关模块：
	- ArmWrestleHUD.init：_bindHud 时在 Common.Bind 之后 Bind 一次（依赖 Common.screenGui 取根缩放）
	- MenuGift：同为菜单挽留，负责领取弹窗

	加载：
		local MenuOfflineHint = require(script.MenuOfflineHint)
		MenuOfflineHint.Bind()
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local GuiService = Utils.GuiService
local TweenService = Utils.TweenService
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleStyle = Utils.ArmWrestleStyle

local Common = require(script.Parent.Common)

local Style = ArmWrestleStyle

local MenuOfflineHint = {}

local GUI_NAME = "MenuHintGui"
local BANNER_SCALE = 1.2
local SLIDE_DISTANCE = 200
local SLIDE_TIME = 0.45
local PULSE_RATIO = 1.06
local PULSE_TIME = 0.7

type Banner = {
	frame: Frame,
	scale: UIScale,
	home: UDim2,
	slideFrom: UDim2,
}

local _screen: ScreenGui?
local _rootScale: UIScale?
local _banners: { Banner } = {}
local _tweens: { Tween } = {}

--[[
	停止并清空当前横幅补间
	@return nil
]]
local function _stopTweens()
	for _, tween in ipairs(_tweens) do
		tween:Cancel()
	end
	table.clear(_tweens)
end

--[[
	播放补间并登记，便于菜单关闭时统一取消
	@param obj Instance - 补间目标
	@param info TweenInfo - 补间参数
	@param goal table - 目标属性表（如 { Position = UDim2 }）
	@return Tween - 已开始播放的补间
]]
local function _play(obj: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(obj, info, goal)
	table.insert(_tweens, tween)
	tween:Play()
	return tween
end

--[[
	菜单打开：按屏幕适配缩放横幅，从上下边缘滑入后循环呼吸
	@return nil
]]
local function _show()
	local screen = _screen
	if not screen then
		return
	end
	_stopTweens()
	local fit = (if _rootScale then _rootScale.Scale else 1) * BANNER_SCALE
	local slideInfo = TweenInfo.new(SLIDE_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local pulseInfo = TweenInfo.new(PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	for _, banner in ipairs(_banners) do
		banner.scale.Scale = fit
		banner.frame.Position = banner.slideFrom
		_play(banner.frame, slideInfo, { Position = banner.home })
		_play(banner.scale, pulseInfo, { Scale = fit * PULSE_RATIO })
	end
	screen.Enabled = true
end

--[[
	菜单关闭：收起横幅并停止动画
	@return nil
]]
local function _hide()
	_stopTweens()
	if _screen then
		_screen.Enabled = false
	end
end

--[[
	读取一条横幅节点并记录滑入起止位置
	@param screen ScreenGui - MenuHintGui
	@param name string - 横幅节点名（Top / Bottom）
	@param direction number - 滑入方向：-1 从屏幕上方进入，1 从屏幕下方进入
	@return Banner - 横幅记录 { frame, scale, home, slideFrom }
]]
local function _bindBanner(screen: ScreenGui, name: string, direction: number): Banner
	local frame = Common.Get(screen, name) :: Frame
	local home = frame.Position
	return {
		frame = frame,
		scale = Common.Get(frame, "UIScale") :: UIScale,
		home = home,
		slideFrom = home + UDim2.fromOffset(0, direction * SLIDE_DISTANCE),
	}
end

--[[
	绑定菜单离线提示横幅、文案与菜单开关监听（ArmWrestleHUD.Init 在 Common.Bind 之后调一次）
	@return ScreenGui - MenuHintGui
]]
function MenuOfflineHint.Bind(): ScreenGui
	local screen = Common.Get(LocalPlayer:WaitForChild("PlayerGui"), GUI_NAME) :: ScreenGui
	screen.Enabled = false
	_screen = screen
	_rootScale = if Common.screenGui then Common.screenGui:FindFirstChildOfClass("UIScale") else nil
	Style.BindIcons(screen)

	local top = _bindBanner(screen, "Top", -1)
	local bottom = _bindBanner(screen, "Bottom", 1)
	_banners = { top, bottom }
	Common.SetText(Common.Get(top.frame, "Label") :: TextLabel, "菜单离线提示标题")
	Common.SetText(Common.Get(bottom.frame, "Label") :: TextLabel, "菜单离线提示描述")

	GuiService.MenuOpened:Connect(_show)
	GuiService.MenuClosed:Connect(_hide)
	return screen
end

return MenuOfflineHint
