--[[
	Module: SystemArmWrestle
	Description: 扳手腕服务端领域：存档、训练、对局、经济；RegisterNetWork 与世界绑定
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	功能：
	- Init：绑世界、限频、心跳、库存；不迁版本、不直连 DataStore
	- SetupPlayer / OnCharacter / OnPlayerRemoving：由 PlayerManager 编排
	- 训练/点按/操作经 NetWork；结算权威在本模块子文件

	与相关模块：
	- Profile 只经 PlayerData.ChangePlrData
	- Battle 独占对局 PivotTo；SpeedTier 由客户端 CMS modifier 消费
	- Economy 不设置 ProcessReceipt；真实收据由 SystemBuyRoblox 按 ItemShopData 冻结快照后调 GrantReceiptProduct
	- 通行证购买由 SystemBuyRoblox → SystemShop 落档；成功后 RefreshPassMirror；进服补发由 SystemShop.Init
	- Potion：药水在线计时；本模块负责每秒到期检测、定时与离服把剩余秒数写回档案。药水库存是背包物品，
	  背包 / 快捷栏使用经 ItemScript.ArmWrestlePotion 调 ApplyPotionItem
	- Boost：同服好友 / Roblox 会员现金加成（仅会话）；加成变化时回调本模块重同步镜像
	- Offline：离线奖励；进服 Settle 记待领秒数，离服与定时检查点刷新 LastOnline，领取走 Action "ClaimOffline"
	- MenuGift：菜单挽留礼物（每账号一次现金）；领取走 Action "ClaimMenuGift"，镜像随 _afterChange 同步
	- 排行走 SystemRecord + SystemRank
	- 新手引导走 SystemGuide：_afterChange 传档案快照判定推进；对局胜利经 Battle 注入的 guideEvent 带 "win" 事件，材质机触发成功经 Economy 带 "machine" 事件
	  快照含 Can* 前置字段（金币够买下一档训练速度 / 最便宜未拥有手臂 / 本关材质机，力量够打本关 Boss / 开下一关门），价格只读 ArmWrestleConfig

	加载：
		local SystemArmWrestle = Utils.SystemArmWrestle
		SystemArmWrestle.Init()
		SystemArmWrestle.SetupPlayer(player)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Workspace = game:GetService("Workspace")
local Players = Utils.Players
local RunService = Utils.RunService
local ArmWrestleConfig = Utils.ArmWrestleConfig
local EnumMgr = Utils.EnumMgr
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local RequestRateLimit = Utils.RequestRateLimit
local SystemGuide = Utils.SystemGuide
local Log = Utils.Log

local Profile = require(script.Profile)
local Look = require(script.Look)
local Train = require(script.Train)
local Battle = require(script.Battle)
local Economy = require(script.Economy)
local WorldBoard = require(script.WorldBoard)
local Gate = require(script.Gate)
local Potion = require(script.Potion)
local Boost = require(script.Boost)
local Offline = require(script.Offline)
local MenuGift = require(script.MenuGift)

local SystemArmWrestle = {}

local PlayerAttr = EnumMgr.PlayerAttr
local ACTION_UNLOCK_LEVEL = "UnlockLevel"
local ACTION_USE_POTION = "UsePotion"
local ACTION_CLAIM_OFFLINE = "ClaimOffline"
local ACTION_CLAIM_MENU_GIFT = "ClaimMenuGift"
local POTION_TICK_SEC = 1
-- 药水剩余秒数与离线奖励 LastOnline 落档间隔；宕机时药水最多少扣、离线最多多算这么久，离服时另有精确写回
local POTION_CHECKPOINT_SEC = 60
local _inited = false
local _netRegistered = false
local _guidePrices: { [string]: any }? = nil

--[[
	集合表计数
	@param set any - { [key] = true }；非表计 0
	@return number - 键数量
]]
local function _countKeys(set: any): number
	if type(set) ~= "table" then
		return 0
	end
	local n = 0
	for _ in pairs(set) do
		n += 1
	end
	return n
end

--[[
	关卡材质机最低购买花费（池内材质 Price 最低值；抽取本身免费）
	@param level table? - 关卡配置
	@return number? - 最低购买价；无机器或无价格为 nil
]]
local function _machineMinPrice(level: { [string]: any }?): number?
	local machine = level and level.Machine
	if type(machine) ~= "table" then
		return nil
	end
	local best: number? = nil
	for _, id in ipairs(machine.Pool or {}) do
		local mat = ArmWrestleConfig.GetMaterial(id)
		local price = mat and tonumber(mat.Price)
		if price and price > 0 and (not best or price < best) then
			best = price
		end
	end
	return best
end

--[[
	新手引导前置判定用的静态价格表（配置只读，首次使用时构建一次，避免每次结算深拷贝配置）
	@return table - { arms: {{Id, Price}}（仅金币价，升序）, trainPrices: {[阶]: number}, machinePrices: {[关]: number}, bossPowers: {[关]: number}, gates: {[关]: number} }
]]
local function _getGuidePrices(): { [string]: any }
	if _guidePrices then
		return _guidePrices
	end
	local arms = {}
	for _, arm in ipairs(ArmWrestleConfig.GetArms()) do
		if not arm.Robux and type(arm.Price) == "number" and arm.Price > 0 then
			table.insert(arms, { Id = arm.Id, Price = arm.Price })
		end
	end
	table.sort(arms, function(a, b)
		return a.Price < b.Price
	end)
	local trainPrices = {}
	for tier, row in ipairs(ArmWrestleConfig.GetTrainSpeed()) do
		trainPrices[tier] = row.Price
	end
	local machinePrices, bossPowers, gates = {}, {}, {}
	for index, level in ipairs(ArmWrestleConfig.GetLevels()) do
		machinePrices[index] = _machineMinPrice(level)
		local opponents = level.Opponents
		local boss = type(opponents) == "table" and opponents[#opponents]
		bossPowers[index] = boss and boss.Power
		gates[index] = level.Gate
	end
	local prices = {
		arms = arms,
		trainPrices = trainPrices,
		machinePrices = machinePrices,
		bossPowers = bossPowers,
		gates = gates,
	}
	_guidePrices = prices
	return prices
end

--[[
	布尔转快照数值（引导条件只比较数值门槛）
	@param value boolean - 条件结果
	@return number - true 为 1，false 为 0
]]
local function _flag(value: boolean): number
	return if value then 1 else 0
end

--[[
	由档案与金币构造新手引导状态快照（字段与 GameConfig「引导」条件一致）
	@param plr Player - 玩家（读背包金币）
	@param data table - ArmWrestle 档案
	@return table - { Strength, Wins, TrainTier, Unlocked, ArmCount, MatCount, Coin, CanBuyTrainSpeed, CanBuyArm, CanBuyMat, CanBeatBoss, CanUnlockGate }；Can* 为 0/1
]]
local function _guideState(plr: Player, data: { [string]: any }): { [string]: number }
	local prices = _getGuidePrices()
	local strength = data.Strength or 0
	local trainTier = data.TrainTier or 1
	local unlocked = data.Unlocked or 1
	local coin = Profile.GetCoin(plr)
	local ownedArms = if type(data.Arms) == "table" then data.Arms else {}
	local armPrice: number? = nil
	for _, arm in ipairs(prices.arms) do
		if not ownedArms[tostring(arm.Id)] then
			armPrice = arm.Price
			break
		end
	end
	local trainPrice = prices.trainPrices[trainTier + 1]
	local matPrice = prices.machinePrices[unlocked]
	local bossPower = prices.bossPowers[unlocked]
	local gate = prices.gates[unlocked + 1]
	return {
		Strength = strength,
		Wins = data.Wins or 0,
		TrainTier = trainTier,
		Unlocked = unlocked,
		ArmCount = _countKeys(data.Arms),
		MatCount = _countKeys(data.Mats),
		Coin = coin,
		CanBuyTrainSpeed = _flag(trainPrice ~= nil and coin >= trainPrice),
		CanBuyArm = _flag(armPrice ~= nil and coin >= armPrice),
		CanBuyMat = _flag(matPrice ~= nil and coin >= matPrice),
		CanBeatBoss = _flag(bossPower ~= nil and strength >= bossPower),
		CanUnlockGate = _flag(gate ~= nil and strength >= gate),
	}
end

--[[
	带结算事件推进新手引导（Battle 胜利写档成功后调用）
	@param plr Player - 玩家
	@param data table - 写档后的档案
	@param event string - 事件名（"win"）
	@param arg any? - 事件参数（对手 Id）
]]
local function _guideEvent(plr: Player, data: { [string]: any }, event: string, arg: any?)
	SystemGuide.Evaluate(plr, _guideState(plr, data), event, arg)
end

--[[
	写回后同步外观/镜像/排行，并按最新档案推进新手引导
	@param plr Player - 玩家
	@param data table - 档案
	@param _unlocked boolean - 是否刚解锁关卡
]]
local function _afterChange(plr: Player, data: { [string]: any }, _unlocked: boolean)
	Profile.Sync(plr, data, Economy.GetPasses(plr))
	Offline.SyncAttributes(plr, data)
	MenuGift.SyncAttributes(plr, data)
	Look.Apply(plr, data)
	SystemGuide.Evaluate(plr, _guideState(plr, data))
end

--[[
	好友/会员加成变化后重同步倍率镜像（不写档）
	@param plr Player - 加成变化的玩家
	@return nil - 档案未就绪时跳过
]]
local function _syncBoost(plr: Player)
	local data = Profile.Get(plr)
	if data then
		Profile.Sync(plr, data, Economy.GetPasses(plr))
	end
end

--[[
	档案（可带金币增量）原子写回；成功同步镜像，失败用存档真值回滚镜像
	@param plr Player - 玩家
	@param data table - 已原地修改的完整档案
	@param coinDelta number? - 金币增减，同 Profile.Commit；缺省 0 仅写档
	@return boolean - 是否成功
]]
local function _commitProfile(plr: Player, data: { [string]: any }, coinDelta: number?): boolean
	if Profile.Commit(plr, data, coinDelta or 0) then
		_afterChange(plr, data, false)
		return true
	end
	local fresh = Profile.Get(plr)
	if fresh then
		_afterChange(plr, fresh, false)
	end
	return false
end

--[[
	分发客户端 Action：关卡解锁走 Gate，使用药水走 Potion，离线奖励走 Offline，挽留礼物走 MenuGift，其余走 Economy
	@param plr Player - 玩家
	@param action string - 动作名
	@param ... any - 参数
	@return any - 结果
]]
local function _dispatchAction(plr: Player, action: string, ...: any): any
	if action == ACTION_UNLOCK_LEVEL then
		return Gate.OnUnlock(plr, ...)
	end
	if action == ACTION_USE_POTION then
		return Potion.Use(plr, ...)
	end
	if action == ACTION_CLAIM_OFFLINE then
		return Offline.Claim(plr)
	end
	if action == ACTION_CLAIM_MENU_GIFT then
		return MenuGift.Claim(plr)
	end
	return Economy.OnAction(plr, action, ...)
end

--[[
	把会话药水剩余秒数与离线奖励 LastOnline 写回档案并存档
	@param plr Player - 玩家
	@return table? - 写回后的档案；会话未就绪为 nil
]]
local function _savePotionLeft(plr: Player): { [string]: any }?
	local data = Profile.Get(plr)
	if not data then
		return nil
	end
	Potion.FillLeft(plr, data)
	Offline.Touch(plr, data)
	Profile.Save(plr, data)
	return data
end

--[[
	药水心跳：每秒处理到期（重新同步倍率镜像并落档），每 POTION_CHECKPOINT_SEC 秒给药水生效中或已完成离线结算的玩家落档
]]
local function _runPotionClock()
	local sinceCheckpoint = 0
	while true do
		task.wait(POTION_TICK_SEC)
		for _, plr in ipairs(Potion.CollectExpired()) do
			local data = if plr.Parent then _savePotionLeft(plr) else nil
			if data then
				_afterChange(plr, data, false)
			end
		end
		sinceCheckpoint += POTION_TICK_SEC
		if sinceCheckpoint >= POTION_CHECKPOINT_SEC then
			sinceCheckpoint = 0
			for _, plr in ipairs(Players:GetPlayers()) do
				if Potion.HasActive(plr) or Offline.IsSettled(plr) then
					_savePotionLeft(plr)
				end
			end
		end
	end
end

--[[
	是否对局中（给技能/坐骑拒释）
	@param plr Player - 玩家
	@return boolean
]]
function SystemArmWrestle.IsInBattle(plr: Player): boolean
	return Battle.IsInBattle(plr) or plr:GetAttribute(PlayerAttr.InBattle) == true
end

--[[
	收据发货入口：仅供 SystemBuyRoblox.GrantSnapshot 在 SystemSave.Transact 内调用，幂等由调用方事务保证
	@param plr Player - 购买玩家（须在线且档案已加载）
	@param key string - 冻结在收据快照里的商品键；须 ArmWrestleConfig.IsReceiptProduct 为 true
	@return boolean - 发货成功（含重复力量倍数档的空操作）为 true
	@return string? - 失败码：INVALID_ARM_WRESTLE_PRODUCT 商品不支持收据发货 / ARM_WRESTLE_GRANT_FAILED 档案未就绪或写档失败
]]
function SystemArmWrestle.GrantReceiptProduct(plr: Player, key: string): (boolean, string?)
	if type(key) ~= "string" or not ArmWrestleConfig.IsReceiptProduct(key) then
		return false, "INVALID_ARM_WRESTLE_PRODUCT"
	end
	if not Economy.GrantProduct(plr, key) then
		return false, "ARM_WRESTLE_GRANT_FAILED"
	end
	return true
end

--[[
	背包使用药水入口：仅供 ItemScript.ArmWrestlePotion 在 BagUseItem 的 SystemSave.Transact 内调用（背包已扣除，这里只延长计时）
	@param plr Player - 使用玩家（须在线且档案已加载）
	@param key string - 药水键，来自 itemdataConf.parms[1]（StrengthPotion / TrainSpeedPotion / CashPotion）
	@param count number - 本次使用瓶数，正整数
	@return boolean - 计时已写入事务为 true
	@return string? - 失败码：invalid 键或瓶数非法 / notReady 会话未就绪或写档失败
]]
function SystemArmWrestle.ApplyPotionItem(plr: Player, key: string, count: number): (boolean, string?)
	return Potion.Apply(plr, key, count)
end

--[[
	Studio / 补发：按 OnlyTag 落档通行证（线上购买走 SystemBuyRoblox → SystemShop）
	@param plr Player - 购买玩家
	@param key string - ItemShopData.OnlyTag（AutoClicker 等）
	@return boolean - 已落档且 NumberValue 可见为 true
]]
function SystemArmWrestle.GrantGamePass(plr: Player, key: string): boolean
	if type(key) ~= "string" or not ArmWrestleConfig.GetGamePass(key) then
		return false
	end
	if not Profile.Get(plr) then
		return false
	end
	Economy.GrantPass(plr, key)
	return Economy.HasPass(plr, key)
end

--[[
	通行证落档后刷新 OwnedPasses 镜像；仅供 SystemBuyRoblox.OnGamePassPurchased
	@param plr Player - 玩家
]]
function SystemArmWrestle.RefreshPassMirror(plr: Player)
	Economy.RefreshPassMirror(plr)
end

--[[
	调试入口：解锁某类全部款式；仅供服务端 DebugManager 在 Dev 服校验后调用，不改装备、不扣限量库存
	@param plr Player - 目标玩家（须在线且档案已加载）
	@param kind string - "Arm" 全部手臂 / "Mat" 全部材质 / "Dumbbell" 全部哑铃
	@return boolean - 写档成功为 true
	@return string? - 失败码：INVALID_KIND / PROFILE_NOT_READY / COMMIT_FAILED
]]
function SystemArmWrestle.DebugUnlockAll(plr: Player, kind: string): (boolean, string?)
	return Economy.DebugUnlockAll(plr, kind)
end

--[[
	注册 Remote / 限频（可重复调用）
]]
function SystemArmWrestle.RegisterNetWork()
	if _netRegistered then
		return
	end
	_netRegistered = true
	-- 最快训练档 0.25s ÷ 训练速度药水 2 倍 = 每秒 8 次，留余量
	RequestRateLimit.SetRateLimitConfig(NetMsg.ARM_WRESTLE_TRAIN, { maxRequests = 12, timeWindow = 1 })
	RequestRateLimit.SetRateLimitConfig(NetMsg.ARM_WRESTLE_TAP, { maxRequests = 20, timeWindow = 1 })
	RequestRateLimit.SetRateLimitConfig(NetMsg.ARM_WRESTLE_ACTION, { maxRequests = 8, timeWindow = 2 })

	NetWork.RegisterServerRemoteEvent(NetMsg.ARM_WRESTLE_TRAIN, function(plr: Player)
		Train.OnTrain(plr)
	end)
	NetWork.RegisterServerRemoteEvent(NetMsg.ARM_WRESTLE_TAP, function(plr: Player)
		Battle.OnTap(plr)
	end)
	NetWork.RegisterServerRemoteFunction(NetMsg.ARM_WRESTLE_ACTION, function(plr: Player, action: any, ...: any)
		if type(action) ~= "string" then
			return false
		end
		local results = table.pack(pcall(_dispatchAction, plr, action, ...))
		if not results[1] then
			Log.warn("SystemArmWrestle.Action 失败", plr.UserId, action, results[2])
			return false
		end
		return table.unpack(results, 2, results.n)
	end)
end

--[[
	启动绑定（Manager 调一次）
]]
function SystemArmWrestle.Init()
	if _inited then
		return
	end
	_inited = true
	SystemArmWrestle.RegisterNetWork()

	Train.Bind({
		hasPass = Economy.HasPass,
		getPasses = Economy.GetPasses,
		isInBattle = Battle.IsInBattle,
		afterChange = _afterChange,
	})
	Battle.Bind({
		hasPass = Economy.HasPass,
		getPasses = Economy.GetPasses,
		afterChange = _afterChange,
		guideEvent = _guideEvent,
	})
	Economy.Bind({
		isInBattle = Battle.IsInBattle,
		afterChange = _afterChange,
		guideEvent = _guideEvent,
	})
	Gate.Bind({
		isInBattle = Battle.IsInBattle,
		commit = _commitProfile,
	})
	Potion.Bind({
		getProfile = Profile.Get,
		commit = _commitProfile,
		resync = _syncBoost,
	})
	Boost.Bind({
		onChanged = _syncBoost,
	})
	Offline.Bind({
		getPasses = Economy.GetPasses,
		commit = _commitProfile,
	})
	MenuGift.Bind({
		commit = _commitProfile,
	})
	task.spawn(_runPotionClock)

	local world = Workspace:FindFirstChild(ArmWrestleConfig.WORLD_NAME)
	if world then
		Battle.BindWorld(world)
		Economy.BindWorld(world)
		Gate.BindWorld(world)
		Battle.StartHeartbeat()
		task.spawn(function()
			Economy.RefreshStock()
			task.wait(5)
			while true do
				WorldBoard.Refresh(world)
				Economy.RefreshStock()
				task.wait(if RunService:IsStudio() then 15 else 60)
			end
		end)
	else
		Log.warn("SystemArmWrestle.Init：未找到 Workspace.World")
	end
end

--[[
	入服建会话并补档案
	@param plr Player - 玩家
]]
function SystemArmWrestle.SetupPlayer(plr: Player)
	Economy.SetupPlayer(plr)
	Boost.SetupPlayer(plr)
	local data = Profile.Get(plr)
	if not data then
		return
	end
	Potion.Load(plr, data)
	Offline.Settle(plr, data)
	Profile.Save(plr, data)
	SystemGuide.SetupPlayer(plr, _guideState(plr, data))
	_afterChange(plr, data, false)
end

--[[
	角色生成：外观 + 哑铃
	@param plr Player - 玩家
	@param _char Model - 角色
]]
function SystemArmWrestle.OnCharacter(plr: Player, _char: Model)
	local data = Profile.Get(plr)
	if data then
		Look.Apply(plr, data)
	end
	Look.EnsureDumbbell(plr, if data then data.Dumbbell else 1)
	local hum = _char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			Battle.ForceEnd(plr)
		end)
	end
end

--[[
	离场清理
	@param plr Player - 玩家
]]
function SystemArmWrestle.OnPlayerRemoving(plr: Player)
	Battle.ForceEnd(plr)
	-- PlayerManager 在本函数之后才 PlayerLeaveSave，药水剩余秒数与 LastOnline 须先写回档案
	_savePotionLeft(plr)
	Potion.Unload(plr)
	Offline.Unload(plr)
	MenuGift.Unload(plr)
	Train.OnPlayerRemoving(plr)
	Economy.OnPlayerRemoving(plr)
	Boost.OnPlayerRemoving(plr)
end

return SystemArmWrestle
