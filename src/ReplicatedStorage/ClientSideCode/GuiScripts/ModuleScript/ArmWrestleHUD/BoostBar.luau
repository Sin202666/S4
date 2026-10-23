--[[
	Module: BoostBar
	Description: 扳手腕主界面右下角现金加成栏：同服好友加成（点击邀请好友）、Roblox 会员加成（点击订阅会员）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	功能：
	- 两枚按钮下方显示「+X%」，数值只读服务端同步的 FriendBoost / PremiumBoost Attribute（整数百分比）
	- 鼠标悬停显示说明气泡（标题 + 说明），移开隐藏
	- 好友按钮：CanSendGameInviteAsync 通过后弹 Roblox 官方邀请；不可邀请时 TipsModule 错误提示
	- 会员按钮：非会员弹 Roblox 官方会员订阅；已是会员只 TipsModule 提示
	- 加成结算全在服务端 SystemArmWrestle.Boost（好友/会员身份由服务端判定），本模块只展示与弹官方窗口

	静态 UI（Studio 维护于 StarterGui.ScreenGui.ArmWrestleHUD，本模块只绑定不新建，节点名为代码契约）：
	- Boost(UIScale / UIListLayout)
	  - FriendButton / PremiumButton（ImageButton，图标即按钮图片）
	    - Value（「+X%」）
	    - Tip（默认隐藏）/ Title、Band / Desc

	与相关模块：
	- ArmWrestleHUD.init：Bind 后把 Boost 写入 Common.hud.boost，对局中由 Battle 隐藏
	- 服务端 SystemArmWrestle.Boost：好友 +10%/人（封顶 +50%）、会员 +25%，与其它现金倍率独立相乘

	加载：
		local BoostBar = require(script.BoostBar)
		Common.hud.boost = BoostBar.Bind(Common.gui)
]]

local SocialService = game:GetService("SocialService")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local MarketplaceService = Utils.MarketplaceService
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local TranslationHelper = Utils.TranslationHelper
local TipsModule = Utils.TipsModule
local Log = Utils.Log

local Common = require(script.Parent.Common)

local Style = ArmWrestleStyle

local BoostBar = {}

local ATTR_FRIEND = "FriendBoost"
local ATTR_PREMIUM = "PremiumBoost"
local PERCENT = 100

local _friendValue: TextLabel?
local _premiumValue: TextLabel?
local _invitePending = false

--[[
	把整数百分比写成「+X%」
	@param lbl TextLabel? - 目标数值标签
	@param attr string - Attribute 名（FriendBoost / PremiumBoost）
	@return nil - 标签未绑定时跳过
]]
local function _renderValue(lbl: TextLabel?, attr: string)
	if not lbl then
		return
	end
	Common.SetRaw(lbl, "+" .. tostring(Common.Attr(attr, 0)) .. "%")
end

--[[
	刷新两枚按钮的加成数值
	@return nil - 无返回值
]]
local function _render()
	_renderValue(_friendValue, ATTR_FRIEND)
	_renderValue(_premiumValue, ATTR_PREMIUM)
end

--[[
	绑定悬停气泡：鼠标进入显示、离开隐藏
	@param btn GuiButton - 加成按钮
	@param tip GuiObject - 气泡 Tip 节点
	@return nil - 无返回值
]]
local function _bindTip(btn: GuiButton, tip: GuiObject)
	tip.Visible = false
	btn.MouseEnter:Connect(function()
		tip.Visible = true
	end)
	btn.MouseLeave:Connect(function()
		tip.Visible = false
	end)
end

--[[
	弹 Roblox 官方好友邀请（CanSendGameInviteAsync 会 yield，放独立线程；请求进行中忽略重复点击）
	@return nil - 无返回值
]]
local function _promptInvite()
	if _invitePending then
		return
	end
	_invitePending = true
	task.spawn(function()
		local okCan, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, LocalPlayer)
		if not okCan or canSend ~= true then
			_invitePending = false
			TipsModule.ErrorTips(LocalPlayer, "暂时无法邀请好友")
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.PromptMessage = TranslationHelper.TranslateByKey("邀请好友")
		local ok, err = pcall(SocialService.PromptGameInvite, SocialService, LocalPlayer, options)
		if not ok then
			Log.warn("[BoostBar] PromptGameInvite failed:", err)
		end
		_invitePending = false
	end)
end

--[[
	弹 Roblox 官方会员订阅；已是会员只提示
	@return nil - 无返回值
]]
local function _promptPremium()
	if LocalPlayer.MembershipType == Enum.MembershipType.Premium then
		TipsModule.NormalTips(LocalPlayer, "已是Roblox会员")
		return
	end
	local ok, err = pcall(MarketplaceService.PromptPremiumPurchase, MarketplaceService, LocalPlayer)
	if not ok then
		Log.warn("[BoostBar] PromptPremiumPurchase failed:", err)
	end
end

--[[
	绑定右下角加成栏静态节点、文案与镜像监听（ArmWrestleHUD.Init 调一次）
	@param gui Frame - ArmWrestleHUD 容器（Common.gui）
	@return Frame - Boost 分组，供对局中隐藏
]]
function BoostBar.Bind(gui: Frame): Frame
	local boost = Common.Get(gui, "Boost") :: Frame

	local friendBtn = Common.Get(boost, "FriendButton") :: ImageButton
	local friendTip = Common.Get(friendBtn, "Tip") :: Frame
	_friendValue = Common.Get(friendBtn, "Value") :: TextLabel
	Common.SetText(Common.Get(friendTip, "Title") :: TextLabel, "好友加成")
	Common.SetText(Common.Get(friendTip, "Band", "Desc") :: TextLabel, "帮助增加你的现金收入")
	_bindTip(friendBtn, friendTip)
	friendBtn.MouseButton1Click:Connect(_promptInvite)

	local premiumBtn = Common.Get(boost, "PremiumButton") :: ImageButton
	local premiumTip = Common.Get(premiumBtn, "Tip") :: Frame
	_premiumValue = Common.Get(premiumBtn, "Value") :: TextLabel
	Common.SetText(Common.Get(premiumTip, "Title") :: TextLabel, "Roblox高级加成")
	Common.SetText(
		Common.Get(premiumTip, "Band", "Desc") :: TextLabel,
		"帮助你将现金增加{1}%",
		{ tostring(math.floor(ArmWrestleConfig.PREMIUM_BOOST * PERCENT + 0.5)) }
	)
	_bindTip(premiumBtn, premiumTip)
	premiumBtn.MouseButton1Click:Connect(_promptPremium)

	LocalPlayer:GetAttributeChangedSignal(ATTR_FRIEND):Connect(function()
		_renderValue(_friendValue, ATTR_FRIEND)
		Style.Pop(friendBtn)
	end)
	LocalPlayer:GetAttributeChangedSignal(ATTR_PREMIUM):Connect(function()
		_renderValue(_premiumValue, ATTR_PREMIUM)
		Style.Pop(premiumBtn)
	end)
	_render()
	return boost
end

return BoostBar
