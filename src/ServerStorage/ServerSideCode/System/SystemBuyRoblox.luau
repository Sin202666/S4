--[[
	Module: SystemBuyRoblox
	Description: 付费发货：收据账本与奖励同档提交；赠送先持久路由后写幂等离线邮件。旧 true 收据仅保留兼容，历史漏单需对账。
	Author: 林奥宇
	Last Modified: 2026-10-16
	Created: 2026-10-12
]]

-- ============================================================================
-- 服务引用
-- ============================================================================

local Players = game:GetService("Players")

-- ============================================================================
-- 模块引用
-- ============================================================================

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local ArmWrestleConfig = Utils.ArmWrestleConfig
local CfgFind = Utils.CfgFind
local Copy = Utils.Copy
local HttpService = game:GetService("HttpService")
local EnumMgr = Utils.EnumMgr
local GameAnalytics = Utils.GameAnalytics
local Log = Utils.Log
local NetMsg = Utils.NetMsg
local NetWork = Utils.NetWork
local RankConfig = Utils.RankConfig
local RequestRateLimit = Utils.RequestRateLimit
local SystemBag = Utils.SystemBag
local SystemSave = Utils.SystemSave
local SystemDataStore = Utils.SystemDataStore
local SystemSDK = Utils.SystemSDK
local SystemShop = Utils.SystemShop
local SystemOnlineAward = Utils.SystemOnlineAward
local TipsModule = Utils.TipsModule

-- ItemShopData.Kind：走扳手腕发货快照（药水无 Kind，走 Items）
local AW_RECEIPT_KINDS: { [string]: boolean } = {
	Strength = true,
	StrengthTier = true,
	Cash = true,
}

-- ============================================================================
-- 模块定义
-- ============================================================================

local SystemBuyRoblox = {}

-- ============================================================================
-- 常量
-- ============================================================================

-- 购买成功时不弹出奖励 UI 的物品 id 集合；值为 1 表示跳过
local NOT_POP_UI_VT: { [number]: number } = {}

-- 需要显示奖励弹窗的 GamePass OnlyTag 集合；值为 1 表示展示
local SHOW_REWARD_GAMEPASS: { [string]: number } = {
	["GiftPack1"] = 1,
	["GiftPack2"] = 1,
}

local RECORD_ROBUX_SPEND_KEY = RankConfig.GetRecordField(RankConfig.RANK_ROBUX_NAME) :: string

local PURCHASE_HISTORY_STORE = SystemDataStore.STORE.PurchaseHistory

local PURCHASE_LOAD_OPTIONS = {
	maxTries = 1,
	retryIntervalSec = 0,
}

local PURCHASE_SAVE_OPTIONS = {
	maxTries = 3,
	retryIntervalSec = 1,
}

local RATE_LIMIT_MAX_REQUESTS = 3
local RATE_LIMIT_WINDOW_SEC = 5

local GIFT_PLAYER_INST_NAME = EnumMgr.PlayerInst.GiftPlayer
local BuyRobloxErr = EnumMgr.BuyRobloxErr

-- ============================================================================
-- 私有变量
-- ============================================================================

local _initialized = false

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	向客户端推送 GamePass 奖励弹窗

	@param player Player - 目标玩家
	@param cfg table - CfgFind 商品配置；须含 itemID、itemCount
]]
local function _showGamePassRewardPop(player: Player, cfg: any)
	local uiData = {
		AwardID = cfg.itemID,
		Count = cfg.itemCount,
	}
	NetWork.FireClient(player, NetMsg.SHOW_LOCAL_UI, "AwardPop", uiData, true)
end

--[[
	取玩家下服创建的赠送目标 ObjectValue

	@param player Player - 赠送发起者
	@return ObjectValue? - GiftPlayer 实例；缺失或类型不符为 nil
]]
local function _getGiftPlayerObject(player: Player): ObjectValue?
	local inst = player:FindFirstChild(GIFT_PLAYER_INST_NAME)
	if inst and inst:IsA("ObjectValue") then
		return inst :: ObjectValue
	end
	return nil
end

-- 收据键兼容旧 PurchaseHistory。
local function _buildPurchaseHistoryKey(receiptInfo)
	return tostring(receiptInfo.PlayerId) .. "_" .. tostring(receiptInfo.PurchaseId)
end

-- 统计失败不阻断已确认发货。
local function _notifyGameAnalytics(receiptInfo: any)
	task.defer(function()
		local analytics = GameAnalytics
		if not analytics then
			Log.warn("[SystemBuyRoblox] GameAnalytics 不可用，跳过收据上报")
			return
		end

		local gaOk, gaErr = pcall(function()
			analytics:ProcessReceiptCallback(receiptInfo)
		end)
		if not gaOk then
			Log.warn("[SystemBuyRoblox] GameAnalytics ProcessReceipt 失败:", gaErr)
		end
	end)
end

--[[
	选择赠送目标；带 productId 时必须先持久化购买意图

	@param player Player - 发起赠送的玩家
	@param targetUserId any - 目标玩家 UserId
	@return boolean - 写入成功为 true；校验失败为 false
]]
local function _onSetGift(player: Player, targetUserId: any, productId: any): boolean
	if not player or not player.Parent then
		Log.warn("[SystemBuyRoblox] SET_GIFT 无效玩家")
		return false
	end

	local uid = tonumber(targetUserId)
	if not uid or uid ~= uid or uid <= 0 or uid >= 2^53 or uid % 1 ~= 0 then
		Log.warn("[SystemBuyRoblox] SET_GIFT 无效目标:", targetUserId)
		return false
	end
	if uid == player.UserId then
		return false
	end

	local target = Players:GetPlayerByUserId(uid)
	if not target or not target.Parent then
		return false
	end

	local giftObj = _getGiftPlayerObject(player)
	if not giftObj then
		Log.warn("[SystemBuyRoblox] GiftPlayer 实例缺失:", player.UserId)
		return false
	end

	if productId ~= nil then
		if type(productId) ~= "number" or not CfgFind.FindCfgByPassID_Gift(productId) then return false end
		local key = tostring(productId)
		local ok = SystemSave.Transact(player, "gift-intent:" .. HttpService:GenerateGUID(false), function(data)
			local pending = data.GiftIntents[key]
			if pending then
				if pending.target ~= uid then return false, "GIFT_ALREADY_PENDING" end
				-- 重开提示后无法区分哪次提示对应延迟收据，保留目标直到运营核对。
				pending.reviewRequired = true
				return true
			end
			data.GiftIntents[key] = { target = uid, createdAt = os.time(), state = "AwaitingReceipt" }
			return true
		end)
		if not ok then return false end
	end
	giftObj.Value = target
	return true
end

--[[
	清除赠送目标

	@param player Player - 发起取消的玩家
	@return boolean - 玩家有效为 true
]]
local function _onCancelGift(player: Player): boolean
	if not player or not player.Parent then
		return false
	end

	local giftPlayer = _getGiftPlayerObject(player)
	if giftPlayer then
		giftPlayer.Value = nil
	end
	return true
end

-- ============================================================================
-- 公共函数
-- ============================================================================

--[[
	购买完成后的服务端发货处理（Marketplace 收据、赠送、邮件礼品共用）

	@param plr Player - 接收物品的目标玩家
	@param onlyTag string - CfgFind 商品唯一标签
	@return boolean, string? - 成功 true；失败 false 与 InvalidParam / ConfigNotFound / GrantFailed
]]
-- 在调用者事务中规划整个商品；通知提交后执行，药水留在背包由既有 UseItem 消费。
--[[ 冻结服务端奖励定义，收据与邮件重试不再重新解释商城配置。
	@param cfg table - 服务端商城配置
	@return table? - 可持久化的奖励快照；配置非法返回 nil
]]
function SystemBuyRoblox.CreateGrantSnapshot(cfg)
	if type(cfg) ~= "table" or type(cfg.OnlyTag) ~= "string" then return nil end
	local price = cfg.price or 0
	if type(price) ~= "number" or price ~= price or price < 0 or price >= 2^53 then return nil end

	-- 扳手腕 Strength / StrengthTier / Cash：Kind 来自 ItemShopData，发货键即 OnlyTag
	local awKind = cfg.Kind
	if type(awKind) == "string" and awKind ~= "" and AW_RECEIPT_KINDS[awKind] then
		local snap: { [string]: any } = {
			version = 1,
			kind = "ArmWrestle",
			Key = cfg.OnlyTag,
			GrantKind = awKind,
			price = price,
		}
		if awKind == "StrengthTier" then
			if type(cfg.Tier) ~= "number" or cfg.Tier < 1 or cfg.Tier % 1 ~= 0
				or type(cfg.Mult) ~= "number" or cfg.Mult <= 0 then
				return nil
			end
			snap.Tier = cfg.Tier
			snap.Mult = cfg.Mult
		elseif type(cfg.Amount) ~= "number" or cfg.Amount <= 0 then
			return nil
		else
			snap.Amount = cfg.Amount
		end
		return snap
	end

	local kind = if cfg.OnlyTag == "OnlineAwardClaimAll" then "OnlineAward" elseif cfg.cost == EnumMgr.RobuxType.GamePass then "GamePass" else "Items"
	local ids, counts = {}, {}
	if type(cfg.itemID) ~= "table" or type(cfg.itemCount) ~= "table" or #cfg.itemID ~= #cfg.itemCount then return nil end
	for _, array in ipairs({ cfg.itemID, cfg.itemCount }) do
		local size = 0
		for key in pairs(array) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > #array then return nil end
			size += 1
		end
		if size ~= #array or size > 1000 then return nil end
	end
	if kind == "GamePass" and (type(cfg.passID) ~= "number" or cfg.passID <= 0 or cfg.passID >= 2^53 or cfg.passID % 1 ~= 0) then return nil end
	for index, id in ipairs(cfg.itemID) do
		if id ~= 0 then
			local count = cfg.itemCount[index]
			if type(id) ~= "number" or id <= 0 or id >= 2^53 or id % 1 ~= 0
				or type(count) ~= "number" or count <= 0 or count >= 2^53 or count % 1 ~= 0 then return nil end
			table.insert(ids, id); table.insert(counts, count)
		end
	end
	if kind == "Items" and #ids == 0 then return nil end
	return { version = 1, kind = kind, OnlyTag = cfg.OnlyTag, passID = cfg.passID, itemID = ids, itemCount = counts, price = price }
end

--[[ 发放已经冻结的服务端奖励定义；调用者必须提供幂等事务。
	@param plr Player - 接收者
	@param snapshot table - CreateGrantSnapshot 产生的可信快照
	@return boolean, string? - 成功或错误码
]]
function SystemBuyRoblox.GrantSnapshot(plr, snapshot)
	if type(snapshot) ~= "table" or snapshot.version ~= 1 then return false, "INVALID_GRANT_SNAPSHOT" end
	if snapshot.kind == "OnlineAward" then return SystemOnlineAward.UnlockAllClaimable(plr) end
	if snapshot.kind == "GamePass" then return SystemShop.BuyGamePassSuc(plr, snapshot.passID, snapshot) end
	-- 延迟取用：SystemArmWrestle 依赖链经背包/存档模块，顶层缓存有循环加载风险
	if snapshot.kind == "ArmWrestle" then return Utils.SystemArmWrestle.GrantReceiptProduct(plr, snapshot.Key) end
	if snapshot.kind ~= "Items" then return false, "INVALID_GRANT_KIND" end
	local ok, err = SystemBag.AddItems(plr, snapshot.itemID, snapshot.itemCount)
	if not ok then return false, err end
	SystemSave.AfterCommit(plr, function() TipsModule.ShowAwardPop(plr, snapshot.itemID, snapshot.itemCount) end)
	return true
end

--[[ 按当前配置发放商品；仅供服务端调用，收据使用冻结快照。
	@param plr Player - 接收者
	@param onlyTag string - 商品标签
	@return boolean, string? - 成功或错误码
]]
function SystemBuyRoblox.BuyItemEnd(plr: Player, onlyTag: string): (boolean, string?)
	local snapshot = SystemBuyRoblox.CreateGrantSnapshot(CfgFind.FindCfgByOnlyTag(onlyTag))
	if not snapshot then return false, "INVALID_PRODUCT_CONFIG" end
	return SystemBuyRoblox.GrantSnapshot(plr, snapshot)
end

--[[
	处理 GamePass 购买完成回调

	@param player Player - 购买玩家
	@param passID number - GamePass 资产 ID
	@param purchaseSuccess boolean - Roblox 回调是否成功
]]
function SystemBuyRoblox.OnGamePassPurchased(player: Player, passID: number, purchaseSuccess: boolean)
	if not purchaseSuccess or not player or not passID then
		return
	end

	local cfg = CfgFind.FindCfgByPassID(passID)
	if not cfg then return end
	local ok, err = SystemSave.Transact(player, "gamepass-purchase:" .. tostring(passID), function(data)
		local granted, grantErr = SystemShop.BuyGamePassSuc(player, passID)
		if not granted then return false, grantErr end
		data.Record[RECORD_ROBUX_SPEND_KEY] = (data.Record[RECORD_ROBUX_SPEND_KEY] or 0) + cfg.price
		return true
	end)
	if not ok then
		Log.warn("[SystemBuyRoblox] OnGamePassPurchased 发货失败:", player.UserId, passID, err)
		return
	end

	if err == "ALREADY_APPLIED" then return end
	-- 扳手腕通行证落档后刷新 OwnedPasses 镜像（倍率展示）
	if ArmWrestleConfig.GetGamePass(cfg.OnlyTag) then
		Utils.SystemArmWrestle.RefreshPassMirror(player)
	end
	TipsModule.NormalTips(player, "成功购买")
	if SHOW_REWARD_GAMEPASS[cfg.OnlyTag] == 1 then _showGamePassRewardPop(player, cfg) end

	task.spawn(function()
		SystemSDK.PayGamePass(player, passID)
	end)
end

--[[
	处理 Developer Product 购买收据（幂等）

	@param receiptInfo table - Marketplace 收据；字段 PlayerId number、ProductId number、PurchaseId string
	@return Enum.ProductPurchaseDecision - PurchaseGranted 已确认持久发货；NotProcessedYet 待重试
]]
function SystemBuyRoblox.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local pending, granted = Enum.ProductPurchaseDecision.NotProcessedYet, Enum.ProductPurchaseDecision.PurchaseGranted
	if type(receiptInfo) ~= "table" or type(receiptInfo.PurchaseId) ~= "string" then return pending end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player or not SystemSave.GetStat(player) then return pending end
	local key = _buildPurchaseHistoryKey(receiptInfo)
	local readOk, history = SystemDataStore.Get(PURCHASE_HISTORY_STORE, key, PURCHASE_LOAD_OPTIONS)
	if not readOk then return pending end
	-- 老 true 无法区分历史占位与发货，保留兼容，必须由订单对账处理历史漏单。
	if history == true or (type(history) == "table" and history.state == "Delivered") then return granted end
	local cfg = CfgFind.FindCfgByPassID(receiptInfo.ProductId)
	local giftCfg = if not cfg then CfgFind.FindCfgByPassID_Gift(receiptInfo.ProductId) else nil
	local intent = SystemSave.GetStatByKey(player, { "GiftIntents", tostring(receiptInfo.ProductId) })
	local snapshot = if cfg or giftCfg then SystemBuyRoblox.CreateGrantSnapshot(cfg or giftCfg) else nil
	if not (type(history) == "table" and history.grant) and not snapshot then return pending end
	local routeOk, route = SystemDataStore.Update(PURCHASE_HISTORY_STORE, key, function(old)
		if old == true or (type(old) == "table" and old.state == "Delivered") then return old end
		local row = if type(old) == "table" then old else {}
		if not row.grant then
			if giftCfg and not row.target and not intent then return nil end
			row.target = row.target or (giftCfg and intent.target or nil)
			row.grant = Copy.deepCopy(snapshot)
			row.product, row.playerId, row.purchaseId = receiptInfo.ProductId, receiptInfo.PlayerId, receiptInfo.PurchaseId
			row.state, row.createdAt = "Pending", os.time()
		end
		return row
	end, PURCHASE_SAVE_OPTIONS)
	if not routeOk or type(route) ~= "table" or not route.grant then return pending end
	if route.product ~= receiptInfo.ProductId then return pending end
	if route.target then
		local queued = Utils.SystemEmail.GivePlrEmail({
			UserID = route.target, MailId = "receipt:" .. key, RewardID = {}, RewardCount = {},
			Ex_Data = { GrantSnapshot = route.grant },
			TagTitle = "Gift", ContentTitle = "Gift", UpdateText = "Gift from " .. player.DisplayName,
		})
		if not queued then return pending end
	end
	local saved, result = SystemSave.Transact(player, "receipt:" .. key, function(data)
		if not route.target then
			local ok, err = SystemBuyRoblox.GrantSnapshot(player, route.grant)
			if not ok then return false, err end
		else
			local current = data.GiftIntents[tostring(receiptInfo.ProductId)]
			if current and current.target == route.target then
				if current.reviewRequired then current.state = "ReviewRequired"
				else data.GiftIntents[tostring(receiptInfo.ProductId)] = nil end
			end
		end
		data.Record[RECORD_ROBUX_SPEND_KEY] = (data.Record[RECORD_ROBUX_SPEND_KEY] or 0) + route.grant.price
		return true
	end)
	if not saved then return pending end
	-- 这是提交后的索引，不再用占位表示发货成功；失败时玩家账本仍防重。
	SystemDataStore.Update(PURCHASE_HISTORY_STORE, key, function(old)
		if old == true then return old end
		local row = if type(old) == "table" then old else {}
		row.state = "Delivered"
		row.deliveredAt = os.time()
		return row
	end, PURCHASE_SAVE_OPTIONS)
	if result ~= "ALREADY_APPLIED" then
		_notifyGameAnalytics(receiptInfo)
		task.spawn(function() SystemSDK.PayProductItem(player, receiptInfo) end)
	end
	return granted
end

-- ============================================================================
-- 初始化
-- ============================================================================

--[[
	注册购买相关 Remote 与限频（由 PurchaseManager 在 Marketplace 绑定前调用）
]]
-- 取消提示不能证明没有延迟收据。保留目标，允许同目标重开；改目标须先完成订单核对。
function SystemBuyRoblox.OnProductPromptFinished(userId: number, productId: number, purchased: boolean)
	if purchased then return end
	local player = Players:GetPlayerByUserId(userId)
	if not player then return end
	local intent = SystemSave.GetStatByKey(player, { "GiftIntents", tostring(productId) })
	if not intent then return end
	SystemSave.Transact(player, "gift-cancel:" .. HttpService:GenerateGUID(false), function(data)
		local current = data.GiftIntents[tostring(productId)]
		if current and current.target == intent.target then
			current.state = "PromptCancelled"
		end
		return true
	end)
end

function SystemBuyRoblox.Init()
	if _initialized then
		return
	end
	_initialized = true

	if RequestRateLimit and RequestRateLimit.SetRateLimitConfig then
		RequestRateLimit.SetRateLimitConfig(NetMsg.SET_GIFT, {
			maxRequests = RATE_LIMIT_MAX_REQUESTS,
			timeWindow = RATE_LIMIT_WINDOW_SEC,
		})
		RequestRateLimit.SetRateLimitConfig(NetMsg.CANCEL_GIFT, {
			maxRequests = RATE_LIMIT_MAX_REQUESTS,
			timeWindow = RATE_LIMIT_WINDOW_SEC,
		})
	end

	NetWork.RegisterServerRemoteFunction(NetMsg.SET_GIFT, _onSetGift, { validate = function(uid, productId)
		return type(uid) == "number" and uid > 0 and uid < 2^53 and uid % 1 == 0
			and (productId == nil or (type(productId) == "number" and productId > 0 and productId < 2^53 and productId % 1 == 0))
	end })
	NetWork.RegisterServerRemoteFunction(NetMsg.CANCEL_GIFT, _onCancelGift)
end

return SystemBuyRoblox
