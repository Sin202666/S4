--[[
	Module: TopBarManager
	Description: 客户端 TopbarPlus 顶栏图标管理器，注册声音开关、反馈、每日签到等入口
	Author: 林奥宇
	Created: 2026-07-03
	Last Modified: 2026-10-15

	功能：
	- 独立图标：声音开关、反馈、每日签到
	- 已下线右侧「SettingMenu」下拉菜单
	- 已下线好友邀请顶栏入口
	- 已下线公告（NewsMail_Full）与更新版本顶栏入口
	- 声音开关：一键同时开/关背景音乐与游戏音效（BGM/EFFECT 写 0 或 100）
	  · 图标状态只读 player.Setting.BGM/EFFECT 镜像；任一 > 0 视为开
	  · 写入经 SETTING_CHANGE 由服务端 SystemSet 校验存档；音效组音量仍只由 SettingManager 写
	- 已下线设置全屏弹窗与齿轮入口（兑换码/称号/键位等随之无入口，存档值保留）
	- 反馈走 Roblox 官方 SocialService:PromptFeedbackSubmissionAsync（Creator Hub > Audience > Feedback 查看）；
	  Studio 试玩不弹窗，每人每天限一次，游戏所有者不可提交
	- 每日签到图标受 GameConfig「每日签到.启用」门控；关闭不建入口（当前暂时下线，创建调用已注释）
	- 不提供在线奖励顶栏入口（已下线入口；OnlineAward 弹窗与服务端结算保留）
	- 不提供背包仓库入口（仓库层已停用，Main.Backpack 只显示快捷栏）
	- ShowUI（默认禁用）：经 SETTING_CHANGE 切换 HideUI

	依赖：
	- TopbarPlus Icon：第三方包，未纳入 UtilsSystem，顶部直接 require
	- Utils.NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, ...)：经 UIManager 开关界面
	- Utils.NetWork.InvokeServer(NetMsg.SETTING_CHANGE, ...)：声音开关 / HideUI 设置变更

	约定：
	- 本文件为 StarterPlayerScripts LocalScript，启动即绑定图标，无 Init() / 模块表
	- ScreenGui 下须存在 DailyReward Frame

	示例：
	NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, "DailyReward")
	NetWork.InvokeServer(NetMsg.SETTING_CHANGE, "BGM", 0)
	NetWork.InvokeServer(NetMsg.SETTING_CHANGE, "HideUI", 1)
]]

-- ========================================
-- 服务引用
-- ========================================
local SocialService = game:GetService("SocialService")

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

-- TopbarPlus 第三方包，未纳入 UtilsSystem
local Icon = require(game.ReplicatedStorage.ClientSideCode.Tool.TopbarPlus.Icon)

local EnumMgr = Utils.EnumMgr
local LocalPlayer = Utils.LocalPlayer
local Log = Utils.Log
local NetMsg = Utils.NetMsg
local NetWork = Utils.NetWork
local SystemGameConfig = Utils.SystemGameConfig

-- ========================================
-- 常量
-- ========================================
local UI_NAME_DAILY_REWARD = "DailyReward"

local SETTING_KEY_HIDE_UI = "HideUI"
local SETTING_KEY_BGM = "BGM"
local SETTING_KEY_EFFECT = "EFFECT"
local SETTING_FOLDER = EnumMgr.PlayerInst.SettingFolder
local SETTING_WAIT_TIMEOUT_SEC = 30
-- settingConf BGM/EFFECT range 上下界
local SOUND_VOLUME_ON = 100
local SOUND_VOLUME_OFF = 0

local ICON_NAME_SOUND = "SoundToggle"
local ICON_NAME_FEEDBACK = "feedback"
local ICON_NAME_SHOW_UI = "ShowUI"
local ICON_NAME_DAILY_REWARD = "dailyreward"

local ICON_ORDER_SECONDARY = 2
local ICON_ORDER_FEEDBACK = 0
local ICON_ORDER_DAILY_REWARD = 2

local IMAGE_SOUND_ON = "rbxassetid://80354343022617"
local IMAGE_SOUND_OFF = "rbxassetid://87810277316848"
local IMAGE_FEEDBACK = "rbxassetid://71141863602929"
local IMAGE_SHOW_UI = "rbxassetid://108026101285797"
local DAILY_REWARD_IMAGE = "rbxassetid://15282926127"

local SCALE_ICON_DEFAULT = 0.65
local SCALE_FEEDBACK = 0.7
local SCALE_DAILY_REWARD = 1

local CORNER_RADIUS_CIRCLE = UDim.new(1, 0)

local NOTICE_BG_COLOR = Color3.new(1, 0, 0.0156863)
local NOTICE_LABEL_COLOR = Color3.new(1, 1, 1)

-- ========================================
-- 私有变量
-- ========================================
local _soundIcon: any = nil
local _bgmValue: NumberValue? = nil
local _effectValue: NumberValue? = nil
local _isSoundTogglePending = false

-- ========================================
-- 私有函数
-- ========================================

--[[
	为 TopbarPlus 图标应用统一红点通知主题
	@param icon any - TopbarPlus Icon 实例（链式调用返回自身）
	@return any - 配置后的 Icon 实例
]]
local function _applyNoticeTheme(icon: any): any
	return icon
		:modifyTheme({ "Notice", "BackgroundColor3", NOTICE_BG_COLOR })
		:modifyTheme({ "NoticeLabel", "TextColor3", NOTICE_LABEL_COLOR })
end

--[[
	经 UIManager 打开本地 UI
	@param uiName string - ScreenGui 下 Frame 名称
	@param uiData any? - 透传给目标 UI updateUi 的数据；无则传 nil
	@param isShow boolean? - 显式显隐；nil 时切换
	@param isAnim boolean? - 是否播放动画
	@param ... any - 透传给 updateUi
	@return nil - 无返回值
]]
local function _fireShowLocalUI(uiName: string, uiData: any?, isShow: boolean?, isAnim: boolean?, ...)
	NetWork.FireBindable(NetMsg.SHOW_LOCAL_UI, uiName, uiData, isShow, isAnim, ...)
end

--[[
	绑定顶栏图标点击：打开本地 UI 并清除通知/选中态
	@param icon any - TopbarPlus Icon 实例
	@param uiName string - ScreenGui 下 Frame 名称
	@param isShow boolean? - 显式显隐；nil 时切换
	@param isAnim boolean? - 是否播放动画；默认 true
	@return nil - 无返回值
]]
local function _bindOpenUiClick(icon: any, uiName: string, isShow: boolean?, isAnim: boolean?)
	icon:bindEvent("selected", function()
		_fireShowLocalUI(uiName, nil, isShow, isAnim)
		icon:clearNotices()
		icon:deselect()
	end)
end

--[[
	当前声音是否开启（BGM / EFFECT 任一 > 0 视为开；镜像未就绪时视为开）
	@return boolean - 开启为 true
]]
local function _isSoundOn(): boolean
	if not _bgmValue or not _effectValue then
		return true
	end
	return _bgmValue.Value > SOUND_VOLUME_OFF or _effectValue.Value > SOUND_VOLUME_OFF
end

--[[
	按开关状态刷新声音图标图片
	@param isOn boolean - true 显示开启图，false 显示静音图
	@return nil - 图标未创建时跳过
]]
local function _applySoundIconImage(isOn: boolean)
	if not _soundIcon then
		return
	end
	_soundIcon:setImage(if isOn then IMAGE_SOUND_ON else IMAGE_SOUND_OFF)
end

--[[
	按 player.Setting 镜像刷新声音图标
	@return nil - 无返回值
]]
local function _refreshSoundIcon()
	_applySoundIconImage(_isSoundOn())
end

--[[
	上送单项音量设置到服务端 SystemSet
	@param showName string - settingConf.ShowName（BGM / EFFECT）
	@param volume number - 目标音量，SOUND_VOLUME_ON 或 SOUND_VOLUME_OFF
	@return boolean - 服务端写入成功为 true
]]
local function _pushVolumeSetting(showName: string, volume: number): boolean
	local ok, result = pcall(function()
		return NetWork.InvokeServer(NetMsg.SETTING_CHANGE, showName, volume)
	end)
	if not ok or result ~= true then
		Log.warn("[TopBarManager] SETTING_CHANGE failed:", showName, volume, result)
		return false
	end
	return true
end

--[[
	切换声音开关：BGM 与 EFFECT 同时写入同一目标值；请求进行中忽略重复点击
	@return nil - 镜像未就绪或请求进行中时跳过
]]
local function _toggleSound()
	if _isSoundTogglePending or not _bgmValue or not _effectValue then
		return
	end
	_isSoundTogglePending = true
	local targetVolume = if _isSoundOn() then SOUND_VOLUME_OFF else SOUND_VOLUME_ON
	_applySoundIconImage(targetVolume > SOUND_VOLUME_OFF)
	task.spawn(function()
		_pushVolumeSetting(SETTING_KEY_BGM, targetVolume)
		_pushVolumeSetting(SETTING_KEY_EFFECT, targetVolume)
		_isSoundTogglePending = false
		_refreshSoundIcon()
	end)
end

--[[
	等待 player.Setting 下指定音量 NumberValue
	@param folder Instance - player.Setting 文件夹
	@param name string - NumberValue.Name（BGM / EFFECT）
	@return NumberValue? - 有效实例；超时或类型不符为 nil
]]
local function _waitVolumeValue(folder: Instance, name: string): NumberValue?
	local inst = folder:WaitForChild(name, SETTING_WAIT_TIMEOUT_SEC)
	if not inst or not inst:IsA("NumberValue") then
		Log.warn("[TopBarManager] 等待 Setting." .. name .. " 超时或类型不符")
		return nil
	end
	return inst
end

--[[
	异步绑定 BGM / EFFECT 镜像变化到声音图标（不阻塞其它顶栏图标创建）
	@return nil - 无返回值
]]
local function _bindSoundSettingValues()
	task.spawn(function()
		local folder = LocalPlayer:WaitForChild(SETTING_FOLDER, SETTING_WAIT_TIMEOUT_SEC)
		if not folder then
			Log.warn("[TopBarManager] 等待 Setting 文件夹超时，声音开关不可用")
			return
		end
		local bgmValue = _waitVolumeValue(folder, SETTING_KEY_BGM)
		local effectValue = _waitVolumeValue(folder, SETTING_KEY_EFFECT)
		if not bgmValue or not effectValue then
			return
		end
		_bgmValue = bgmValue
		_effectValue = effectValue
		bgmValue.Changed:Connect(_refreshSoundIcon)
		effectValue.Changed:Connect(_refreshSoundIcon)
		_refreshSoundIcon()
	end)
end

--[[
	创建声音开关顶栏图标（一键开/关背景音乐 + 游戏音效）
	@return nil - 无返回值
]]
local function _createSoundToggleIcon()
	local soundIcon = Icon.new()
		:setName(ICON_NAME_SOUND)
		:setRight()
		:setOrder(ICON_ORDER_SECONDARY)
		:setLabel("")
		:setImage(IMAGE_SOUND_ON)
		:setImageScale(SCALE_ICON_DEFAULT)
		:setCornerRadius(CORNER_RADIUS_CIRCLE)
		:autoDeselect(false)
	_soundIcon = soundIcon

	soundIcon:bindEvent("selected", function()
		soundIcon:deselect()
		_toggleSound()
	end)

	_bindSoundSettingValues()
end

--[[
	弹出 Roblox 官方反馈对话框（PromptFeedbackSubmissionAsync 会 yield 到提交或关闭，须在独立线程调用）
	@return nil - 无返回值
]]
local function _promptRobloxFeedback()
	task.spawn(function()
		local ok, err = pcall(SocialService.PromptFeedbackSubmissionAsync, SocialService, {
			FeedbackType = Enum.FeedbackType.Feedback,
		})
		if not ok then
			Log.warn("[TopBarManager] PromptFeedbackSubmissionAsync failed:", err)
		end
	end)
end

--[[
	创建外层反馈顶栏图标（不挂入 SettingMenu 下拉）
	@return any - feedback TopbarPlus Icon
]]
local function _createFeedbackIcon(): any
	local feedbackIcon = Icon.new()
		:setName(ICON_NAME_FEEDBACK)
		:setRight()
		:setImageScale(SCALE_FEEDBACK)
		:setOrder(ICON_ORDER_FEEDBACK)
		:setLabel("")
		:setImage(IMAGE_FEEDBACK)
		:setCornerRadius(CORNER_RADIUS_CIRCLE)
		:autoDeselect(false)

	feedbackIcon:bindEvent("selected", function()
		_promptRobloxFeedback()
		feedbackIcon:deselect()
	end)

	return feedbackIcon
end

--[[
	创建 HideUI 调试顶栏图标（默认禁用）
	@return any - ShowUI TopbarPlus Icon
]]
local function _createShowUIIcon(): any
	local showUiIcon = Icon.new()
		:setEnabled(false)
		:setName(ICON_NAME_SHOW_UI)
		:setRight()
		:setImageScale(SCALE_FEEDBACK)
		:setOrder(ICON_ORDER_FEEDBACK)
		:setLabel("")
		:setImage(IMAGE_SHOW_UI)
		:setCornerRadius(CORNER_RADIUS_CIRCLE)
		:autoDeselect(false)

	_applyNoticeTheme(showUiIcon)

	showUiIcon:bindEvent("selected", function()
		NetWork.InvokeServer(NetMsg.SETTING_CHANGE, SETTING_KEY_HIDE_UI, 1)
		showUiIcon:deselect()
	end)

	return showUiIcon
end

--[[
	创建每日签到顶栏图标
	@return nil - 无返回值
]]
local function _createDailyRewardIcon()
	local icon = Icon.new()
		:setName(ICON_NAME_DAILY_REWARD)
		:setRight()
		:setImageScale(SCALE_DAILY_REWARD)
		:setOrder(ICON_ORDER_DAILY_REWARD)
		:setImage(DAILY_REWARD_IMAGE)
		:setCornerRadius(CORNER_RADIUS_CIRCLE)
		:autoDeselect(false)

	_applyNoticeTheme(icon)
	_bindOpenUiClick(icon, UI_NAME_DAILY_REWARD)
end

-- ========================================
-- 初始化
-- ========================================
_createSoundToggleIcon()
_createFeedbackIcon()
_createShowUIIcon()

-- 每日签到暂时下线：入口已注释，恢复时取消注释并把 GameConfig「每日签到.启用」改回 true
-- if SystemGameConfig.GetValue({ "每日签到", "启用" }) ~= false then
-- 	_createDailyRewardIcon()
-- end
