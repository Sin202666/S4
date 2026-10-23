--[[
	Module: SystemCode
	Description: 兑换码：type 1 单玩家一次、配置时间窗；type 3 CDK 永久预留给兑换人并同档幂等发奖；未定义类型明确拒绝。
	Author: 林奥宇
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local Log = Utils.Log
local CfgFind = Utils.CfgFind
local EnumMgr = Utils.EnumMgr
local NetMsg = Utils.NetMsg
local NetWork = Utils.NetWork
local SystemBag = Utils.SystemBag
local SystemCDK = Utils.SystemCDK
local SystemSave = Utils.SystemSave
local RequestRateLimit = Utils.RequestRateLimit

local SystemCode = {}

local CodeErr = EnumMgr.CodeErr
local CDK_TYPE = 3
local REDEEM_CODE_MAX_LEN = 50
local RATE_LIMIT_MAX_REQUESTS = 3
local RATE_LIMIT_WINDOW_SEC = 5

local _registered = false

-- ============================================================================
-- 私有函数
-- ============================================================================

--[[
	校验玩家对象是否在线且有效
	@param plr Player - 待校验玩家
	@return boolean - 有效为 true
]]
local function _validatePlayer(plr: Player): boolean
	return plr ~= nil and plr:IsA("Player") and plr.Parent ~= nil
end

--[[
	规范化兑换码：去首尾空白并大写
	@param codeStr string - 原始输入
	@return string - 规范化后的码
]]
local function _normalizeCode(codeStr: string): string
	local trimmed = string.gsub(codeStr, "^%s+", "")
	trimmed = string.gsub(trimmed, "%s+$", "")
	return string.upper(trimmed)
end

--[[
	是否为 codeConf 中非 type 3 的普通兑换码（精确匹配规范化后的 code）
	@param codeStr string - 已规范化的码
	@return boolean - 命中普通码配置为 true
]]
local function _isNonCdkConfiguredCode(codeStr: string): any
	local codes = CfgFind.GetCfgByName("codeConf")
	if not codes then
		return false
	end
	for _, config in pairs(codes) do
		if tonumber(config.codeType) ~= CDK_TYPE and type(config.code) == "string" then
			if _normalizeCode(config.code) == codeStr then
				return config
			end
		end
	end
	return false
end

--[[
	奖励列表是否至少有一条可入包的配置物品
	@param rewardId {number}? - 物品 ID 列表
	@param rewardNum {number}? - 对应数量
	@return boolean - 存在可发条目为 true
]]
local function _hasGrantableReward(rewardId: { number }?, rewardNum: { number }?): boolean
	if type(rewardId) ~= "table" or type(rewardNum) ~= "table" then
		return false
	end
	for i, itemId in ipairs(rewardId) do
		local count = tonumber(rewardNum[i])
		if CfgFind.FindCfgByID(itemId) and count and count > 0 then
			return true
		end
	end
	return false
end

--[[
	将 CDK 奖励写入背包
	@param plr Player - 玩家
	@param rewardId {number}? - 物品 ID 列表
	@param rewardNum {number}? - 对应数量
	@return boolean - 至少入包一件为 true
]]
local function _grantCdkRewards(plr: Player, rewardId: { number }?, rewardNum: { number }?): boolean
	if not _hasGrantableReward(rewardId, rewardNum) then
		return false
	end
	local ok = SystemBag.AddItems(plr, rewardId :: { number }, rewardNum :: { number })
	return ok == true
end

-- ============================================================================
-- 公共 API
-- ============================================================================

--[[
	兑换兑换码（服务端权威：校验 → CDK CAS → 入包；失败回滚）
	@param plr Player - 发起兑换的玩家
	@param codeStr string - 用户输入的兑换码
	@return boolean - 兑换并入包成功为 true
	@return string? - 失败时为 EnumMgr.CodeErr；成功为 nil
]]
function SystemCode.RedeemCode(plr: Player, codeStr: string): (boolean, string?)
	if not _validatePlayer(plr) then
		return false, CodeErr.InvalidPlayer
	end
	if type(codeStr) ~= "string" or codeStr == "" then
		return false, CodeErr.InvalidCode
	end

	local normalized = _normalizeCode(codeStr)
	if normalized == "" or string.len(normalized) >= REDEEM_CODE_MAX_LEN then
		return false, CodeErr.InvalidCode
	end

	local ordinary = _isNonCdkConfiguredCode(normalized)
	if ordinary then
		if tonumber(ordinary.codeType) ~= 1 then return false, CodeErr.OrdinaryNotImplemented end
		local now = os.time()
		if ((ordinary.startTime or 0) > 0 and now < ordinary.startTime) or ((ordinary.endTime or 0) > 0 and now > ordinary.endTime) then
			return false, CodeErr.RedeemFailed
		end
		return SystemSave.Transact(plr, "code:" .. normalized, function(data)
			if data.Code[normalized] then return true end
			local ok, err = SystemBag.AddItems(plr, ordinary.rewardId, ordinary.rewardNum)
			if not ok then return false, err end
			data.Code[normalized] = true
			return true
		end)
	end

	local ok, rewardId, rewardNum, poolId = SystemCDK.Redeem(plr, normalized)
	if not ok or type(poolId) ~= "string" then
		return false, CodeErr.RedeemFailed
	end

	local granted, err = SystemSave.Transact(plr, "cdk:" .. poolId .. ":" .. normalized, function()
		return _grantCdkRewards(plr, rewardId, rewardNum)
	end)
	if not granted then Log.warn("CDK pending; retry same code", plr.UserId, poolId, err) end
	return granted, if granted then nil else CodeErr.GrantFailed
end

--[[
	注册兑换码 RemoteFunction，并配置限频（幂等；须在模块加载时调用，避免客户端 Invoke 早于 Init）
]]
function SystemCode.RegisterNetWork()
	if _registered then
		return
	end
	_registered = true

	if RequestRateLimit and RequestRateLimit.SetRateLimitConfig then
		RequestRateLimit.SetRateLimitConfig(NetMsg.REDEEM_CODE, {
			maxRequests = RATE_LIMIT_MAX_REQUESTS,
			timeWindow = RATE_LIMIT_WINDOW_SEC,
		})
	end

	NetWork.RegisterServerRemoteFunction(NetMsg.REDEEM_CODE, function(player: Player, rawCode: string)
		if not _validatePlayer(player) then
			Log.warn("SystemCode: Remote 无效玩家")
			return false, CodeErr.InvalidPlayer
		end
		return SystemCode.RedeemCode(player, rawCode)
	end)
end

SystemCode.RegisterNetWork()

return SystemCode
