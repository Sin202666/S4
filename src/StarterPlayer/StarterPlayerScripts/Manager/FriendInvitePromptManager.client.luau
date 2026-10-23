--[[
	Module: FriendInvitePromptManager
	Description: 好友邀请提示管理器（客户端），定时在屏幕右下角弹 Roblox 原生通知，提示「某好友在线」并可一键邀请
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	功能：
	- 进入游戏后等待 GameConfig.好友邀请提示.进入后延迟秒，之后每隔 间隔秒 尝试弹一次，每会话最多 每会话最多次数 次
	- 通知走 StarterGui:SetCore("SendNotification")：好友头像 + 「{名字} 在线中」+ 按钮「邀请 / 稍后」
	- 点「邀请」：CanSendGameInviteAsync 通过后用 ExperienceInviteOptions.InviteUser 定向弹 Roblox 官方邀请框
	- 候选好友 = GetFriendsOnline 去掉已在本服的玩家；优先挑本会话还没提示过的好友，再随机
	- 对局中（玩家 Attribute InBattle）、无可邀请好友、查询失败时本轮不弹也不占次数，RETRY_INTERVAL 秒后重试
	- 不落存档、不走 Remote

	加载方式：
	- 本文件是 StarterPlayerScripts LocalScript，客户端自动运行
	- 不是 Utils 模块，禁止 require；不要写 Utils.FriendInvitePromptManager

	配置（GameConfig.好友邀请提示）：
	- 启用：false 时不计时、不弹出
	- 进入后延迟秒 / 间隔秒 / 每会话最多次数 / 通知停留秒：非法或 ≤0 时回落缺省并 Log.warn

	约定：
	- 纯表现层提示，邀请结果仅用于日志；不据此发奖（好友加成由服务端 SystemArmWrestle.Boost 判定）
	- GetFriendsOnline 有频率限制，两次调用间隔不小于 RETRY_INTERVAL
	- Studio 中 PromptGameInvite 可能不弹框，以正式服为准
]]

-- ============================================================================
-- 服务引用
-- ============================================================================

local Players = game:GetService("Players")
local SocialService = game:GetService("SocialService")
local StarterGui = game:GetService("StarterGui")

-- ============================================================================
-- 模块引用
-- ============================================================================

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local Log = Utils.Log
local EnumMgr = Utils.EnumMgr
local LocalPlayer = Utils.LocalPlayer
local SystemGameConfig = Utils.SystemGameConfig
local TranslationHelper = Utils.TranslationHelper

-- ============================================================================
-- 常量
-- ============================================================================

local CONFIG_ROOT = "好友邀请提示"
local DEFAULTS = table.freeze({
	["进入后延迟秒"] = 90,
	["间隔秒"] = 600,
	["每会话最多次数"] = 3,
	["通知停留秒"] = 10,
})
local RETRY_INTERVAL = 60
local SET_CORE_RETRY_COUNT = 5
local SET_CORE_RETRY_INTERVAL = 1
local MAX_FRIENDS_QUERY = 200
local HEADSHOT_URL = "rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"

-- ============================================================================
-- 私有变量
-- ============================================================================

local _notified: { [number]: boolean } = {}
local _invitePending = false
local _notifyCallback: BindableFunction? = nil
local _pendingUserId: number? = nil

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	读取 GameConfig.好友邀请提示 下的正数字段；非法或 ≤0 时回落缺省并打日志
	@param field string - 字段名，须为 DEFAULTS 的键（进入后延迟秒 / 间隔秒 / 每会话最多次数 / 通知停留秒）
	@return number - 有效配置值，或 DEFAULTS[field]
]]
local function _getNumber(field: string): number
	local value = SystemGameConfig.GetValue({ CONFIG_ROOT, field })
	if typeof(value) == "number" and value > 0 then
		return value
	end
	Log.warn("FriendInvitePromptManager: 配置非法，使用缺省", CONFIG_ROOT .. "." .. field, value, DEFAULTS[field])
	return DEFAULTS[field]
end

--[[
	拉取可邀请的在线好友（排除已在本服的玩家）
	@return { table }? - 好友信息数组，元素含 VisitorId:number / DisplayName:string / UserName:string；查询失败返回 nil
]]
local function _getInvitableFriends(): { { [string]: any } }?
	local ok, result = pcall(LocalPlayer.GetFriendsOnline, LocalPlayer, MAX_FRIENDS_QUERY)
	if not ok then
		Log.warn("FriendInvitePromptManager: GetFriendsOnline 失败", result)
		return nil
	end
	local list = {}
	for _, info in ipairs(result) do
		local userId = info.VisitorId
		if typeof(userId) == "number" and not Players:GetPlayerByUserId(userId) then
			table.insert(list, info)
		end
	end
	return list
end

--[[
	从候选中挑一位好友：优先本会话未提示过的，其次全部候选，均随机
	@param friends { table } - _getInvitableFriends 的非空结果
	@return table - 选中的好友信息（VisitorId / DisplayName / UserName）
]]
local function _pickFriend(friends: { { [string]: any } }): { [string]: any }
	local fresh = {}
	for _, info in ipairs(friends) do
		if not _notified[info.VisitorId] then
			table.insert(fresh, info)
		end
	end
	local pool = if #fresh > 0 then fresh else friends
	return pool[math.random(1, #pool)]
end

--[[
	向指定好友弹 Roblox 官方邀请框（CanSendGameInviteAsync 会 yield，放独立线程；请求进行中忽略重复点击）
	@param userId number - 被邀请好友的 UserId
	@return nil - 无返回值
]]
local function _promptInvite(userId: number)
	if _invitePending then
		return
	end
	_invitePending = true
	task.spawn(function()
		local okCan, canSend = pcall(SocialService.CanSendGameInviteAsync, SocialService, LocalPlayer, userId)
		if not okCan or canSend ~= true then
			_invitePending = false
			Log.warn("FriendInvitePromptManager: 无法邀请", userId, canSend)
			return
		end
		local options = Instance.new("ExperienceInviteOptions")
		options.InviteUser = userId
		options.PromptMessage = TranslationHelper.TranslateByKey("邀请好友")
		local ok, err = pcall(SocialService.PromptGameInvite, SocialService, LocalPlayer, options)
		if not ok then
			Log.warn("FriendInvitePromptManager: PromptGameInvite 失败", err)
		end
		_invitePending = false
	end)
end

--[[
	原生通知按钮回调；SetCore 只回传按钮文案，故用 _pendingUserId 记录当前通知对应的好友
	@param buttonText string - 被点击按钮的展示文案
	@return nil - 无返回值
]]
local function _onNotifyButton(buttonText: string)
	local userId = _pendingUserId
	_pendingUserId = nil
	if userId and buttonText == TranslationHelper.TranslateByKey("邀请") then
		_promptInvite(userId)
	end
end

--[[
	调用 SetCore 发通知；CoreScript 未就绪时 SetCore 会报错，按 SET_CORE_RETRY_COUNT 次重试
	@param payload table - SendNotification 参数（Title / Text / Icon / Duration / Button1 / Button2 / Callback）
	@return boolean - 是否发送成功
]]
local function _sendNotification(payload: { [string]: any }): boolean
	for attempt = 1, SET_CORE_RETRY_COUNT do
		local ok, err = pcall(StarterGui.SetCore, StarterGui, "SendNotification", payload)
		if ok then
			return true
		end
		Log.warn("FriendInvitePromptManager: SendNotification 失败", attempt, err)
		if attempt < SET_CORE_RETRY_COUNT then
			task.wait(SET_CORE_RETRY_INTERVAL)
		end
	end
	return false
end

--[[
	尝试弹一次好友在线通知
	@return boolean - true=已弹出（计入次数）；false=对局中 / 无可邀请好友 / 查询或发送失败
]]
local function _tryNotify(): boolean
	if LocalPlayer:GetAttribute(EnumMgr.PlayerAttr.InBattle) == true then
		return false
	end
	local friends = _getInvitableFriends()
	if not friends or #friends == 0 then
		return false
	end
	local friend = _pickFriend(friends)
	local name = if typeof(friend.DisplayName) == "string" and friend.DisplayName ~= "" then friend.DisplayName else tostring(friend.UserName)
	_pendingUserId = friend.VisitorId
	local sent = _sendNotification({
		Title = TranslationHelper.TranslateByKey("好友在线标题"),
		Text = TranslationHelper.TranslateByKey("好友在线邀请", { name }),
		Icon = string.format(HEADSHOT_URL, friend.VisitorId),
		Duration = _getNumber("通知停留秒"),
		Button1 = TranslationHelper.TranslateByKey("邀请"),
		Button2 = TranslationHelper.TranslateByKey("稍后"),
		Callback = _notifyCallback,
	})
	if not sent then
		_pendingUserId = nil
		return false
	end
	_notified[friend.VisitorId] = true
	return true
end

--[[
	提示主循环：首延迟后按间隔弹出，未弹成功时短间隔重试且不占次数
	@return nil - 无返回值
]]
local function _runLoop()
	task.wait(_getNumber("进入后延迟秒"))
	local maxCount = _getNumber("每会话最多次数")
	local shown = 0
	while shown < maxCount do
		if _tryNotify() then
			shown += 1
			task.wait(_getNumber("间隔秒"))
		else
			task.wait(RETRY_INTERVAL)
		end
	end
end

-- ============================================================================
-- 初始化
-- ============================================================================

if SystemGameConfig.GetValue({ CONFIG_ROOT, "启用" }) == true then
	local callback = Instance.new("BindableFunction")
	callback.OnInvoke = _onNotifyButton
	_notifyCallback = callback
	task.spawn(_runLoop)
end
