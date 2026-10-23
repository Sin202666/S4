--[[
	Module: MenuGift
	Description: 扳手腕菜单挽留弹窗：玩家一打开 Roblox 菜单即弹出，免费领一次现金，点击领取请求服务端结算
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 监听 GuiService.MenuOpened：菜单打开瞬间弹出，透过菜单半透明背景可见；关闭菜单后仍留在屏幕上等待领取或手动关闭
	- 只读服务端镜像 MenuGiftClaimed（是否已领，未同步前按已领处理不弹）/ MenuGiftCash（预估现金）
	- 对局中不弹；每次打开菜单都会再弹，直到领取（每账号永久一次）
	- 领取：Invoke("ClaimMenuGift")，结算与「+X 现金」提示全在服务端 SystemArmWrestle.MenuGift；成功后撒彩纸并收起
	- 玩家在菜单里直接点「离开」时无法拦截，属平台限制；Roblox 菜单（CoreGui）永远盖在游戏 UI 之上
	- 显示期间整窗上下浮动、领取按钮呼吸缩放、礼物图标左右摆动，收起即停止
	- 音效（SystemUISfx）：领取成功播奖励音
	- 独立 ScreenGui（DisplayOrder 高于 HUD / CoinGui / UIAnimGui，低于 TipsGui 以便领取提示可见）+ 全屏压暗遮罩，避免被其他界面遮挡
	- 不在 HUD 树内，弹出时按主 ScreenGui 根 UIScale × POPUP_SCALE 设置 Holder 缩放，保持与 HUD 弹窗一致大小

	静态 UI（Studio 维护于 StarterGui.MenuGiftGui，本模块只绑定不新建，节点名为代码契约）：
	- MenuGiftGui(ScreenGui，默认 Enabled=false，IgnoreGuiInset，ScreenInsets=None，ResetOnSpawn=false)
	  - Dim（全屏黑色半透明遮罩，Active 拦截点击）
	  - Holder（全屏透明容器，居中）/ UIScale（脚本按屏幕适配写入）
	    - MenuGift(Frame，屏幕居中；外框与商店弹窗同一套积木风格；不得再挂 UIScale，Style.Pop 用 PopScale)
	      - TitleBar（金色积木标题栏）/ Title（标题，Icon=gift）/ GiftIcon（礼物图标 ImageLabel）/ Desc（说明）/ Reward（预估现金，Icon=cash）
	      - ClaimButton（绿色积木按钮）/ Label（领取）、Pulse（UIScale，呼吸动画专用）
	      - CloseButton（红色积木关闭按钮，「X」为静态子节点 Icon）

	与相关模块：
	- ArmWrestleHUD.init：_bindHud 时在 Common.Bind 之后 Bind 一次（依赖 Common.screenGui 取根缩放）
	- Battle：IsActive 判断对局中
	- 服务端 SystemArmWrestle.MenuGift：金额计算、次数把关与发放

	加载：
		local MenuGift = require(script.MenuGift)
		MenuGift.Bind()
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local GuiService = Utils.GuiService
local TweenService = Utils.TweenService
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local TipsModule = Utils.TipsModule
local SystemUISfx = Utils.SystemUISfx

local Common = require(script.Parent.Common)

local Style = ArmWrestleStyle

local MenuGift = {}

local ACTION_CLAIM = "ClaimMenuGift"
local ERR_CLAIMED = "claimed"
local ATTR_CLAIMED = "MenuGiftClaimed"
local ATTR_CASH = "MenuGiftCash"
local PULSE_SCALE = 1.08
local PULSE_TIME = 0.6
local SWING_ANGLE = 8
local SWING_TIME = 0.8
local BOB_OFFSET = 14
local BOB_TIME = 0.9
local GUI_NAME = "MenuGiftGui"
local POPUP_SCALE = 1.5
-- TitleBar 悬在 MenuGift 框外上方（高 72），下移半个标题栏让整体在 MenuOfflineHint 上下横幅之间居中
local TITLE_OFFSET = 36

local _screen: ScreenGui?
local _holderScale: UIScale?
local _rootScale: UIScale?
local _root: Frame?
local _reward: TextLabel?
local _pulse: UIScale?
local _icon: ImageLabel?
local _tweens: { Tween } = {}
local _claiming = false

--[[
	开关整窗浮动、领取按钮呼吸与礼物图标摆动（无限往返补间，停止时复位）
	@param on boolean - true 播放，false 停止并复位
	@return nil
]]
local function _setAnimating(on: boolean)
	for _, tween in ipairs(_tweens) do
		if on then
			tween:Play()
		else
			tween:Cancel()
		end
	end
	if on then
		return
	end
	if _pulse then
		_pulse.Scale = 1
	end
	if _icon then
		_icon.Rotation = -SWING_ANGLE
	end
	if _root then
		_root.Position = UDim2.new(0.5, 0, 0.5, TITLE_OFFSET - BOB_OFFSET)
	end
end

--[[
	收起弹窗
	@return nil
]]
local function _hide()
	if _screen then
		_screen.Enabled = false
	end
	_setAnimating(false)
end

--[[
	刷新预估现金；已领则收起
	@return nil
]]
local function _refresh()
	if Common.Attr(ATTR_CLAIMED, true) ~= false then
		_hide()
		return
	end
	if _reward then
		Common.SetText(_reward, "获得现金", { ArmWrestleConfig.Format(Common.Attr(ATTR_CASH, 0)) })
	end
end

--[[
	Roblox 菜单打开：未领取时弹出（已显示则不重复弹）
	@return nil
]]
local function _onMenuOpened()
	local root = _root
	local screen = _screen
	if not root or not screen then
		return
	end
	if Common.Attr(ATTR_CLAIMED, true) ~= false then
		return
	end
	_refresh()
	if not screen.Enabled then
		if _holderScale then
			_holderScale.Scale = (if _rootScale then _rootScale.Scale else 1) * POPUP_SCALE
		end
		screen.Enabled = true
		Style.Pop(root)
		_setAnimating(true)
	end
end

--[[
	点击领取：请求服务端结算；进行中忽略重复点击
	@return nil
]]
local function _claim()
	if _claiming then
		return
	end
	_claiming = true
	local ok, result = Common.Invoke(ACTION_CLAIM)
	_claiming = false
	if ok then
		Common.Confetti()
		SystemUISfx.PlayReward()
		_hide()
		return
	end
	if result == ERR_CLAIMED then
		_hide()
		return
	end
	TipsModule.ErrorTips(LocalPlayer, "领取挽留礼物失败")
end

--[[
	绑定挽留弹窗静态节点、文案、菜单与镜像监听（ArmWrestleHUD.Init 在 Common.Bind 之后调一次）
	@return Frame - MenuGift 弹窗
]]
function MenuGift.Bind(): Frame
	local screen = Common.Get(LocalPlayer:WaitForChild("PlayerGui"), GUI_NAME) :: ScreenGui
	screen.Enabled = false
	_screen = screen
	_holderScale = Common.Get(screen, "Holder", "UIScale") :: UIScale
	_rootScale = if Common.screenGui then Common.screenGui:FindFirstChildOfClass("UIScale") else nil
	local root = Common.Get(screen, "Holder", "MenuGift") :: Frame
	_root = root
	Style.BindIcons(root)
	_reward = Common.Get(root, "Reward") :: TextLabel
	Common.SetText(Common.Get(root, "Title") :: TextLabel, "挽留礼物标题")
	Common.SetText(Common.Get(root, "Desc") :: TextLabel, "挽留礼物描述")

	local claimBtn = Common.Get(root, "ClaimButton") :: TextButton
	Common.SetText(Common.Get(claimBtn, "Label") :: TextLabel, "领取")
	claimBtn.MouseButton1Click:Connect(_claim)

	local pulse = Common.Get(claimBtn, "Pulse") :: UIScale
	local icon = Common.Get(root, "GiftIcon") :: ImageLabel
	_pulse = pulse
	_icon = icon
	local pulseInfo = TweenInfo.new(PULSE_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local swingInfo = TweenInfo.new(SWING_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local bobInfo = TweenInfo.new(BOB_TIME, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	_tweens = {
		TweenService:Create(pulse, pulseInfo, { Scale = PULSE_SCALE }),
		TweenService:Create(icon, swingInfo, { Rotation = SWING_ANGLE }),
		TweenService:Create(root, bobInfo, { Position = UDim2.new(0.5, 0, 0.5, TITLE_OFFSET + BOB_OFFSET) }),
	}
	_setAnimating(false)

	local closeBtn = Common.Get(root, "CloseButton") :: TextButton
	closeBtn.MouseButton1Click:Connect(_hide)

	GuiService.MenuOpened:Connect(_onMenuOpened)
	LocalPlayer:GetAttributeChangedSignal(ATTR_CLAIMED):Connect(_refresh)
	LocalPlayer:GetAttributeChangedSignal(ATTR_CASH):Connect(_refresh)
	return root
end

return MenuGift
