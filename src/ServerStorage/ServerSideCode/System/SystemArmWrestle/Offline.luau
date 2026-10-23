--[[
	Module: Offline
	Description: 扳手腕离线奖励：按离线时长折算力量，进服记待领秒数，玩家点领取时由服务端结算
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-19

	暂时关闭：Settle 只刷新 LastOnline，不累计待领；Claim 直接拒绝。重新打开时去掉这两个函数开头的提前返回，取消 TipsModule / MIN_SEC 的注释，并恢复 ArmWrestleHUD 里 OfflinePanel / MenuOfflineHint 的绑定。

	规则（参数见 ArmWrestleConfig.OFFLINE_*）：
	- 离线秒数 = 进服时 os.time() − 档案 LastOnline；不足 OFFLINE_MIN_SEC 不计，累计待领封顶 OFFLINE_MAX_SEC
	- 未领取的待领秒数跨会话保留并继续累加（仍封顶）；LastOnline 为 0（新玩家 / 本功能上线前的老档）不发
	- 力量 = Profile.GetBaseStrength × (待领秒数 ÷ 基础训练间隔) × OFFLINE_RATE；不含药水与好友/会员加成
	- 领取时才按当下倍率计算：通行证进服后异步查询，进服即算会漏 2 倍力量
	- 时间只用服务器 os.time()，客户端不上传任何数值；跨服时钟差导致的负时长按不足门槛处理

	LastOnline 刷新时机：
	- Settle 之后才允许 Touch：进服到 Settle 之间若被检查点抢先刷新，会把本次离线时长清零
	- 离服（SystemArmWrestle.OnPlayerRemoving）与每 60 秒检查点由 init 调 Touch 后存档；宕机最多多算一个检查点间隔

	客户端镜像（SyncAttributes，由 init 的 _afterChange 调用）：
	- OfflinePending：待领离线秒数；>0 时客户端弹领取窗
	- OfflineStrength：按当前倍率预估的可领力量（仅展示，结算以 Claim 为准）

	与相关模块：
	- 只改档案字段 LastOnline / OfflinePending / Strength，写回经 Bind 注入的 commit（Profile.Commit 原子提交）或调用方存档
	- 领取请求经 ARM_WRESTLE_ACTION 的 "ClaimOffline" 动作，由 init._dispatchAction 分发

	加载：
		local Offline = require(script.Offline)
		Offline.Bind({ getPasses = Economy.GetPasses, commit = _commitProfile })
		Offline.Settle(plr, data)          -- SetupPlayer，随后存档
		Offline.Touch(plr, data)           -- 离服 / 检查点，随后存档
		local ok, amount = Offline.Claim(plr)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ArmWrestleConfig = Utils.ArmWrestleConfig
-- 领取提示随离线奖励一并关闭，恢复 Claim 时取消注释
-- local TipsModule = Utils.TipsModule

local Profile = require(script.Parent.Profile)

local Offline = {}

local ERR_NONE = "none"
local ERR_NOT_READY = "notReady"
local ATTR_PENDING = "OfflinePending"
local ATTR_STRENGTH = "OfflineStrength"
local RATE = ArmWrestleConfig.OFFLINE_RATE
-- 累计门槛随离线奖励一并关闭，恢复 Settle 时取消注释
-- local MIN_SEC = ArmWrestleConfig.OFFLINE_MIN_SEC
local MAX_SEC = ArmWrestleConfig.OFFLINE_MAX_SEC

local _settled: { [Player]: boolean } = {}
local _getPasses: ((Player) -> { [string]: boolean })?
local _commit: ((Player, { [string]: any }) -> boolean)?

--[[
	读档案中的待领秒数并钳制到 [0, MAX_SEC]
	@param data table - ArmWrestle 档案（读 OfflinePending）
	@return number - 待领离线秒数（整数）
]]
local function _pending(data: { [string]: any }): number
	local value = tonumber(data.OfflinePending) or 0
	return math.clamp(math.floor(value), 0, MAX_SEC)
end

--[[
	基础训练间隔（不含训练速度药水）
	@param _data table - ArmWrestle 档案（不再读 TrainTier）
	@return number - 冷却秒数，恒 > 0
]]
local function _trainCooldown(_data: { [string]: any }): number
	local cooldown = ArmWrestleConfig.TRAIN_COOLDOWN
	return if cooldown > 0 then cooldown else 1
end

--[[
	注入会话依赖（SystemArmWrestle.Init 调一次）
	@param deps table - { getPasses: (Player) -> { [key] = true } 会话通行证, commit: (Player, table) -> boolean 原子写回并同步镜像 }
	@return nil
]]
function Offline.Bind(deps: {
	getPasses: (Player) -> { [string]: boolean },
	commit: (Player, { [string]: any }) -> boolean,
})
	_getPasses = deps.getPasses
	_commit = deps.commit
end

--[[
	进服结算离线时长：累加到待领秒数并把 LastOnline 刷新为当前时间（原地修改，调用方负责存档）
	@param plr Player - 玩家；标记本会话已结算，之后才允许 Touch
	@param data table - ArmWrestle 档案（读写 LastOnline / OfflinePending）
	@return number - 本次新增的离线秒数；不足门槛或首次进服为 0
]]
function Offline.Settle(plr: Player, data: { [string]: any }): number
	-- 离线奖励暂时关闭：只刷新 LastOnline，不累计待领，避免重新打开后把关闭期间一次性结算
	data.LastOnline = os.time()
	_settled[plr] = true
	return 0
	--[[
	local now = os.time()
	local last = tonumber(data.LastOnline) or 0
	local pending = _pending(data)
	local added = 0
	if last > 0 then
		local away = now - last
		if away >= MIN_SEC then
			local total = math.min(pending + away, MAX_SEC)
			added = total - pending
			pending = total
		end
	end
	data.OfflinePending = pending
	data.LastOnline = now
	_settled[plr] = true
	return added
	]]
end

--[[
	刷新 LastOnline 为当前时间（原地修改，调用方负责存档）；本会话尚未 Settle 时不改
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案（写 LastOnline）
	@return boolean - 已刷新为 true；未 Settle 为 false
]]
function Offline.Touch(plr: Player, data: { [string]: any }): boolean
	if not _settled[plr] then
		return false
	end
	data.LastOnline = os.time()
	return true
end

--[[
	本会话是否已完成离线结算（检查点据此决定是否需要为该玩家刷新 LastOnline）
	@param plr Player - 玩家
	@return boolean - 已 Settle 为 true
]]
function Offline.IsSettled(plr: Player): boolean
	return _settled[plr] == true
end

--[[
	按当前倍率计算待领离线力量
	@param plr Player - 玩家（读会话通行证）
	@param data table - ArmWrestle 档案（读 OfflinePending / StrengthTier）
	@return number - 可领力量（向下取整）；无待领或依赖未注入为 0
]]
function Offline.GetStrength(plr: Player, data: { [string]: any }): number
	local pending = _pending(data)
	local getPasses = _getPasses
	if pending <= 0 or not getPasses then
		return 0
	end
	local base = Profile.GetBaseStrength(data, getPasses(plr))
	return math.floor(base * (pending / _trainCooldown(data)) * RATE)
end

--[[
	同步离线奖励镜像 Attribute（OfflinePending 秒 / OfflineStrength 预估力量），仅供界面展示
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案
	@return nil
]]
function Offline.SyncAttributes(plr: Player, data: { [string]: any })
	plr:SetAttribute(ATTR_PENDING, _pending(data))
	plr:SetAttribute(ATTR_STRENGTH, Offline.GetStrength(plr, data))
end

--[[
	领取离线奖励：按当下倍率加力量、清空待领秒数，经 commit 原子写回；写档失败不清空，可重试
	@param plr Player - 玩家（来自 Remote，须本会话已 Settle）
	@return boolean - 成功为 true
	@return any - 成功时为本次获得的力量 number；失败时为失败码 string：none 无待领 / notReady 会话未就绪或写档失败
]]
function Offline.Claim(plr: Player): (boolean, any)
	-- 离线奖励暂时关闭
	return false, ERR_NONE
	--[[
	local commit, getPasses = _commit, _getPasses
	if not commit or not getPasses or not _settled[plr] then
		return false, ERR_NOT_READY
	end
	local data = Profile.Get(plr)
	if not data then
		return false, ERR_NOT_READY
	end
	if _pending(data) <= 0 then
		return false, ERR_NONE
	end
	local amount = Offline.GetStrength(plr, data)
	Profile.AddStrength(plr, data, amount, getPasses(plr))
	data.OfflinePending = 0
	if not commit(plr, data) then
		return false, ERR_NOT_READY
	end
	TipsModule.NormalTips(plr, "获得力量", { ArmWrestleConfig.Format(amount) })
	return true, amount
	]]
end

--[[
	离场释放会话标记（须在离服 Touch 并存档之后调用）
	@param plr Player - 玩家
	@return nil
]]
function Offline.Unload(plr: Player)
	_settled[plr] = nil
end

return Offline
