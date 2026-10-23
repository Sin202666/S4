--[[
	Module: Potion
	Description: 扳手腕药水：会话内在线计时、倍率查询、使用结算、到期检测与客户端镜像
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	计时规则：
	- 只在在线时流逝。进服 Load 把存档 PotionLeft（剩余秒数）换成 os.clock() 截止点；
	  离服与定时检查点由 SystemArmWrestle.init 调 FillLeft 写回档案再存档
	- 续用叠加：新截止 = 当前剩余 + 单瓶 Duration × 瓶数

	库存与使用：
	- 库存是背包物品（ArmWrestleConfig.GetPotion(key).ItemId），唯一写口 SystemBag；本模块不存瓶数
	- Apply 是延长计时的唯一入口，须在 SystemSave 事务内调用：事务内写 PotionLeft，内存截止点在 AfterCommit 才更新，
	  事务回滚时计时不会被误加
	- 两个使用入口都走 Apply：商城按钮 Use（本模块在同一事务内扣背包 1 瓶）；背包 / 快捷栏使用走
	  ItemScript.ArmWrestlePotion（BagUseItem 已扣背包，脚本只调 SystemArmWrestle.ApplyPotionItem）

	与相关模块：
	- 倍率唯一出口 GetMult：Profile.GetMults 消费 Strength / Cash，Train 消费 TrainSpeed（冷却 ÷ 倍率）
	- 不写 WalkSpeed / 位置；档案写回经 Bind 注入的 getProfile / commit / resync（避免与 Profile 互相 require）
	- 购买只往背包加物品，由 Economy.GrantProduct（Kind = "Potion"）处理

	客户端镜像（SyncAttributes，由 Profile.Sync 调用）：
	- PotionEnd_<键>：生效截止的服务器时间（workspace:GetServerTimeNow 口径，取整），未生效为 0
	- TrainSpeedMult：训练频率倍率（客户端据此调快训练请求，结算仍以服务端冷却为准）
	- 持有瓶数不在这里同步：客户端读背包镜像 Player.Bag[tostring(ItemId)]

	加载：
		local Potion = require(script.Potion)
		Potion.Bind({ getProfile = Profile.Get, commit = _commitProfile, resync = _syncBoost })
		Potion.Load(plr, data)
		local ok, err = Potion.Use(plr, "StrengthPotion")
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Workspace = game:GetService("Workspace")
local ArmWrestleConfig = Utils.ArmWrestleConfig
local SystemBag = Utils.SystemBag
local SystemSave = Utils.SystemSave

local Potion = {}

local ERR_INVALID = "invalid"
local ERR_EMPTY = "empty"
local ERR_NOT_READY = "notReady"
local ATTR_END_PREFIX = "PotionEnd_"
local ATTR_TRAIN_SPEED = "TrainSpeedMult"
local EFFECT_TRAIN_SPEED = "TrainSpeed"

local POTION_ORDER = ArmWrestleConfig.PotionOrder

-- 键 → { Effect, Mult, Duration, ItemId }；GetMult 每次训练都会调用，避免反复深拷贝配置
local _effects: { [string]: { Effect: string, Mult: number, Duration: number, ItemId: number } } = {}
for _, key in ipairs(POTION_ORDER) do
	local row = ArmWrestleConfig.GetPotion(key)
	if row then
		_effects[key] = { Effect = row.Effect, Mult = row.Mult, Duration = row.Duration, ItemId = row.ItemId }
	end
end

local _until: { [Player]: { [string]: number } } = {}
local _getProfile: ((Player) -> { [string]: any }?)?
local _commit: ((Player, { [string]: any }) -> boolean)?
local _resync: ((Player) -> ())?

--[[
	药水剩余在线秒数
	@param plr Player - 玩家
	@param key string - 药水键
	@return number - 剩余秒数；未生效或会话未加载为 0
]]
local function _left(plr: Player, key: string): number
	local map = _until[plr]
	local deadline = map and map[key]
	if not deadline then
		return 0
	end
	return math.max(deadline - os.clock(), 0)
end

--[[
	注入档案读写依赖（SystemArmWrestle.Init 调一次）
	@param deps table - { getProfile: (Player) -> table?, commit: (Player, table) -> boolean, resync: (Player) -> () }；commit 须原子写回并同步镜像，resync 按最新档案重同步镜像（不写档）
]]
function Potion.Bind(deps: {
	getProfile: (Player) -> { [string]: any }?,
	commit: (Player, { [string]: any }) -> boolean,
	resync: (Player) -> (),
})
	_getProfile = deps.getProfile
	_commit = deps.commit
	_resync = deps.resync
end

--[[
	进服建立计时会话：把存档剩余秒数换成本服 os.clock() 截止点
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案（读 PotionLeft { [键] = 秒 }）
]]
function Potion.Load(plr: Player, data: { [string]: any })
	local map = {}
	local saved = data.PotionLeft
	if type(saved) == "table" then
		local now = os.clock()
		for key, left in pairs(saved) do
			if _effects[key] and type(left) == "number" and left > 0 then
				map[key] = now + left
			end
		end
	end
	_until[plr] = map
end

--[[
	离服释放计时会话（须在 FillLeft 写回档案之后调用）
	@param plr Player - 玩家
]]
function Potion.Unload(plr: Player)
	_until[plr] = nil
end

--[[
	把当前剩余秒数写进档案 PotionLeft（原地修改，不存档；调用方负责保存）
	计时会话未建立（未 Load）时不改档案，避免把存档里的剩余时长清空
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案
]]
function Potion.FillLeft(plr: Player, data: { [string]: any })
	if not _until[plr] then
		return
	end
	local left = {}
	for _, key in ipairs(POTION_ORDER) do
		local seconds = math.floor(_left(plr, key))
		if seconds > 0 then
			left[key] = seconds
		end
	end
	data.PotionLeft = left
end

--[[
	当前生效倍率（同维度多瓶时取最大，当前每维度只有一种药水）
	@param plr Player - 玩家
	@param effect string - Strength（每次训练力量）/ TrainSpeed（训练频率）/ Cash（对局金币）
	@return number - 倍率；未生效为 1
]]
function Potion.GetMult(plr: Player, effect: string): number
	local map = _until[plr]
	if not map then
		return 1
	end
	local now = os.clock()
	local mult = 1
	for key, deadline in pairs(map) do
		local row = _effects[key]
		if row and row.Effect == effect and deadline > now then
			mult = math.max(mult, row.Mult)
		end
	end
	return mult
end

--[[
	是否有任一药水生效中（定时检查点据此决定是否需要写档）
	@param plr Player - 玩家
	@return boolean - 有生效药水为 true
]]
function Potion.HasActive(plr: Player): boolean
	local map = _until[plr]
	if not map then
		return false
	end
	local now = os.clock()
	for _, deadline in pairs(map) do
		if deadline > now then
			return true
		end
	end
	return false
end

--[[
	清掉已到期的截止点并返回受影响玩家（init 每秒调用，随后重新同步倍率镜像）
	@return {Player} - 本次有药水到期的玩家列表
]]
function Potion.CollectExpired(): { Player }
	local now = os.clock()
	local list = {}
	for plr, map in pairs(_until) do
		local expired = false
		for key, deadline in pairs(map) do
			if deadline <= now then
				map[key] = nil
				expired = true
			end
		end
		if expired then
			table.insert(list, plr)
		end
	end
	return list
end

--[[
	同步药水镜像 Attribute（截止时间取整，避免每次训练 Sync 时数值抖动触发复制）
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案（当前未读，保留与 Profile.Sync 的调用约定）
]]
function Potion.SyncAttributes(plr: Player, _data: { [string]: any })
	local serverNow = Workspace:GetServerTimeNow()
	for _, key in ipairs(POTION_ORDER) do
		local left = _left(plr, key)
		plr:SetAttribute(ATTR_END_PREFIX .. key, if left > 0 then math.floor(serverNow + left + 0.5) else 0)
	end
	plr:SetAttribute(ATTR_TRAIN_SPEED, Potion.GetMult(plr, EFFECT_TRAIN_SPEED))
end

--[[
	延长药水计时（不扣库存）。须在 SystemSave 事务 / Mutate 回调内调用，失败令外层事务整体回滚
	@param plr Player - 玩家
	@param key string - 药水键（ArmWrestleConfig.PotionOrder 中的键；调用方已从配置或 itemdataConf.parms 取得）
	@param count number - 本次生效瓶数，正整数；时长 = 单瓶 Duration × count
	@return boolean - 成功为 true
	@return string? - 失败码：invalid 键或瓶数非法 / notReady 会话未就绪或写档失败
]]
function Potion.Apply(plr: Player, key: string, count: number): (boolean, string?)
	local getProfile, commit, resync = _getProfile, _commit, _resync
	if not getProfile or not commit or not resync then
		return false, ERR_NOT_READY
	end
	local row = _effects[key]
	if not row or type(count) ~= "number" or count < 1 or count % 1 ~= 0 then
		return false, ERR_INVALID
	end
	local data = getProfile(plr)
	if not _until[plr] or not data then
		return false, ERR_NOT_READY
	end
	local newLeft = _left(plr, key) + row.Duration * count
	Potion.FillLeft(plr, data)
	data.PotionLeft[key] = math.floor(newLeft)
	if not commit(plr, data) then
		return false, ERR_NOT_READY
	end
	SystemSave.AfterCommit(plr, function()
		local map = _until[plr]
		if map then
			map[key] = os.clock() + newLeft
		end
		resync(plr)
	end)
	return true
end

--[[
	商城按钮使用一瓶药水：同一事务内从背包扣 1 瓶并延长计时
	@param plr Player - 玩家
	@param key any - 客户端传入的药水键（不可信，须为 ArmWrestleConfig.PotionOrder 中的键）
	@return boolean - 成功为 true
	@return string? - 失败码：invalid 键非法 / empty 背包里没有该药水 / notReady 会话未就绪或写档失败
]]
function Potion.Use(plr: Player, key: any): (boolean, string?)
	local row = if type(key) == "string" then _effects[key] else nil
	if not row then
		return false, ERR_INVALID
	end
	if SystemBag.GetItemCountByID(plr, row.ItemId) < 1 then
		return false, ERR_EMPTY
	end
	local ok = SystemSave.Mutate(plr, function()
		local removed, removeErr = SystemBag.RemoveItem(plr, { row.ItemId }, { 1 })
		if not removed then
			return false, removeErr
		end
		return Potion.Apply(plr, key, 1)
	end)
	if not ok then
		return false, ERR_NOT_READY
	end
	return true
end

return Potion
