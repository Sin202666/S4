--[[
	Module: Economy
	Description: 扳手腕升级垫、材质机、买臂/买哑铃/装备、关卡传送校验、限量库存、Studio 发货
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-15

	不设置 ProcessReceipt。线上商品 Id=0 时仅 Studio DevGrant；
	填入真实 Id 后由 SystemBuyRoblox.ProcessReceipt 在 SystemSave.Transact 内调 GrantProduct（经 SystemArmWrestle.GrantReceiptProduct），
	因此 GrantProduct 内的提示、镜像同步、库存写入一律经 SystemSave.AfterCommit，事务失败时不执行。
	限量库存走 SystemDataStore.STORE.Global。
	价格/奖励货币为背包金币；涉及金币的写档一律经 _commit（Profile.Commit 原子提交）。
	药水商品（Kind = "Potion"）只往背包加药水物品（ArmWrestleConfig.GetPotion().ItemId），使用与计时在 Potion 子模块。
	通行证拥有权以 Roblox 为准：进服 _loadOwnedPasses 查询，购买回调经 SystemArmWrestle.GrantGamePass，均只写会话。
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Players = Utils.Players
local RunService = Utils.RunService
local MarketplaceService = Utils.MarketplaceService
local ArmWrestleConfig = Utils.ArmWrestleConfig
local TipsModule = Utils.TipsModule
local NetWork = Utils.NetWork
local NetMsg = Utils.NetMsg
local SystemDataStore = Utils.SystemDataStore
local SystemSave = Utils.SystemSave
local SystemBag = Utils.SystemBag
local Log = Utils.Log

local Profile = require(script.Parent.Profile)
local Look = require(script.Parent.Look)
local Battle = require(script.Parent.Battle)

local Economy = {}

local IS_STUDIO = RunService:IsStudio()
local STORE_GLOBAL = SystemDataStore.STORE.Global
local STOCK_KEY = SystemDataStore.Keys.ARM_WRESTLE_JUDGEMENT_SOLD
local LIMITED_ID = ArmWrestleConfig.LIMITED_ARM_ID
-- 关卡传送最小间隔，防连点刷传送
local TELEPORT_COOLDOWN_SEC = 1
-- 材质机触发成功的新手引导事件名（GameConfig「引导」Done 条件 { "Event", "machine" }）
local GUIDE_EVENT_MACHINE = "machine"

local _offers: { [Player]: { Level: number, Id: string } } = {}
-- 玩家最近一次材质机抽取 / 换一个的 os.clock()，客户端 3D 表演期间拒绝重复请求
local _rollAt: { [Player]: number } = {}
local _teleportAt: { [Player]: number } = {}
local _ownedPass: { [Player]: { [string]: boolean } } = {}
local _padDebounce: { [string]: number } = {}
local _machines: { [number]: Model } = {}
local _limitedStand: Model?
local _limitedSold = ArmWrestleConfig.LIMITED_SOLD_DEFAULT
local _isInBattle: ((Player) -> boolean)?
local _afterChange: ((Player, { [string]: any }, boolean) -> ())?
local _guideEvent: ((Player, { [string]: any }, string, any?) -> ())?

--[[
	是否拥有通行证（会话 + 档案）
	@param plr Player - 玩家
	@param key string - AutoClicker 等
	@return boolean
]]
function Economy.HasPass(plr: Player, key: string): boolean
	local owned = _ownedPass[plr]
	if owned and owned[key] then
		return true
	end
	return false
end

--[[
	会话通行证表（只读拷贝用途：调用方勿长期持有）
	@param plr Player - 玩家
	@return table
]]
function Economy.GetPasses(plr: Player): { [string]: boolean }
	return _ownedPass[plr] or {}
end

--[[
	注入依赖
	@param deps table - { isInBattle: (Player) -> boolean, afterChange: 写档后同步回调, guideEvent: 新手引导结算事件回调 (plr, data, 事件名, 参数?)，材质机触发成功时发 "machine" }
]]
function Economy.Bind(deps: {
	isInBattle: (Player) -> boolean,
	afterChange: (Player, { [string]: any }, boolean) -> (),
	guideEvent: ((Player, { [string]: any }, string, any?) -> ())?,
})
	_isInBattle = deps.isInBattle
	_afterChange = deps.afterChange
	_guideEvent = deps.guideEvent
end

--[[
	金币变动 + 写档原子提交；成功同步镜像，失败用存档真值回滚外观/镜像
	@param plr Player - 玩家
	@param data table - 已原地修改的档案
	@param coinDelta number - 金币增减（负数为扣除）
	@return boolean - 是否成功
]]
local function _commit(plr: Player, data: { [string]: any }, coinDelta: number): boolean
	local afterChange = _afterChange
	if not afterChange then
		return false
	end
	if Profile.Commit(plr, data, coinDelta) then
		SystemSave.AfterCommit(plr, function()
			afterChange(plr, data, false)
		end)
		return true
	end
	local fresh = Profile.Get(plr)
	if fresh then
		SystemSave.AfterCommit(plr, function()
			afterChange(plr, fresh, false)
		end)
	end
	return false
end

--[[
	金币不足时提示差额
	@param plr Player - 玩家
	@param price number - 所需金币
	@return boolean - 足够为 true
]]
local function _checkCoin(plr: Player, price: number): boolean
	local coin = Profile.GetCoin(plr)
	if coin >= price then
		return true
	end
	TipsModule.ErrorTips(plr, "现金不足", { ArmWrestleConfig.Format(math.ceil(price - coin)) })
	return false
end

--[[
	刷新限量展台剩余数（只写 Left 属性；库存文案由客户端 WorldText 按翻译键渲染）
]]
local function _refreshStock()
	if not _limitedStand then
		return
	end
	local arm = ArmWrestleConfig.GetArm(LIMITED_ID)
	local limit = arm and arm.Limited or 250
	_limitedStand:SetAttribute("Left", math.max(limit - _limitedSold, 0))
end

--[[
	加载并刷新限量库存
]]
function Economy.RefreshStock()
	local ok, value = SystemDataStore.Get(STORE_GLOBAL, STOCK_KEY)
	if ok and type(value) == "number" then
		_limitedSold = value
	end
	_refreshStock()
end

--[[
	消耗一件限量
]]
local function _consumeStock()
	_limitedSold += 1
	SystemDataStore.Update(STORE_GLOBAL, STOCK_KEY, function(old)
		return (if type(old) == "number" then old else ArmWrestleConfig.LIMITED_SOLD_DEFAULT) + 1
	end)
	_refreshStock()
end

--[[
	玩家是否靠近零件
	@param plr Player - 玩家
	@param part BasePart - 目标
	@param dist number - 距离
	@return boolean
]]
local function _near(plr: Player, part: BasePart, dist: number): boolean
	local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	return hrp ~= nil and (hrp.Position - part.Position).Magnitude <= dist
end

--[[
	授予材质
	@param plr Player - 玩家
	@param data table - 档案
	@param id string - 材质 Id
	@return boolean - 是否新获得
]]
local function _grantMaterial(plr: Player, data: { [string]: any }, id: string): boolean
	local mat = ArmWrestleConfig.GetMaterial(id)
	if not mat then
		return false
	end
	local isNew = data.Mats[id] ~= true
	data.Mats[id] = true
	local cur = ArmWrestleConfig.GetMaterial(data.Mat)
	if not cur or mat.Mult > cur.Mult then
		data.Mat = id
	end
	Look.Apply(plr, data)
	return isNew
end

--[[
	授予手臂
	@param plr Player - 玩家
	@param data table - 档案
	@param id number - 手臂 Id
]]
local function _grantArm(plr: Player, data: { [string]: any }, id: number)
	data.Arms[tostring(id)] = true
	local arm = ArmWrestleConfig.GetArm(id)
	local cur = ArmWrestleConfig.GetArm(data.Arm)
	if arm and (not cur or arm.Mult > cur.Mult) then
		data.Arm = id
	end
	Look.Apply(plr, data)
end

--[[
	发货（Studio DevGrant 或收据事务内调用）；已拥有的力量倍数档按空操作成功处理，保证收据可被确认
	@param plr Player - 玩家
	@param key string - 商品键（ArmWrestleConfig._PRODUCTS 的键）
	@return boolean - 成功（含重复档空操作）为 true；档案未就绪/配置缺失/写档失败为 false
]]
function Economy.GrantProduct(plr: Player, key: string): boolean
	local data = Profile.Get(plr)
	local product = ArmWrestleConfig.GetProduct(key)
	if not data or not product or not _afterChange then
		return false
	end
	local coinDelta = 0
	local isLimitedArm = false
	local notify: () -> ()
	if product.Kind == "StrengthTier" then
		if (data.StrengthTier or 0) >= product.Tier then
			Log.warn("SystemArmWrestle.Economy 重复购买已拥有力量倍数档", plr.UserId, key, data.StrengthTier)
			return true
		end
		-- 跳档购买直接升到该档，不回退、不叠乘
		data.StrengthTier = product.Tier
		notify = function()
			TipsModule.NormalTips(plr, "力量倍数提升", { tostring(product.Mult) })
		end
	elseif product.Kind == "Cash" then
		coinDelta = math.floor(Profile.BestReward(data) * (product.Amount or 0))
		notify = function()
			TipsModule.NormalTips(plr, "获得现金", { ArmWrestleConfig.Format(coinDelta) })
		end
	elseif product.Kind == "Strength" then
		local perClick = select(1, Profile.GetMults(plr, data, Economy.GetPasses(plr)))
		local amt = perClick * (product.Amount or 0)
		Profile.AddStrength(plr, data, amt, Economy.GetPasses(plr))
		notify = function()
			TipsModule.NormalTips(plr, "获得力量", { ArmWrestleConfig.Format(amt) })
		end
	elseif product.Kind == "Arm" then
		local arm = ArmWrestleConfig.GetArm(product.ArmId)
		isLimitedArm = arm ~= nil and arm.Limited ~= nil
		_grantArm(plr, data, product.ArmId)
		data.Arm = product.ArmId
		notify = function()
			TipsModule.NormalTips(plr, "获得手臂", { arm and arm.ZhName or "" })
		end
	elseif product.Kind == "Material" then
		_grantMaterial(plr, data, product.MatId)
		data.Mat = product.MatId
		local mat = ArmWrestleConfig.GetMaterial(product.MatId)
		notify = function()
			TipsModule.NormalTips(plr, "获得材质", { mat and mat.ZhName or "" })
		end
	elseif product.Kind == "Potion" then
		local potion = ArmWrestleConfig.GetPotion(product.PotionKey)
		local count = product.Count or 0
		if not potion or count <= 0 then
			return false
		end
		-- 药水库存只在背包；档案不变，不走 _commit
		local added = SystemBag.AddItems(plr, { potion.ItemId }, { count })
		if not added then
			return false
		end
		SystemSave.AfterCommit(plr, function()
			TipsModule.NormalTips(plr, "获得药水", { { potion.ZhName }, tostring(count) })
		end)
		return true
	else
		return false
	end
	if not _commit(plr, data, coinDelta) then
		return false
	end
	if isLimitedArm then
		SystemSave.AfterCommit(plr, _consumeStock)
	end
	SystemSave.AfterCommit(plr, notify)
	return true
end

--[[
	授予通行证到会话（Studio DevGrant、购买回调、进服拥有权查询）
	@param plr Player - 玩家
	@param key string - 通行证键（AutoClicker / DoubleStrength / DoubleCash）
	@param silent boolean? - true 时不弹「解锁通行证」提示（进服恢复已购通行证用），默认 false
]]
function Economy.GrantPass(plr: Player, key: string, silent: boolean?)
	if not _ownedPass[plr] then
		return
	end
	_ownedPass[plr][key] = true
	local pass = ArmWrestleConfig.GetGamePass(key)
	if pass and not silent then
		TipsModule.NormalTips(plr, "解锁通行证", { pass.ZhName })
	end
	local data = Profile.Get(plr)
	if data and _afterChange then
		_afterChange(plr, data, false)
	end
end

--[[
	购买升级垫
	@param plr Player - 玩家
	@param kind string - TrainSpeed / WalkSpeed
	@param tier number - 目标阶
]]
local function _buyUpgrade(plr: Player, kind: string, tier: number)
	local data = Profile.Get(plr)
	if not data or not _afterChange then
		return
	end
	local list = if kind == "TrainSpeed" then ArmWrestleConfig.GetTrainSpeed() else ArmWrestleConfig.GetWalkSpeed()
	local field = if kind == "TrainSpeed" then "TrainTier" else "SpeedTier"
	if data[field] >= tier then
		return
	end
	if data[field] < tier - 1 then
		TipsModule.ErrorTips(plr, "需要先购买上一级")
		return
	end
	local price = list[tier] and list[tier].Price
	if type(price) ~= "number" then
		return
	end
	if not _checkCoin(plr, price) then
		return
	end
	data[field] = tier
	if not _commit(plr, data, -price) then
		return
	end
	TipsModule.NormalTips(plr, "升级成功")
end

--[[
	绑定世界垫/机/展台
	@param world Instance - Workspace.World
]]
function Economy.BindWorld(world: Instance)
	for _, zone in ipairs(world:GetChildren()) do
		local pads = zone:FindFirstChild("Pads")
		if pads then
			for _, pad in ipairs(pads:GetChildren()) do
				local touch = pad:FindFirstChild("Touch")
				if touch and touch:IsA("BasePart") then
					touch.Touched:Connect(function(hit)
						local plr = Players:GetPlayerFromCharacter(hit.Parent)
						if not plr then
							return
						end
						local key = tostring(plr.UserId) .. pad.Name
						if _padDebounce[key] and os.clock() - _padDebounce[key] < 1.5 then
							return
						end
						_padDebounce[key] = os.clock()
						_buyUpgrade(plr, pad:GetAttribute("Kind"), pad:GetAttribute("Tier"))
					end)
				end
			end
		end
		for _, child in ipairs(zone:GetChildren()) do
			if child.Name:match("^Machine_") and child:IsA("Model") then
				local levelIndex = child:GetAttribute("Level")
				if type(levelIndex) == "number" then
					_machines[levelIndex] = child
					local main = child:FindFirstChild("Main")
					local prompt = main and main:FindFirstChild("Prompt")
					if prompt and prompt:IsA("ProximityPrompt") then
						prompt.Triggered:Connect(function(plr: Player)
							Economy.OnMachine(plr, levelIndex)
						end)
					end
				end
			end
		end
	end
	-- TODO(程莘, 2026-10-15): 限量展台暂时下线，模型已移至 ServerStorage.LimitedStand；恢复时还原下两行并把模型放回 World.Common
	-- local common = world:FindFirstChild("Common")
	-- _limitedStand = common and common:FindFirstChild("LimitedStand")
	if _limitedStand then
		local holder = _limitedStand:FindFirstChild("Holder")
		local prompt = holder and holder:FindFirstChild("Prompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(plr: Player)
				local data = Profile.Get(plr)
				if not data then
					return
				end
				if data.Arms[tostring(LIMITED_ID)] then
					TipsModule.NormalTips(plr, "已拥有审判之臂")
					return
				end
				if (_limitedStand:GetAttribute("Left") or 0) <= 0 then
					TipsModule.ErrorTips(plr, "已售罄")
					return
				end
				if IS_STUDIO then
					Economy.GrantProduct(plr, "JudgementArm")
				else
					TipsModule.ErrorTips(plr, "商品未配置")
				end
			end)
		end
	end
end

--[[
	材质机抽取是否仍在冷却（上一次抽取 / 换一个的客户端表演尚未结束）
	@param plr Player - 玩家
	@return boolean - 冷却中为 true
]]
local function _isRollCooling(plr: Player): boolean
	local last = _rollAt[plr]
	return last ~= nil and os.clock() - last < ArmWrestleConfig.ROLL_COOLDOWN_SEC
end

--[[
	触发材质机：服务端抽取并结算，下发 Offer / Result（载荷带 Level 供客户端在对应机器播放 3D 表演）
	@param plr Player - 玩家
	@param levelIndex number - 关卡
]]
function Economy.OnMachine(plr: Player, levelIndex: number)
	local data = Profile.Get(plr)
	if not data or not _isInBattle or _isInBattle(plr) or not _afterChange then
		return
	end
	if levelIndex > (data.Unlocked or 1) then
		TipsModule.ErrorTips(plr, "需要先解锁关卡", { tostring(levelIndex) })
		return
	end
	local level = ArmWrestleConfig.GetLevel(levelIndex)
	local machine = level and level.Machine
	if not machine or _isRollCooling(plr) then
		return
	end
	if machine.Mode == "Offer" then
		local id = ArmWrestleConfig.PickFromPool(machine.Pool)
		if not id then
			return
		end
		_offers[plr] = { Level = levelIndex, Id = id }
		_rollAt[plr] = os.clock()
		local mat = ArmWrestleConfig.GetMaterial(id)
		NetWork.FireClient(plr, NetMsg.ARM_WRESTLE_ROLL, "Offer", {
			Id = id,
			Level = levelIndex,
			Price = mat and mat.OfferPrice,
			Owned = data.Mats[id] == true,
		})
		if _guideEvent then
			_guideEvent(plr, data, GUIDE_EVENT_MACHINE, levelIndex)
		end
	else
		local price = machine.Price or 0
		if not _checkCoin(plr, price) then
			return
		end
		local id = ArmWrestleConfig.PickFromPool(machine.Pool)
		local refund = 0
		if id and data.Mats[id] then
			refund = math.floor(price * 0.5)
		elseif id then
			_grantMaterial(plr, data, id)
		end
		if not _commit(plr, data, refund - price) then
			return
		end
		_rollAt[plr] = os.clock()
		NetWork.FireClient(plr, NetMsg.ARM_WRESTLE_ROLL, "Result", {
			Id = id,
			Level = levelIndex,
			Pool = machine.Pool,
			Refund = refund,
		})
		if _guideEvent then
			_guideEvent(plr, data, GUIDE_EVENT_MACHINE, levelIndex)
		end
	end
end

--[[
	客户端 Action
	@param plr Player - 玩家
	@param action string - 动作名：BuyArm / EquipArm / EquipMat / BuyDumbbell / EquipDumbbell / OfferBuy / OfferNext / SetAuto / Teleport / DevGrant
	@param ... any - 参数（BuyDumbbell / EquipDumbbell 为哑铃 Id number；Teleport 为 1-based 关卡下标 number）
	@return any - 结果：成功 true；失败 false 与可选失败码（cash / owned / battle / robux / pass / studio / locked：Teleport 目标关未解锁 / wait：OfferNext 抽取冷却中或 Teleport 冷却中）
]]
function Economy.OnAction(plr: Player, action: string, ...: any): any
	local data = Profile.Get(plr)
	if not data or not _afterChange then
		return false
	end
	if action == "BuyArm" then
		local id = ...
		local arm = ArmWrestleConfig.GetArm(id)
		if not arm or data.Arms[tostring(id)] then
			return false
		end
		if arm.Robux then
			if IS_STUDIO and arm.ProductKey then
				return Economy.GrantProduct(plr, arm.ProductKey)
			end
			return false, "robux"
		end
		local price = arm.Price or 0
		if Profile.GetCoin(plr) < price then
			return false, "cash"
		end
		_grantArm(plr, data, id)
		data.Arm = id
		if not _commit(plr, data, -price) then
			return false, "cash"
		end
		return true
	elseif action == "EquipArm" then
		local id = ...
		if not data.Arms[tostring(id)] then
			return false
		end
		data.Arm = id
		Look.Apply(plr, data)
		Profile.Save(plr, data)
		_afterChange(plr, data, false)
		return true
	elseif action == "EquipMat" then
		local id = ...
		if not data.Mats[id] then
			return false
		end
		data.Mat = id
		Look.Apply(plr, data)
		Profile.Save(plr, data)
		_afterChange(plr, data, false)
		return true
	elseif action == "BuyDumbbell" then
		local id = ...
		local dumbbell = ArmWrestleConfig.GetDumbbell(id)
		if not dumbbell or data.Dumbbells[tostring(id)] then
			return false
		end
		if _isInBattle and _isInBattle(plr) then
			return false, "battle"
		end
		local price = dumbbell.Price or 0
		if Profile.GetCoin(plr) < price then
			return false, "cash"
		end
		data.Dumbbells[tostring(id)] = true
		data.Dumbbell = id
		if not _commit(plr, data, -price) then
			return false, "cash"
		end
		Look.EnsureDumbbell(plr, id)
		return true
	elseif action == "EquipDumbbell" then
		local id = ...
		if type(id) ~= "number" or not data.Dumbbells[tostring(id)] then
			return false
		end
		if _isInBattle and _isInBattle(plr) then
			return false, "battle"
		end
		data.Dumbbell = id
		if not _commit(plr, data, 0) then
			return false
		end
		Look.EnsureDumbbell(plr, id)
		return true
	elseif action == "OfferBuy" then
		local offer = _offers[plr]
		local machine = offer and _machines[offer.Level]
		local main = machine and machine:FindFirstChild("Main")
		if not offer or not main or not main:IsA("BasePart") or not _near(plr, main, ArmWrestleConfig.NEAR_MACHINE_STUDS) then
			return false
		end
		local mat = ArmWrestleConfig.GetMaterial(offer.Id)
		local price = mat and mat.OfferPrice or 0
		if not mat or Profile.GetCoin(plr) < price then
			return false, "cash"
		end
		if data.Mats[offer.Id] then
			return false, "owned"
		end
		_grantMaterial(plr, data, offer.Id)
		if not _commit(plr, data, -price) then
			return false, "cash"
		end
		_offers[plr] = nil
		return true, offer.Id
	elseif action == "OfferNext" then
		local offer = _offers[plr]
		local machine = offer and _machines[offer.Level]
		local main = machine and machine:FindFirstChild("Main")
		if not offer or not main or not main:IsA("BasePart") or not _near(plr, main, ArmWrestleConfig.NEAR_MACHINE_STUDS) then
			return false
		end
		if _isRollCooling(plr) then
			return false, "wait"
		end
		local level = ArmWrestleConfig.GetLevel(offer.Level)
		offer.Id = ArmWrestleConfig.PickFromPool(level.Machine.Pool) or offer.Id
		_rollAt[plr] = os.clock()
		local mat = ArmWrestleConfig.GetMaterial(offer.Id)
		return true,
			{ Id = offer.Id, Level = offer.Level, Price = mat and mat.OfferPrice, Owned = data.Mats[offer.Id] == true }
	elseif action == "SetAuto" then
		local on = ...
		if on and not Economy.HasPass(plr, "AutoClicker") then
			if IS_STUDIO then
				Economy.GrantPass(plr, "AutoClicker")
			else
				return false, "pass"
			end
		end
		plr:SetAttribute("AutoOn", on == true)
		return true
	elseif action == "Teleport" then
		local levelIndex = ...
		if type(levelIndex) ~= "number" or levelIndex % 1 ~= 0 or not ArmWrestleConfig.GetLevel(levelIndex) then
			return false
		end
		if Battle.IsInBattle(plr) then
			return false, "battle"
		end
		if levelIndex > (data.Unlocked or 1) then
			return false, "locked"
		end
		local last = _teleportAt[plr]
		if last and os.clock() - last < TELEPORT_COOLDOWN_SEC then
			return false, "wait"
		end
		_teleportAt[plr] = os.clock()
		return Battle.TeleportZone(plr, levelIndex)
	elseif action == "DevGrant" then
		if not IS_STUDIO then
			return false, "studio"
		end
		local kind, key = ...
		if kind == "Pass" and ArmWrestleConfig.GetGamePass(key) then
			Economy.GrantPass(plr, key)
			return true
		elseif kind == "Product" and ArmWrestleConfig.GetProduct(key) then
			return Economy.GrantProduct(plr, key)
		end
		return false
	end
	return false
end

--[[
	调试：一次性解锁某类全部款式（仅供服务端 DebugManager 在 Dev 服校验后经 SystemArmWrestle 调用）
	只写拥有表，不改当前装备、不扣限量库存、不弹获得提示
	@param plr Player - 目标玩家（须在线且档案已加载）
	@param kind string - "Arm" 全部手臂 / "Mat" 全部材质 / "Dumbbell" 全部哑铃
	@return boolean - 写档成功为 true
	@return string? - 失败码：INVALID_KIND 类别非法 / PROFILE_NOT_READY 档案未就绪 / COMMIT_FAILED 写档失败
]]
function Economy.DebugUnlockAll(plr: Player, kind: string): (boolean, string?)
	local data = Profile.Get(plr)
	if not data or not _afterChange then
		return false, "PROFILE_NOT_READY"
	end
	if kind == "Arm" then
		for _, arm in ipairs(ArmWrestleConfig.GetArms()) do
			data.Arms[tostring(arm.Id)] = true
		end
	elseif kind == "Mat" then
		for _, mat in ipairs(ArmWrestleConfig.GetMaterials()) do
			data.Mats[mat.Id] = true
		end
	elseif kind == "Dumbbell" then
		for _, dumbbell in ipairs(ArmWrestleConfig.GetDumbbells()) do
			data.Dumbbells[tostring(dumbbell.Id)] = true
		end
	else
		return false, "INVALID_KIND"
	end
	if not _commit(plr, data, 0) then
		return false, "COMMIT_FAILED"
	end
	return true
end

--[[
	进服向 Roblox 查询已购通行证并静默写入会话（拥有权以 Roblox 为准，不落存档）；Id 为 0 的 Studio 占位跳过
	@param plr Player - 玩家
]]
local function _loadOwnedPasses(plr: Player)
	local changed = false
	for key, pass in pairs(ArmWrestleConfig.GetGamePasses()) do
		if type(pass.Id) ~= "number" or pass.Id <= 0 then
			continue
		end
		local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, plr.UserId, pass.Id)
		if not ok then
			Log.warn("SystemArmWrestle.Economy 查询通行证失败", plr.UserId, key, owned)
		elseif owned and plr.Parent and _ownedPass[plr] then
			Economy.GrantPass(plr, key, true)
			changed = true
		end
	end
	local afterChange = _afterChange
	local data = changed and Profile.Get(plr)
	if data and afterChange then
		afterChange(plr, data, false)
	end
end

--[[
	入服会话：建通行证会话表并后台查询已购通行证
	@param plr Player - 玩家
]]
function Economy.SetupPlayer(plr: Player)
	_ownedPass[plr] = {}
	plr:SetAttribute("AutoOn", false)
	task.spawn(_loadOwnedPasses, plr)
end

--[[
	离场清理
	@param plr Player - 玩家
]]
function Economy.OnPlayerRemoving(plr: Player)
	_ownedPass[plr] = nil
	_offers[plr] = nil
	_rollAt[plr] = nil
	_teleportAt[plr] = nil
end

return Economy
