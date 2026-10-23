--[[
	Module: OfflinePanel
	Description: 扳手腕离线奖励弹窗：进服有待领离线时长时弹出，展示离线时长与预估力量，点击领取请求服务端结算
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	功能：
	- 只读服务端镜像 OfflinePending（待领离线秒数）/ OfflineStrength（预估力量）；OfflinePending > 0 时显示
	- 领取：Invoke("ClaimOffline")，结算与「+X 力量」提示全在服务端 SystemArmWrestle.Offline；成功后撒彩纸并收起
	- 关闭：仅本会话不再弹出，待领时长保留在档案，下次进服再弹
	- 音效（SystemUISfx）：领取成功播奖励音

	静态 UI（Studio 维护于 StarterGui.ScreenGui.ArmWrestleHUD，本模块只绑定不新建，节点名为代码契约）：
	- OfflineReward(Frame，默认隐藏，UIScale)
	  - Title（标题）/ Time（离线时长）/ Reward（预估力量）
	  - ClaimButton / Label（领取）
	  - CloseButton / Label（X）

	与相关模块：
	- ArmWrestleHUD.init：_bindHud 时 Bind 一次
	- 服务端 SystemArmWrestle.Offline：离线时长结算、力量计算与领取

	加载：
		local OfflinePanel = require(script.OfflinePanel)
		OfflinePanel.Bind(Common.gui)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local LocalPlayer = Utils.LocalPlayer
local ArmWrestleConfig = Utils.ArmWrestleConfig
local ArmWrestleStyle = Utils.ArmWrestleStyle
local TipsModule = Utils.TipsModule
local SystemUISfx = Utils.SystemUISfx

local Common = require(script.Parent.Common)

local Style = ArmWrestleStyle

local OfflinePanel = {}

local ACTION_CLAIM = "ClaimOffline"
local ERR_NONE = "none"
local ATTR_PENDING = "OfflinePending"
local ATTR_STRENGTH = "OfflineStrength"
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_MINUTE = 60

local _root: Frame?
local _time: TextLabel?
local _reward: TextLabel?
local _dismissed = false
local _claiming = false

--[[
	按镜像刷新弹窗显隐与文案
	@return nil - 未绑定时跳过
]]
local function _render()
	local root = _root
	if not root then
		return
	end
	local pending = Common.Attr(ATTR_PENDING, 0)
	local show = pending > 0 and not _dismissed
	if not show then
		root.Visible = false
		return
	end
	if _time then
		local hours = pending // SECONDS_PER_HOUR
		local minutes = (pending % SECONDS_PER_HOUR) // SECONDS_PER_MINUTE
		Common.SetText(_time, "离线时长", { tostring(hours), tostring(minutes) })
	end
	if _reward then
		Common.SetText(_reward, "获得力量", { ArmWrestleConfig.Format(Common.Attr(ATTR_STRENGTH, 0)) })
	end
	if not root.Visible then
		root.Visible = true
		Style.Pop(root)
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
		if _root then
			_root.Visible = false
		end
		return
	end
	if result ~= ERR_NONE then
		TipsModule.ErrorTips(LocalPlayer, "领取离线奖励失败")
	end
	_render()
end

--[[
	关闭弹窗：本会话不再弹出，待领时长保留到下次进服
	@return nil
]]
local function _dismiss()
	_dismissed = true
	if _root then
		_root.Visible = false
	end
end

--[[
	绑定离线奖励弹窗静态节点、文案与镜像监听（ArmWrestleHUD.Init 调一次）
	@param gui Frame - ArmWrestleHUD 容器（Common.gui）
	@return Frame - OfflineReward 弹窗
]]
function OfflinePanel.Bind(gui: Frame): Frame
	local root = Common.Get(gui, "OfflineReward") :: Frame
	root.Visible = false
	_root = root
	_time = Common.Get(root, "Time") :: TextLabel
	_reward = Common.Get(root, "Reward") :: TextLabel
	Common.SetText(Common.Get(root, "Title") :: TextLabel, "恭喜你离线获得小标题")

	local claimBtn = Common.Get(root, "ClaimButton") :: TextButton
	Common.SetText(Common.Get(claimBtn, "Label") :: TextLabel, "领取")
	claimBtn.MouseButton1Click:Connect(_claim)

	local closeBtn = Common.Get(root, "CloseButton") :: TextButton
	Common.SetRaw(Common.Get(closeBtn, "Label") :: TextLabel, "X")
	closeBtn.MouseButton1Click:Connect(_dismiss)

	LocalPlayer:GetAttributeChangedSignal(ATTR_PENDING):Connect(_render)
	LocalPlayer:GetAttributeChangedSignal(ATTR_STRENGTH):Connect(_render)
	_render()
	return root
end

return OfflinePanel
