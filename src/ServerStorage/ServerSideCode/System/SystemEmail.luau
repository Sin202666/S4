--[[
	Module: SystemEmail
	Description: 邮件先以 MailId 在玩家档原子发奖，再确认邮箱 IsSynced；确认失败重试不会重复发奖。支持稳定 MailId 的幂等离线投递。
	Author: 林奥宇
	Last Modified: 2026-10-12
	Created: 2026-10-12
]]

-- ========================================
-- 服务引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local Players = Utils.Players
local SystemBag = Utils.SystemBag
local SystemSave = Utils.SystemSave
local SystemShop = Utils.SystemShop
local SystemBuyRoblox = Utils.SystemBuyRoblox
local SystemDataStore = Utils.SystemDataStore
local PlayerData = Utils.PlayerData
local CfgFind = Utils.CfgFind
local EnumMgr = Utils.EnumMgr
local Log = Utils.Log
local HttpService = Utils.HttpService
local Struct = Utils.Struct
local Copy = Utils.Copy
local UpdateModule = Utils.UpdateModule

-- ========================================
-- 模块定义
-- ========================================
local SystemEmail = {}

-- ========================================
-- 常量定义
-- ========================================
local EMAIL_STORE = SystemDataStore.STORE.Email

local MAX_REWARD_ITEMS = 20
local MAX_ITEM_COUNT = 9999
local MAX_UNSYNCED_MAILS = 50
local MAX_TAG_TITLE_LEN = 64
local MAX_CONTENT_TITLE_LEN = 200
local MAX_UPDATE_TEXT_LEN = 2000
local _deliveryBusy, _retryState = setmetatable({}, { __mode = "k" }), setmetatable({}, { __mode = "k" })
local _deliveryStarted = false

-- ========================================
-- 私有函数
-- ========================================

--[[
	校验玩家是否仍在线且有效

	@param plr Player - 待校验玩家
	@return boolean - true 表示玩家有效
]]
local function _validatePlayer(plr: Player): boolean
	return plr ~= nil and plr.Parent ~= nil
end

--[[
	将任意值截断为不超过 maxLen 字节的字符串，且落在 UTF-8 码点边界上

	@param value any - 原始值；非 string 时 tostring
	@param maxLen number - 最大字节长度
	@return string - 截断后的文本；value 为 nil 时为空串
]]
local function _truncateString(value: any, maxLen: number): string
	local text = if type(value) == "string" then value else tostring(value or "")
	if #text <= maxLen then
		return text
	end

	local resultEnd = 0
	local walkOk, walkErr = pcall(function()
		for startByte in utf8.codes(text) do
			local nextStart = utf8.offset(text, 2, startByte)
			local charEnd = if nextStart then nextStart - 1 else #text
			if charEnd > maxLen then
				break
			end
			resultEnd = charEnd
		end
	end)
	if walkOk then
		return string.sub(text, 1, resultEnd)
	end

	Log.warn("SystemEmail: UTF-8 截断回退为按字节", walkErr)
	return string.sub(text, 1, maxLen)
end

--[[
	解析并校验目标 UserId

	@param rawUserId any - 邮件入参 UserID
	@return number? - 正整数 UserId；非法为 nil
]]
local function _parseUserId(rawUserId: any): number?
	local userId = tonumber(rawUserId)
	if not userId or userId ~= userId or userId <= 0 or userId ~= math.floor(userId) then
		return nil
	end
	return userId
end

--[[
	获取玩家存档中的 Email 表

	@param plr Player - 玩家对象
	@return table? - Email 存档表；无数据时 nil
]]
local function _getEmailData(plr: Player)
	return PlayerData.GetPlrDataByKey(plr, "Email")
end

--[[
	判断 DS 邮件是否尚未发放

	@param mail any - DS 邮件条目；IsSynced 为 nil/0 表示待发放
	@return boolean - true 表示待发放
]]
local function _isMailPendingSync(mail: any): boolean
	if type(mail) ~= "table" then
		return false
	end
	local isSynced = mail.IsSynced
	return isSynced == nil or isSynced == 0
end

--[[
	统计 DS 列表中待发放邮件数量

	@param data any - Email DS 数组
	@return number - pending 条数
]]
local function _countPendingMails(data: any): number
	if type(data) ~= "table" then
		return 0
	end
	local pending = 0
	for _, mail in ipairs(data) do
		if _isMailPendingSync(mail) then
			pending += 1
		end
	end
	return pending
end

--[[
	校验奖励列表并拷贝为平行数组

	@param rewardID any - 奖励 ID 列表
	@param rewardCount any - 对应数量列表
	@return {number}?, {number}?, string? - 拷贝后的 ID、数量；失败时第三项为错误码
]]
local function _sanitizeRewardLists(rewardID: any, rewardCount: any, allowEmpty: boolean?, frozenProduct: boolean?): ({ number }?, { number }?, string?)
	if type(rewardID) ~= "table" or type(rewardCount) ~= "table" then
		return nil, nil, "INVALID_REWARD_LIST"
	end
	if #rewardID ~= #rewardCount then
		return nil, nil, "REWARD_LIST_MISMATCH"
	end
	if #rewardID == 0 then
		if allowEmpty and next(rewardID) == nil and next(rewardCount) == nil then return {}, {}, nil end
		return nil, nil, "EMPTY_REWARD_LIST"
	end
	if #rewardID > (if frozenProduct then 1000 else MAX_REWARD_ITEMS) then
		return nil, nil, "TOO_MANY_REWARDS"
	end

	local ids: { number } = {}
	local counts: { number } = {}
	for _, array in ipairs({ rewardID, rewardCount }) do
		local size = 0
		for key in pairs(array) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > #array then return nil, nil, "INVALID_REWARD_LIST" end
			size += 1
		end
		if size ~= #array then return nil, nil, "INVALID_REWARD_LIST" end
	end
	for index, rawId in ipairs(rewardID) do
		local itemId = tonumber(rawId)
		local count = tonumber(rewardCount[index])
		if not itemId or itemId ~= math.floor(itemId) or itemId <= 0 or itemId >= 2^53 then
			return nil, nil, "INVALID_REWARD_ID"
		end
		if not count or count ~= math.floor(count) or count < 1 or count > (if frozenProduct then 2^53 - 1 else MAX_ITEM_COUNT) then
			return nil, nil, "INVALID_REWARD_COUNT"
		end
		if not CfgFind.FindCfgByID(itemId) then
			return nil, nil, "UNKNOWN_REWARD_ID"
		end
		ids[index] = itemId
		counts[index] = count
	end
	return ids, counts, nil
end

--[[
	清洗 Ex_Data：丢弃药水等未知键；仅保留合法礼品解锁字段

	@param exData any - 客户端/运营传入的 Ex_Data
	@return table?, string? - 清洗后的表；失败时第二项为错误码
]]
local function _sanitizeExData(exData: any): ({ [string]: any }?, string?)
	if exData == nil then
		return {}, nil
	end
	if type(exData) ~= "table" then
		return nil, "INVALID_EX_DATA"
	end

	if exData.GrantSnapshot ~= nil then
		local snapshot = exData.GrantSnapshot
		if type(snapshot) ~= "table" or snapshot.version ~= 1
			or (snapshot.kind ~= "Items" and snapshot.kind ~= "GamePass" and snapshot.kind ~= "OnlineAward")
			or type(snapshot.OnlyTag) ~= "string" then return nil, "INVALID_GRANT_SNAPSHOT" end
		local ids, counts = _sanitizeRewardLists(snapshot.itemID, snapshot.itemCount, snapshot.kind ~= "Items", true)
		if not ids or not counts then return nil, "INVALID_GRANT_SNAPSHOT" end
		if snapshot.kind == "GamePass" and (type(snapshot.passID) ~= "number" or snapshot.passID <= 0 or snapshot.passID >= 2^53 or snapshot.passID % 1 ~= 0) then
			return nil, "INVALID_GRANT_SNAPSHOT"
		end
		return { GrantSnapshot = { version = 1, kind = snapshot.kind, OnlyTag = snapshot.OnlyTag,
			passID = snapshot.passID, itemID = ids, itemCount = counts } }, nil
	end

	local isGift = tonumber(exData.IsGift)
	if isGift == 1 then
		local passID = tonumber(exData.PassID)
		if not passID or passID ~= math.floor(passID) or passID <= 0 then
			return nil, "INVALID_GIFT_PASS"
		end
		if not CfgFind.FindCfgByPassID(passID) then
			return nil, "INVALID_GIFT_PASS"
		end
		return { IsGift = 1, PassID = passID }, nil
	end

	return {}, nil
end

--[[
	将 DS 邮件转为发奖用结构（剥离 DS 专用字段）

	@param dsMail Struct.DsEmail - DataStore 邮件条目
	@return Struct.Email - 发奖数据
]]
local function _dsMailToPlayerMail(dsMail: Struct.DsEmail): Struct.Email
	return {
		RewardID = dsMail.RewardID,
		RewardCount = dsMail.RewardCount,
		Ex_Data = dsMail.Ex_Data or {},
		TagTitle = dsMail.TagTitle or "",
		ContentTitle = dsMail.ContentTitle or "",
		UpdateText = dsMail.UpdateText or "",
		Time = dsMail.Time,
		IsRead = dsMail.IsRead or 0,
		IsClaim = dsMail.IsClaim or 0,
	}
end

--[[
	发放普通物品类邮件奖励（含 GamePass 配置 ID；不检查背包容量；药水参数不生效）
	同一封邮件一次 AddItems，避免逐件入包失败导致半包后回滚重复发奖

	@param plr Player - 玩家对象
	@param data Struct.Email - 邮件数据
	@return boolean - true 表示发奖成功
]]
local function _grantItemMailRewards(plr: Player, data: Struct.Email): boolean
	if not _validatePlayer(plr) then
		return false
	end

	local ids, counts = _sanitizeRewardLists(data.RewardID, data.RewardCount)
	if not ids or not counts then return false end

	if #ids == 0 then
		return true
	end

	local ok = SystemBag.AddItems(plr, ids, counts)
	if not ok then
		Log.warn("SystemEmail: 整封入包失败", plr.UserId)
		return false
	end

	return true
end

--[[
	发放单封邮件奖励（老礼品解锁或物品入包）

	@param plr Player - 玩家对象
	@param data Struct.Email - 邮件数据
	@return boolean - true 表示发奖成功
]]
local function _grantMailRewards(plr: Player, data: Struct.Email): boolean
	if not _validatePlayer(plr) or not data then
		return false
	end

	local exData = data.Ex_Data
	if exData and exData.GrantSnapshot then return SystemBuyRoblox.GrantSnapshot(plr, exData.GrantSnapshot) end
	if exData and tonumber(exData.IsGift) == 1 and exData.PassID then
		local giftCfg = CfgFind.FindCfgByPassID(exData.PassID)
		if not giftCfg then
			Log.warn("SystemEmail: Gift Pass 配置缺失", exData.PassID)
			return false
		end
		if giftCfg.cost == EnumMgr.RobuxType.GamePass then
			local ok, err = SystemShop.BuyGamePassSuc(plr, giftCfg.passID)
			if not ok then
				Log.warn("SystemEmail: Gift GamePass 解锁失败", plr.UserId, giftCfg.passID, err)
				return false
			end
			return true
		end

		local buyOk = SystemBuyRoblox.BuyItemEnd(plr, giftCfg.OnlyTag)
		if not buyOk then
			Log.warn("SystemEmail: Gift 商品解锁失败", plr.UserId, giftCfg.OnlyTag)
			return false
		end
		return true
	end

	return _grantItemMailRewards(plr, data)
end

--[[
	发放并清理玩家存档中的老邮件。
	领取标记与奖励同档提交，失败保留待确认事务。

	@param plr Player - 玩家对象
	@return nil
]]
-- 旧邮件的领取标记与奖励在同一份玩家档中提交。
local function _grantAndClearLegacySaveEmails(plr: Player)
	local email = _getEmailData(plr)
	for key, entry in pairs(email or {}) do
		if type(entry) == "table" and entry.IsClaim ~= 1 then
			SystemSave.Transact(plr, "legacy-mail:" .. tostring(key) .. ":" .. tostring(entry.Time), function(data)
				local current = data.Email[key]
				if not current or current.IsClaim == 1 then return true end
				if not _grantMailRewards(plr, current) then return false, "GRANT_FAILED" end
				current.IsClaim = 1
				return true
			end)
		end
	end
end

-- 先同档提交奖励+MailId；成功后确认邮箱。确认失败允许重试，账本阻止重复发放。
local function _grantPendingDsEmails(plr: Player, userIdStr: string): (boolean, string?)
	if not _validatePlayer(plr) then return false, "PLAYER_OFFLINE" end
	-- 为旧邮件补稳定 ID，避免以秒为单位的 Time 冲突；Update 的返回值是唯一读取来源。
	local ok, mails = SystemDataStore.Update(EMAIL_STORE, userIdStr, function(old)
		if type(old) ~= "table" then return {} end
		local kept, recent = {}, 0
		for index = #old, 1, -1 do
			local mail = old[index]
			if type(mail) == "table" and mail.IsSynced == 1 and type(mail.MailId) == "string" and (mail.SyncedAt or 0) > 0 then
				recent += 1
				if recent <= 100 then table.insert(kept, 1, { MailId = mail.MailId, IsSynced = 1, SyncedAt = mail.SyncedAt }) end
			else table.insert(kept, 1, mail) end
		end
		old = kept
		for _, mail in ipairs(old) do
			if _isMailPendingSync(mail) and (type(mail.MailId) ~= "string" or mail.MailId == "") then
				mail.MailId = HttpService:GenerateGUID(false)
			end
		end
		return old
	end)
	if not ok then return false, "DS_READ_FAILED" end
	local processed = 0
	for _, mail in ipairs(mails or {}) do
		if processed >= 10 then return false, "DELIVERY_BACKLOG" end
		if _isMailPendingSync(mail) then
			local granted = SystemSave.Transact(plr, "mail:" .. mail.MailId, function()
				return _grantMailRewards(plr, _dsMailToPlayerMail(mail))
			end)
			if not granted then return false, "GRANT_PENDING" end
			local marked = SystemDataStore.Update(EMAIL_STORE, userIdStr, function(old)
				if type(old) ~= "table" then return nil end
				for _, entry in ipairs(old) do
					if entry.MailId == mail.MailId then entry.IsSynced = 1; entry.SyncedAt = os.time() end
				end
				return old
			end)
			if not marked then return false, "DS_SYNC_FAILED" end
			processed += 1
		end
	end
	return true
end

--[[ 每个在线 Player 单独串行投递；发生故障时保留队列并记录退避时间。
	@param plr Player - 接收者实例
	@return boolean, string? - 投递结果
]]
function SystemEmail.DeliverPending(plr)
	if not _validatePlayer(plr) then return false, "PLAYER_OFFLINE" end
	if _deliveryBusy[plr] then return false, "DELIVERY_BUSY" end
	_deliveryBusy[plr] = true
	local called, ok, err = pcall(function()
		_grantAndClearLegacySaveEmails(plr)
		return _grantPendingDsEmails(plr, tostring(plr.UserId))
	end)
	_deliveryBusy[plr] = nil
	if not called then ok, err = false, "DELIVERY_EXCEPTION" end
	local attempts = if ok then 0 else ((_retryState[plr] and _retryState[plr].attempts or 0) + 1)
	if _validatePlayer(plr) then
		_retryState[plr] = { attempts = attempts, nextAt = os.clock() + math.min(300, 30 * 2^math.min(attempts, 4)), error = err }
	else _retryState[plr] = nil end
	if not ok then Log.warn("Email delivery pending", plr.UserId, err) end
	return ok, err
end

--[[ 启动在线邮箱轮询；Manager 调用一次，跨服写入邮箱也能在在线期间被发现。
	@return nil - 注册调度及清理
]]
function SystemEmail.StartDelivery()
	if _deliveryStarted then return end
	_deliveryStarted = true
	Players.PlayerRemoving:Connect(function(plr) _retryState[plr] = nil end)
	UpdateModule.Register(UpdateModule.INTERVAL.SEC_30, function()
		for _, plr in ipairs(Players:GetPlayers()) do
			local state = _retryState[plr]
			if not state or os.clock() >= state.nextAt then SystemEmail.DeliverPending(plr) end
		end
	end, { spawn = true })
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	打印玩家 DS 邮件信息（调试用）

	@param userID number | string - 玩家 UserId
	@return nil
]]
function SystemEmail.PrintPlrEmail(userID: number | string)
	local userIdStr = tostring(userID)
	local ok, data, err = SystemDataStore.Get(EMAIL_STORE, userIdStr)
	if not ok then
		Log.warn("SystemEmail.PrintPlrEmail: 读取失败", userIdStr, err)
		return
	end
	if not data then
		Log.print("SystemEmail: 邮件空", userIdStr)
		return
	end

	Log.print("SystemEmail: 玩家 DS 邮件", userIdStr)
	for _, v in pairs(data) do
		local mailText = v.UpdateText or v.Des or ""
		Log.print("邮件内容:", mailText, "IsSynced:", v.IsSynced, "SyncedAt:", v.SyncedAt)
		local rewardID = v.RewardID
		local rewardCount = v.RewardCount
		if rewardID and rewardCount then
			for k1, id in pairs(rewardID) do
				Log.print(string.format("<%sx%s>", tostring(id), tostring(rewardCount[k1])))
			end
		end
	end
end

--[[
	运营侧向玩家 DS 写入离线邮件；目标在线时立即入包

	@param emailData table - 见文件头 GivePlrEmail 入参
	@return boolean, string? - 失败 false 与错误码；写入成功 true；在线入包未完成且会补发时为 QueuedGrantFailed
]]
function SystemEmail.GivePlrEmail(emailData: any): (boolean, string?)
	if type(emailData) ~= "table" then
		return false, "INVALID_EMAIL_DATA"
	end

	local userID = _parseUserId(emailData.UserID)
	if not userID then
		return false, "MISSING_USER_ID"
	end

	local exData, exErr = _sanitizeExData(emailData.Ex_Data)
	if not exData then
		return false, exErr or "INVALID_EX_DATA"
	end
	local rewardIDs, rewardCounts, rewardErr = _sanitizeRewardLists(emailData.RewardID, emailData.RewardCount, exData.GrantSnapshot ~= nil or exData.IsGift == 1)
	if not rewardIDs or not rewardCounts then return false, rewardErr or "INVALID_REWARD_LIST" end

	local storedEmail: Struct.DsEmail = {
		RewardID = rewardIDs,
		RewardCount = rewardCounts,
		Ex_Data = exData,
		TagTitle = _truncateString(emailData.TagTitle, MAX_TAG_TITLE_LEN),
		ContentTitle = _truncateString(emailData.ContentTitle, MAX_CONTENT_TITLE_LEN),
		UpdateText = _truncateString(emailData.UpdateText, MAX_UPDATE_TEXT_LEN),
		Time = workspace:GetServerTimeNow(),
		IsRead = 0,
		IsClaim = 0,
		IsSynced = 0,
		SyncedAt = 0,
		MailId = if type(emailData.MailId) == "string" and #emailData.MailId > 0 and #emailData.MailId <= 200 then emailData.MailId else HttpService:GenerateGUID(false),
	}

	local userIdStr = tostring(userID)
	local rejectReason: string? = nil
	local updateOk, _, updateErr = SystemDataStore.Update(EMAIL_STORE, userIdStr, function(oldData)
		rejectReason = nil
		local data = if type(oldData) == "table" then oldData else {}
		for _, mail in ipairs(data) do
			if mail.MailId == storedEmail.MailId then
				return data
			end
		end
		if _countPendingMails(data) >= MAX_UNSYNCED_MAILS then
			rejectReason = "MAIL_QUEUE_FULL"
			return oldData
		end
		table.insert(data, storedEmail)
		return data
	end)
	if not updateOk then
		Log.warn("SystemEmail.GivePlrEmail: 写入失败", userIdStr, updateErr)
		return false, "DS_WRITE_FAILED"
	end
	if rejectReason then
		return false, rejectReason
	end

	local targetPlr = Players:GetPlayerByUserId(userID)
	if targetPlr then
		local grantOk, grantErr = SystemEmail.DeliverPending(targetPlr)
		if not grantOk then
			Log.warn("SystemEmail.GivePlrEmail: 在线发放未完成", userIdStr, grantErr)
			if grantErr == EnumMgr.GmEmailErr.SyncRevertFailed then
				return true, EnumMgr.GmEmailErr.SyncRevertFailed
			end
			return true, EnumMgr.GmEmailErr.QueuedGrantFailed
		end
	end

	return true, nil
end

--[[
	玩家入服时异步发放老存档邮件与 DS 待同步邮件（由 PlayerManager 调用）

	@param plr Player - 刚完成数据加载的玩家
	@return nil
]]
function SystemEmail.Init(plr: Player)
	if not _validatePlayer(plr) then
		return
	end

	task.spawn(SystemEmail.DeliverPending, plr)
end

return SystemEmail
