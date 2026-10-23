--[[
	Module: SystemArmWrestle
	Description: 扳手腕服务端领域：经济、药水、离线奖励与菜单礼物；RegisterNetWork
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-19

	功能：
	- Init：绑限频与药水心跳；不迁版本、不直连 DataStore
	- SetupPlayer / OnCharacter / OnPlayerRemoving：由 PlayerManager 编排
	- 哑铃训练已下线，不再注册训练 Remote

	与相关模块：
	- Profile 只经 PlayerData.ChangePlrData
	- Economy 不设置 ProcessReceipt；真实收据由 SystemBuyRoblox 按 ItemShopData 冻结快照后调 GrantReceiptProduct
	- 通行证购买由 SystemBuyRoblox → SystemShop 落档；成功后 RefreshPassMirror；进服补发由 SystemShop.Init
	- Potion：药水在线计时；本模块负责每秒到期检测、定时与离服把剩余秒数写回档案。药水库存是背包物品，
	  背包 / 快捷栏使用经 ItemScript.ArmWrestlePotion 调 ApplyPotionItem
	- Boost：同服好友 / Roblox 会员现金加成（仅会话）；加成变化时回调本模块重同步镜像
	- Offline：离线奖励暂时关闭；Settle 只刷新 LastOnline，不累计待领，Claim 直接拒绝
	- MenuGift：菜单挽留礼物（每账号一次固定现金）；领取走 Action "ClaimMenuGift"，镜像随 _afterChange 同步
	- 排行走 SystemRecord + SystemRank
	- 哑铃训练、手臂、比赛、升级垫、地图解锁、材质、地图传送已下线；对应存档字段留在 SaveMetaData，本模块不再读写

	加载：
		local SystemArmWrestle = Utils.SystemArmWrestle
		SystemArmWrestle.Init()
		SystemArmWrestle.SetupPlayer(player)
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Players = Utils.Players
local ArmWrestleConfig = Utils.ArmWrestleConfig
local EnumMgr = Utils.EnumMgr
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local RequestRateLimit = Utils.RequestRateLimit
local Log = Utils.Log

local Profile = require(script.Profile)
local Economy = require(script.Economy)
local Potion = require(script.Potion)
local Boost = require(script.Boost)
local Offline = require(script.Offline)
local MenuGift = require(script.MenuGift)

local SystemArmWrestle = {}

local PlayerAttr = EnumMgr.PlayerAttr
local ACTION_USE_POTION = "UsePotion"
local ACTION_CLAIM_OFFLINE = "ClaimOffline"
local ACTION_CLAIM_MENU_GIFT = "ClaimMenuGift"
local POTION_TICK_SEC = 1
-- 药水剩余秒数与离线奖励 LastOnline 落档间隔；宕机时药水最多少扣、离线最多多算这么久，离服时另有精确写回
local POTION_CHECKPOINT_SEC = 60
local _inited = false
local _netRegistered = false

--[[
	写回后同步镜像与排行
	@param plr Player - 玩家
	@param data table - 档案
	@param _unlocked boolean - 旧关卡解锁标记，已无解锁流程，调用方仍传 false
]]
local function _afterChange(plr: Player, data: { [string]: any }, _unlocked: boolean)
	Profile.Sync(plr, data, Economy.GetPasses(plr))
	Offline.SyncAttributes(plr, data)
	MenuGift.SyncAttributes(plr, data)
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
	分发客户端 Action：使用药水走 Potion，离线奖励走 Offline，挽留礼物走 MenuGift，其余走 Economy
	@param plr Player - 玩家
	@param action string - 动作名
	@param ... any - 参数
	@return any - 结果
]]
local function _dispatchAction(plr: Player, action: string, ...: any): any
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
	是否对局中。比赛已下线，恒为 false，供技能/坐骑的旧调用点继续编译
	@param _plr Player - 玩家
	@return boolean - 恒 false
]]
function SystemArmWrestle.IsInBattle(_plr: Player): boolean
	return false
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
	注册 Remote / 限频（可重复调用）
]]
function SystemArmWrestle.RegisterNetWork()
	if _netRegistered then
		return
	end
	_netRegistered = true
	RequestRateLimit.SetRateLimitConfig(NetMsg.ARM_WRESTLE_ACTION, { maxRequests = 8, timeWindow = 2 })

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

	Economy.Bind({
		afterChange = _afterChange,
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
end

--[[
	入服建会话并补档案
	@param plr Player - 玩家
]]
function SystemArmWrestle.SetupPlayer(plr: Player)
	Economy.SetupPlayer(plr)
	Boost.SetupPlayer(plr)
	plr:SetAttribute(PlayerAttr.InBattle, false)
	local data = Profile.Get(plr)
	if not data then
		return
	end
	Potion.Load(plr, data)
	Offline.Settle(plr, data)
	Profile.Save(plr, data)
	_afterChange(plr, data, false)
end

--[[
	角色生成。外观与哑铃已下线，这里不再改角色
	@param _plr Player - 玩家
	@param _char Model - 角色
]]
function SystemArmWrestle.OnCharacter(_plr: Player, _char: Model)
end

--[[
	离场清理
	@param plr Player - 玩家
]]
function SystemArmWrestle.OnPlayerRemoving(plr: Player)
	-- PlayerManager 在本函数之后才 PlayerLeaveSave，药水剩余秒数与 LastOnline 须先写回档案
	_savePotionLeft(plr)
	Potion.Unload(plr)
	Offline.Unload(plr)
	MenuGift.Unload(plr)
	Economy.OnPlayerRemoving(plr)
	Boost.OnPlayerRemoving(plr)
end

return SystemArmWrestle
