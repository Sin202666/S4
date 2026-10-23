--[[
	Module: ArmWrestleConfig
	Description: 扳手腕玩法共享配置（关卡、手臂、材质、哑铃、升级、商品表）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	功能：
	- 提供关卡/对手/手臂/材质/哑铃/训练与移速阶、Studio 商品表
	- 成长与对局数值来自导表：AWConst / AWMaterial / AWArm / AWDumbbell / AWUpgrade / AWLevel / AWEnemy
	- ApplyDumbbellLook：按哑铃配置给模板克隆体改色（服务端发 Tool、客户端卡片预览共用）
	- 手臂 / 材质 / 哑铃条目的 Xyd（1..7）指向 _RARITIES（GetRarity），仅用于 UI 底色、文案与表现档位，不参与结算；与物品表 xyd 同语义
	- 手臂 / 材质 / 哑铃 / 关卡条目的 Icon：弹窗卡片 Preview（ImageLabel）展示图（rbxassetid，群组资源）；关卡为场景底图
	- 材质抽取权重按关卡箱子 AWLevel.PoolWeights（与 Pool 按位对齐）；同材质可在不同箱有不同权重；PoolOdds/PickFromPool 只读箱子权重
	- 查询 API 一律返回深拷贝，禁止把内存表活引用交给调用方
	- 玩家可见名称走 ZhName / ZhDes，由 TranslationHelper 按字面量或 Zh* 字段翻译

	与相关模块：
	- SystemArmWrestle 读本表做服务端结算；客户端只读展示
	- 不写存档、不发奖、不绑 Remote
	- Robux 商品 / 通行证：ItemShopData + GamePassItem（导表 itemshopdataConf / gamepassitemConf）；本模块按 OnlyTag 组装展示与发货语义
	- ItemShopData.Kind：StrengthTier / Strength / Cash / Arm / Material；药水无 Kind，购买走 itemID→背包
	- passID=0 仅 Studio DevGrant；真实 Id 经 SystemBuyRoblox.ProcessReceipt（CfgFind.FindCfgByPassID → CreateGrantSnapshot）
	- 通行证落档 data.GamePass[OnlyTag]，进服 SystemShop.Init 按 UserOwnsGamePassAsync 补发
	- 力量倍数档 StrengthTier1..6 为替换式（x2..x64），GetStrengthTierMult 由 Profile.GetMults 唯一消费
	- 药水 GetPotion：库存是背包物品（ItemId 对应 itemdataConf 201~203），使用后按在线秒数计时（服务端 SystemArmWrestle.Potion）
	- 商城分区顺序：ShopPassOrder / ShopPackOrder / PotionOrder（常量表）；稀有度 _RARITIES 仍本文件
	- FormatFixed：三位有效数字价签（1.00T / 10.0B）；Format 为通用缩写（去尾零）
	- 离线奖励参数 OFFLINE_RATE / OFFLINE_MIN_SEC / OFFLINE_MAX_SEC：服务端 SystemArmWrestle.Offline 结算
	- 菜单挽留礼物倍数 MENU_GIFT_CASH_MULT：服务端 SystemArmWrestle.MenuGift 结算（每账号一次）
	- 数值设计说明见 docs/扳手腕数值设计说明.md

	加载：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local ArmWrestleConfig = Utils.ArmWrestleConfig
		local arm = ArmWrestleConfig.GetArm(1)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Copy = Utils.Copy
local ConfigInstance = Utils.ConfigInstance
local EnumMgr = Utils.EnumMgr
local Log = Utils.Log

local ArmWrestleConfig = {}

local function _clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	return Copy.deepCopy(value)
end

--[[
	读 AWConst 数值；缺行或缺 Value 时用 fallback
	@param key string - 常量键（与 AWConst.xlsx Key 一致）
	@param fallback number - 缺省值
	@return number - 表值或 fallback
]]
local function _const(key: string, fallback: number): number
	local row = ConfigInstance.awconstConf and ConfigInstance.awconstConf[key]
	local value = row and row.Value
	if type(value) == "number" then
		return value
	end
	return fallback
end

--[[
	RGB 三列拼 Color3
	@param r number? - 红 0–255
	@param g number? - 绿 0–255
	@param b number? - 蓝 0–255
	@return Color3 - 颜色
]]
local function _rgb(r: number?, g: number?, b: number?): Color3
	return Color3.fromRGB(r or 0, g or 0, b or 0)
end

--[[
	导表行最大数字主键
	@param conf table - ConfigInstance 子表
	@return number - 最大 Id；空表为 0
]]
local function _maxNumericKey(conf: { [any]: any }): number
	local maxId = 0
	for id in pairs(conf) do
		if type(id) == "number" and id > maxId then
			maxId = id
		end
	end
	return maxId
end

--[[
	从 awmaterialConf 组装材质数组（按 Mult 升序；Price/ProductKey 为 0/空则省略字段）
	@return {table} - 材质列表
]]
local function _loadMaterials(): { { [string]: any } }
	local conf = ConfigInstance.awmaterialConf or {}
	local list = {}
	for id, row in pairs(conf) do
		if type(row) == "table" and type(id) == "string" then
			local entry: { [string]: any } = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Xyd = row.Xyd or 1,
				Mat = row.Mat,
				Color = _rgb(row.ColorR, row.ColorG, row.ColorB),
				Icon = row.Icon,
			}
			if type(row.Price) == "number" and row.Price > 0 then
				entry.Price = row.Price
			end
			if type(row.ProductKey) == "string" and row.ProductKey ~= "" then
				entry.ProductKey = row.ProductKey
			end
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return (a.Mult or 0) < (b.Mult or 0)
	end)
	return list
end

--[[
	从 awarmConf 组装手臂稠密数组；Robux/Limited/ProductKey 仅在 >0 / 非空时写入（兼容 if arm.Robux）
	@return {table} - 手臂列表（下标=Id）
]]
local function _loadArms(): { { [string]: any } }
	local conf = ConfigInstance.awarmConf or {}
	local maxId = _maxNumericKey(conf)
	local list = table.create(maxId)
	for id = 1, maxId do
		local row = conf[id]
		if type(row) == "table" then
			local entry: { [string]: any } = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Xyd = row.Xyd or 1,
				Price = row.Price or 0,
				Color = _rgb(row.ColorR, row.ColorG, row.ColorB),
				Icon = row.Icon,
			}
			if type(row.Robux) == "number" and row.Robux > 0 then
				entry.Robux = row.Robux
			end
			if type(row.ProductKey) == "string" and row.ProductKey ~= "" then
				entry.ProductKey = row.ProductKey
			end
			if type(row.Limited) == "number" and row.Limited > 0 then
				entry.Limited = row.Limited
			end
			list[id] = entry
		end
	end
	return list
end

--[[
	从 awdumbbellConf 组装哑铃稠密数组
	@return {table} - 哑铃列表（下标=Id）
]]
local function _loadDumbbells(): { { [string]: any } }
	local conf = ConfigInstance.awdumbbellConf or {}
	local maxId = _maxNumericKey(conf)
	local list = table.create(maxId)
	for id = 1, maxId do
		local row = conf[id]
		if type(row) == "table" then
			list[id] = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Xyd = row.Xyd or 1,
				Price = row.Price or 0,
				PlateColor = _rgb(row.PlateR, row.PlateG, row.PlateB),
				PlateMat = row.PlateMat,
				PlateScale = row.PlateScale,
				HandleColor = _rgb(row.HandleR, row.HandleG, row.HandleB),
				Icon = row.Icon,
			}
		end
	end
	return list
end

--[[
	从 awupgradeConf 按 Kind 组装阶数组；Level=0 为基础档（不写 Price/Level 字段，与旧表形状一致）
	@param kind string - TrainSpeed / WalkSpeed
	@return {table} - 阶列表（按 Level 升序）
]]
local function _loadUpgradeKind(kind: string): { { [string]: any } }
	local conf = ConfigInstance.awupgradeConf or {}
	local rows = {}
	for _, row in pairs(conf) do
		if type(row) == "table" and row.Kind == kind then
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, b)
		return (a.Level or 0) < (b.Level or 0)
	end)
	local list = table.create(#rows)
	for _, row in ipairs(rows) do
		local entry: { [string]: any } = { Value = row.Value }
		local level = row.Level or 0
		if level > 0 then
			entry.Level = level
			entry.Price = row.Price or 0
		end
		table.insert(list, entry)
	end
	return list
end

--[[
	从 awlevelConf + awenemyConf 组装关卡数组（对手按 Power 升序）
	@return {table} - 关卡列表（下标=关卡 Id）
]]
local function _loadLevels(): { { [string]: any } }
	local levelConf = ConfigInstance.awlevelConf or {}
	local oppConf = ConfigInstance.awenemyConf or {}
	local maxLevel = _maxNumericKey(levelConf)
	local byLevel: { [number]: { { [string]: any } } } = {}
	for oppId, row in pairs(oppConf) do
		if type(row) == "table" and type(row.Level) == "number" then
			local level = row.Level
			local bucket = byLevel[level]
			if not bucket then
				bucket = {}
				byLevel[level] = bucket
			end
			table.insert(bucket, {
				Id = oppId,
				ZhName = row.ZhName,
				Model = row.Model,
				Power = row.Power,
				Reward = row.Reward,
				Scale = row.Scale,
			})
		end
	end
	for _, bucket in pairs(byLevel) do
		table.sort(bucket, function(a, b)
			return (a.Power or 0) < (b.Power or 0)
		end)
	end
	local list = table.create(maxLevel)
	for levelId = 1, maxLevel do
		local row = levelConf[levelId]
		if type(row) == "table" then
			local pool = if type(row.Pool) == "table" then row.Pool else {}
			local poolWeights = if type(row.PoolWeights) == "table" then row.PoolWeights else {}
			if #pool ~= #poolWeights then
				Log.warn(
					`[ArmWrestleConfig] level {levelId} Pool(#={#pool}) vs PoolWeights(#={#poolWeights}) length mismatch`
				)
			end
			local machine: { [string]: any } = {
				Mode = row.MachineMode,
				ZhName = row.MachineZhName,
				Pool = pool,
				PoolWeights = poolWeights,
			}
			list[levelId] = {
				ZhName = row.ZhName,
				Theme = row.Theme,
				Gate = row.Gate,
				Ground = {
					Mat = row.GroundMat,
					Color = _rgb(row.GroundR, row.GroundG, row.GroundB),
				},
				Icon = row.Icon,
				Opponents = byLevel[levelId] or {},
				Machine = machine,
			}
		end
	end
	return list
end

ArmWrestleConfig.TOOL_NAME = "哑铃"
-- ReplicatedStorage 下的文件夹路径，末端子节点名为 TOOL_NAME
ArmWrestleConfig.TOOL_ASSET_PATH = { "Assets", "ModelRes", "Dumbbell" }
ArmWrestleConfig.WORLD_NAME = "World"
ArmWrestleConfig.BATTLE_OWNER = "ArmWrestle:Battle"
ArmWrestleConfig.WALK_MODIFIER = "ArmWrestle:Walk"
ArmWrestleConfig.STOCK_KEY = "ArmWrestleJudgementSold"
-- 桌子 Model 上由场景烘焙的 R6 玩家入座 HRP CFrame；对手 HRP 为 OppPivot
ArmWrestleConfig.SEAT_ATTR = "R6Seat"
-- 擂台四面有挡墙进不去，对局结束服务端把玩家送到此 HRP CFrame（擂台正面围栏外）
ArmWrestleConfig.EXIT_ATTR = "R6Exit"
ArmWrestleConfig.OPPONENT_MODEL_NAME = "Opponent"
-- AnimationModule/Animation.luau 中的逻辑名；对局拉锯片长 1 秒，TimePosition = P（对手 1-P）
ArmWrestleConfig.ANIM_TRAIN = "AW_Train"
ArmWrestleConfig.ANIM_BATTLE = "AW_Battle"
ArmWrestleConfig.ANIM_WIN = "AW_Win"
ArmWrestleConfig.ANIM_LOSE = "AW_Lose"
-- 桌边对手无人挑战时的循环待机（与玩家地面待机共用一片）
ArmWrestleConfig.ANIM_IDLE = "Idle"
-- ReplicatedStorage 下 KeyframeSequence 源文件夹；未上传前 Studio 内用其注册临时动画预览
ArmWrestleConfig.ANIM_SOURCE_PATH = { "Assets", "Animations", "ArmWrestle" }

-- 以下标量来自 AWConst.xlsx；Studio 离线门槛仍用 10 秒便于测试
ArmWrestleConfig.EXIT_PUSH_STUDS = _const("EXIT_PUSH_STUDS", 3)
ArmWrestleConfig.WIN_CINEMATIC_SEC = _const("WIN_CINEMATIC_SEC", 4.6)
ArmWrestleConfig.WIN_RELEASE_DELAY_SEC = _const("WIN_RELEASE_DELAY_SEC", 5.2)
ArmWrestleConfig.LOSE_RELEASE_DELAY_SEC = _const("LOSE_RELEASE_DELAY_SEC", 2.6)
ArmWrestleConfig.LIMITED_ARM_ID = _const("LIMITED_ARM_ID", 12)
ArmWrestleConfig.LIMITED_SOLD_DEFAULT = _const("LIMITED_SOLD_DEFAULT", 96)
ArmWrestleConfig.NEAR_MACHINE_STUDS = _const("NEAR_MACHINE_STUDS", 25)
ArmWrestleConfig.TABLE_PROMPT_DISTANCE = _const("TABLE_PROMPT_DISTANCE", 18)
ArmWrestleConfig.ROLL_ANIM_SEC = _const("ROLL_ANIM_SEC", 3.2)
ArmWrestleConfig.ROLL_COOLDOWN_SEC = ArmWrestleConfig.ROLL_ANIM_SEC
ArmWrestleConfig.FRIEND_BOOST_PER = _const("FRIEND_BOOST_PER", 0.1)
ArmWrestleConfig.FRIEND_BOOST_MAX = _const("FRIEND_BOOST_MAX", 0.5)
ArmWrestleConfig.PREMIUM_BOOST = _const("PREMIUM_BOOST", 0.25)
ArmWrestleConfig.OFFLINE_RATE = _const("OFFLINE_RATE", 0.1)
ArmWrestleConfig.OFFLINE_MIN_SEC = if RunService:IsStudio() then 10 else _const("OFFLINE_MIN_SEC", 300)
ArmWrestleConfig.OFFLINE_MAX_SEC = _const("OFFLINE_MAX_SEC", 28800)
ArmWrestleConfig.MENU_GIFT_CASH_MULT = _const("MENU_GIFT_CASH_MULT", 10)
ArmWrestleConfig.ZoneLength = _const("ZoneLength", 170)
ArmWrestleConfig.ZoneWidth = _const("ZoneWidth", 130)
ArmWrestleConfig.BattleTime = _const("BattleTime", 15)
ArmWrestleConfig.TapPower = _const("TapPower", 0.035)
ArmWrestleConfig.OpponentDrift = _const("OpponentDrift", 0.13)
ArmWrestleConfig.MaxTapsPerSecond = _const("MaxTapsPerSecond", 14)
ArmWrestleConfig.AutoTapsPerSecond = _const("AutoTapsPerSecond", 8)

-- 稀有度档：键=Xyd（与 EnumMgr.Xyd / 物品表 xyd 同语义）；Rank 与键相同，供 Tips 渐变等沿用
local _RARITIES = {
	[1] = { ZhName = "普通", Color = Color3.fromRGB(170, 170, 170), Weight = 60, Rank = 1 },
	[2] = { ZhName = "优秀", Color = Color3.fromRGB(85, 220, 90), Weight = 30, Rank = 2 },
	[3] = { ZhName = "稀有", Color = Color3.fromRGB(70, 160, 255), Weight = 12, Rank = 3 },
	[4] = { ZhName = "史诗", Color = Color3.fromRGB(180, 90, 255), Weight = 5, Rank = 4 },
	[5] = { ZhName = "传说", Color = Color3.fromRGB(255, 170, 30), Weight = 1.5, Rank = 5 },
	[6] = { ZhName = "神话", Color = Color3.fromRGB(255, 60, 80), Weight = 0.4, Rank = 6 },
	[7] = { ZhName = "专属", Color = Color3.fromRGB(255, 90, 220), Weight = 0, Rank = 7 },
}

local _MATERIALS = _loadMaterials()
local _ARMS = _loadArms()
local _DUMBBELLS = _loadDumbbells()
local _TRAIN_SPEED = _loadUpgradeKind("TrainSpeed")
local _WALK_SPEED = _loadUpgradeKind("WalkSpeed")
local _LEVELS = _loadLevels()

-- 药水：Effect 为生效维度（Strength 每次训练力量 / TrainSpeed 训练频率 / Cash 对局金币），Duration 为单瓶在线秒数，Icon 为 ArmWrestleStyle.Icons 的键
-- ItemId 为背包物品 Id（itemdataConf），须与表中 UseScript = ArmWrestlePotion、parms = 本键 的行一一对应
local _POTIONS = {
	StrengthPotion = { ZhName = "力量药水", ZhDes = "力量药水描述", Effect = "Strength", Mult = 2, Duration = 900, ProductKey = "StrengthPotion", Icon = "potionStrength", ItemId = 201 },
	TrainSpeedPotion = { ZhName = "训练速度药水", ZhDes = "训练速度药水描述", Effect = "TrainSpeed", Mult = 2, Duration = 900, ProductKey = "TrainSpeedPotion", Icon = "potionTrainSpeed", ItemId = 202 },
	CashPotion = { ZhName = "金币药水", ZhDes = "金币药水描述", Effect = "Cash", Mult = 2, Duration = 900, ProductKey = "CashPotion", Icon = "potionCash", ItemId = 203 },
}

-- 可走真实收据发货的商品种类（ItemShopData.Kind）；药水走 Items 快照；Arm/Material 含限量/装备，收据路径未覆盖
local _RECEIPT_KINDS = { Strength = true, StrengthTier = true, Cash = true }

local _STRENGTH_TIER_KEYS = { "StrengthTier1", "StrengthTier2", "StrengthTier3", "StrengthTier4", "StrengthTier5", "StrengthTier6" }

ArmWrestleConfig.GamePassOrder = { "AutoClicker", "DoubleStrength", "DoubleCash" }
-- 主界面右侧力量包，自上而下
ArmWrestleConfig.StrengthPackOrder = { "StrengthPack3", "StrengthPack2", "StrengthPack1" }
-- 商城：通行证区、力量区（从小到大）、药水区
ArmWrestleConfig.ShopPassOrder = { "DoubleStrength", "DoubleCash", "AutoClicker" }
ArmWrestleConfig.ShopPackOrder = { "StrengthPack1", "StrengthPack2", "StrengthPack3" }
ArmWrestleConfig.PotionOrder = { "StrengthPotion", "TrainSpeedPotion", "CashPotion" }

--[[
	从 itemshopdataConf 行取正数 passID；0 / 非法视为 Studio 占位
	@param row table - 商城行
	@return number - Roblox 资产 Id；占位为 0
]]
local function _shopPassId(row: { [string]: any }): number
	local id = row.passID
	if type(id) == "number" and id > 0 then
		return id
	end
	return 0
end

--[[
	商城行 → 通行证展示表
	@param row table - cost = GamePass 的 ItemShopData 行
	@return table - { Id, ZhName, ZhDes, Robux }
]]
local function _rowToPass(row: { [string]: any }): { [string]: any }
	return {
		Id = _shopPassId(row),
		ZhName = row.ZhName,
		ZhDes = if type(row.ZhDes) == "string" then row.ZhDes else "",
		Robux = if type(row.price) == "number" then row.price else 0,
	}
end

--[[
	商城行 → 开发者商品展示/发货表（Kind 等来自 ItemShopData 加列）
	@param row table - ItemShopData 行
	@return table - { Id, ZhName, ZhDes, Robux, Kind?, Tier?, Mult?, Amount?, ArmId?, MatId? }
]]
local function _rowToProduct(row: { [string]: any }): { [string]: any }
	local product: { [string]: any } = {
		Id = _shopPassId(row),
		ZhName = row.ZhName,
		ZhDes = if type(row.ZhDes) == "string" then row.ZhDes else "",
		Robux = if type(row.price) == "number" then row.price else 0,
	}
	local kind = row.Kind
	if type(kind) == "string" and kind ~= "" then
		product.Kind = kind
		if kind == "StrengthTier" then
			product.Tier = row.Tier
			product.Mult = row.Mult
		elseif kind == "Strength" or kind == "Cash" then
			product.Amount = row.Amount
		elseif kind == "Arm" then
			product.ArmId = row.ArmId
		elseif kind == "Material" then
			product.MatId = row.MatId
		end
	end
	return product
end

--[[
	从 itemshopdataConf 组装通行证与开发者商品缓存（OnlyTag 为键）
	@return table, table - _GAME_PASSES, _PRODUCTS
]]
local function _loadShopProducts(): ({ [string]: any }, { [string]: any })
	local passes: { [string]: any } = {}
	local products: { [string]: any } = {}
	local productTags: { [string]: boolean } = {}
	for _, key in ipairs(_STRENGTH_TIER_KEYS) do
		productTags[key] = true
	end
	for _, key in ipairs(ArmWrestleConfig.StrengthPackOrder) do
		productTags[key] = true
	end
	for _, key in ipairs(ArmWrestleConfig.PotionOrder) do
		productTags[key] = true
	end
	-- 手臂 / 材质 Robux 商品（Kind = Arm / Material，OnlyTag 与 AWArm/AWMaterial.ProductKey 对齐）
	productTags.HolyArm = true
	productTags.JudgementArm = true
	productTags.ArcaneMaterial = true

	local shopConf = ConfigInstance.itemshopdataConf
	if type(shopConf) ~= "table" then
		Log.warn("ArmWrestleConfig: itemshopdataConf 缺失，通行证/商品表为空")
		return passes, products
	end
	local robuxGamePass = EnumMgr.RobuxType.GamePass
	for _, row in pairs(shopConf) do
		if type(row) == "table" and type(row.OnlyTag) == "string" and row.OnlyTag ~= "" then
			if row.cost == robuxGamePass then
				passes[row.OnlyTag] = _rowToPass(row)
			elseif productTags[row.OnlyTag] then
				products[row.OnlyTag] = _rowToProduct(row)
			end
		end
	end
	return passes, products
end

local _GAME_PASSES, _PRODUCTS = _loadShopProducts()

--[[
	默认存档子树（深拷贝后写入 SaveMetaData / 会话）
	@return table - ArmWrestle 可变副本
]]
function ArmWrestleConfig.GetDefaultProfile(): { [string]: any }
	return {
		Strength = 0,
		Cash = 0,
		Wins = 0,
		Unlocked = 1,
		TrainTier = 1,
		SpeedTier = 1,
		Arms = { ["1"] = true },
		Arm = 1,
		Mats = {},
		Mat = "",
		Dumbbells = { ["1"] = true },
		Dumbbell = 1,
		StrengthTier = 0,
		PotionLeft = {},
		LastOnline = 0,
		OfflinePending = 0,
		MenuGiftClaimed = false,
	}
end

--[[
	稀有度表深拷贝
	@param xyd number - 稀有度档 1..7（普通..专属）；与条目 Xyd / EnumMgr.Xyd 一致
	@return table? - { ZhName, Color, Weight, Rank }；非法档为 nil
]]
function ArmWrestleConfig.GetRarity(xyd: number): { [string]: any }?
	if type(xyd) ~= "number" then
		return nil
	end
	local row = _RARITIES[xyd]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	材质表（深拷贝数组）
	@return {table} - 材质列表
]]
function ArmWrestleConfig.GetMaterials(): { { [string]: any } }
	return _clone(_MATERIALS)
end

--[[
	按 Id 取材质
	@param id string - 材质 Id
	@return table? - 材质条目
]]
function ArmWrestleConfig.GetMaterial(id: string): { [string]: any }?
	if type(id) ~= "string" or id == "" then
		return nil
	end
	for _, row in ipairs(_MATERIALS) do
		if row.Id == id then
			return _clone(row)
		end
	end
	return nil
end

--[[
	手臂表（深拷贝数组）
	@return {table} - 手臂列表
]]
function ArmWrestleConfig.GetArms(): { { [string]: any } }
	return _clone(_ARMS)
end

--[[
	按 Id 取手臂
	@param id number - 手臂 Id（1-12）
	@return table? - 手臂条目
]]
function ArmWrestleConfig.GetArm(id: number): { [string]: any }?
	local row = _ARMS[id]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	哑铃表（深拷贝数组）
	@return {table} - 哑铃列表 { Id, ZhName, Mult, Price, PlateColor, PlateMat, PlateScale, HandleColor }
]]
function ArmWrestleConfig.GetDumbbells(): { { [string]: any } }
	return _clone(_DUMBBELLS)
end

--[[
	按 Id 取哑铃
	@param id number - 哑铃 Id（1-10）；非数字或越界返回 nil
	@return table? - 哑铃条目
]]
function ArmWrestleConfig.GetDumbbell(id: number): { [string]: any }?
	if type(id) ~= "number" then
		return nil
	end
	local row = _DUMBBELLS[id]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按哑铃配置给模板克隆体改外观：名为 Handle 的部件改握把色，其余 BasePart 视为杠铃片（改色/材质/截面放大）
	只能作用于 FindToolTemplate() 的克隆体，禁止直接改模板
	@param root Instance - Tool 克隆体或由其拼出的展示 Model
	@param id number - 哑铃 Id；无效时不做修改
]]
function ArmWrestleConfig.ApplyDumbbellLook(root: Instance, id: number)
	local row = _DUMBBELLS[id]
	if not row then
		return
	end
	local material = (Enum.Material :: any)[row.PlateMat] or Enum.Material.Metal
	for _, part in ipairs(root:GetDescendants()) do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Handle" then
			part.Color = row.HandleColor
		else
			part.Color = row.PlateColor
			part.Material = material
			local size = part.Size
			part.Size = Vector3.new(size.X, size.Y * row.PlateScale, size.Z * row.PlateScale)
		end
	end
end

--[[
	训练速度阶
	@return {table} - 阶列表
]]
function ArmWrestleConfig.GetTrainSpeed(): { { [string]: any } }
	return _clone(_TRAIN_SPEED)
end

--[[
	行走速度阶
	@return {table} - 阶列表
]]
function ArmWrestleConfig.GetWalkSpeed(): { { [string]: any } }
	return _clone(_WALK_SPEED)
end

--[[
	关卡表
	@return {table} - 关卡列表
]]
function ArmWrestleConfig.GetLevels(): { { [string]: any } }
	return _clone(_LEVELS)
end

--[[
	单关配置
	@param index number - 1-based 关卡下标
	@return table? - 关卡条目
]]
function ArmWrestleConfig.GetLevel(index: number): { [string]: any }?
	local row = _LEVELS[index]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按对手 Id 查找
	@param id string - 对手 Id
	@return table? - 对手条目
	@return number? - 关卡下标
]]
function ArmWrestleConfig.GetOpponent(id: string): ({ [string]: any }?, number?)
	if type(id) ~= "string" then
		return nil, nil
	end
	for levelIndex, level in ipairs(_LEVELS) do
		for _, opponent in ipairs(level.Opponents) do
			if opponent.Id == id then
				return _clone(opponent), levelIndex
			end
		end
	end
	return nil, nil
end

--[[
	通行证表（深拷贝）
	@return table - key → 配置
]]
function ArmWrestleConfig.GetGamePasses(): { [string]: any }
	return _clone(_GAME_PASSES)
end

--[[
	单条通行证
	@param key string - AutoClicker 等
	@return table? - 配置
]]
function ArmWrestleConfig.GetGamePass(key: string): { [string]: any }?
	local row = _GAME_PASSES[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按 Roblox GamePass Id 查通行证键（Id 为 0 的 Studio 占位不参与）
	@param passId number - GamePass 资产 Id
	@return string? - 通行证键（AutoClicker 等）；非本玩法通行证为 nil
]]
function ArmWrestleConfig.FindGamePassKey(passId: number): string?
	if type(passId) ~= "number" or passId <= 0 then
		return nil
	end
	for key, row in pairs(_GAME_PASSES) do
		if row.Id == passId then
			return key
		end
	end
	return nil
end

--[[
	单条药水配置
	@param key string - StrengthPotion / TrainSpeedPotion / CashPotion
	@return table? - { ZhName, ZhDes, Effect = "Strength" | "TrainSpeed" | "Cash", Mult, Duration(秒), ProductKey, Icon(ArmWrestleStyle.Icons 键), ItemId(背包物品 Id) }；未知键为 nil
]]
function ArmWrestleConfig.GetPotion(key: string): { [string]: any }?
	local row = _POTIONS[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	开发者商品表
	@return table - key → 配置
]]
function ArmWrestleConfig.GetProducts(): { [string]: any }
	return _clone(_PRODUCTS)
end

--[[
	单条商品
	@param key string - 商品键
	@return table? - 配置
]]
function ArmWrestleConfig.GetProduct(key: string): { [string]: any }?
	local row = _PRODUCTS[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按 Roblox 开发者商品 Id 查可走收据发货的商品键（Id 为 0 的 Studio 占位不参与）
	@param productId number - 收据 ProductId
	@return string? - 商品键；非本玩法商品或种类不支持收据发货时为 nil
]]
function ArmWrestleConfig.FindReceiptProductKey(productId: number): string?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for key, row in pairs(_PRODUCTS) do
		if row.Id == productId and _RECEIPT_KINDS[row.Kind] then
			return key
		end
	end
	return nil
end

--[[
	商品键是否允许走真实收据发货
	@param key string - 商品键
	@return boolean - Kind 属于 Strength / StrengthTier / Cash / Potion 时为 true
]]
function ArmWrestleConfig.IsReceiptProduct(key: string): boolean
	local row = _PRODUCTS[key]
	return row ~= nil and _RECEIPT_KINDS[row.Kind] == true
end

--[[
	力量倍数最高档
	@return number - 档数（当前 6，对应 x64）
]]
function ArmWrestleConfig.GetMaxStrengthTier(): number
	return #_STRENGTH_TIER_KEYS
end

--[[
	按档位取力量倍数商品
	@param tier number - 1..GetMaxStrengthTier()
	@return string? - 商品键（StrengthTier1 等）；越界为 nil
	@return table? - 商品配置深拷贝 { Id, ZhName, Robux, Kind = "StrengthTier", Tier, Mult }
]]
function ArmWrestleConfig.GetStrengthTierProduct(tier: number): (string?, { [string]: any }?)
	local key = _STRENGTH_TIER_KEYS[tier]
	if not key then
		return nil, nil
	end
	return key, _clone(_PRODUCTS[key])
end

--[[
	已购档位对应的力量总倍数（替换式，不与低档叠乘）
	@param tier number? - 存档 StrengthTier；nil / 0 / 非法为未购买
	@return number - 倍数；未购买为 1
]]
function ArmWrestleConfig.GetStrengthTierMult(tier: number?): number
	local key = if type(tier) == "number" then _STRENGTH_TIER_KEYS[math.min(tier, #_STRENGTH_TIER_KEYS)] else nil
	local row = key and _PRODUCTS[key]
	return if row then row.Mult else 1
end

--[[
	奖池概率（按箱子 PoolWeights 与 Pool 按位对齐；<=0 或缺失视为 0）
	@param pool {string} - 材质 Id 列表（关卡 Machine.Pool）
	@param weights {number}? - 与 pool 对齐的权重（关卡 Machine.PoolWeights）；nil 视为全 0
	@return {table} - { Id, Chance }；Chance 之和为 1（总权重为 0 时全为 0）
]]
function ArmWrestleConfig.PoolOdds(pool: { string }, weights: { number }?): { { Id: string, Chance: number } }
	local weightList = weights or {}
	local resolved = table.create(#pool)
	local total = 0
	for i, id in ipairs(pool) do
		local base = weightList[i]
		local weight = if type(base) == "number" and base > 0 then base else 0
		resolved[i] = weight
		total += weight
	end
	local odds = table.create(#pool)
	for i, id in ipairs(pool) do
		odds[i] = { Id = id, Chance = if total > 0 then resolved[i] / total else 0 }
	end
	return odds
end

--[[
	从奖池抽一个材质 Id
	@param pool {string} - 材质 Id（关卡 Machine.Pool）
	@param weights {number}? - 与 pool 对齐的权重（关卡 Machine.PoolWeights）
	@return string? - 抽中的 Id；池空或总权重为 0 为 nil
]]
function ArmWrestleConfig.PickFromPool(pool: { string }, weights: { number }?): string?
	local odds = ArmWrestleConfig.PoolOdds(pool, weights)
	if #odds == 0 then
		return nil
	end
	local totalChance = 0
	for _, row in ipairs(odds) do
		totalChance += row.Chance
	end
	if totalChance <= 0 then
		return nil
	end
	local roll = math.random()
	local acc = 0
	for _, row in ipairs(odds) do
		acc += row.Chance
		if roll <= acc then
			return row.Id
		end
	end
	return odds[#odds].Id
end

--[[
	数字缩写
	@param n number - 原值
	@return string - 展示串
]]
function ArmWrestleConfig.Format(n: number): string
	n = tonumber(n) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	while math.abs(n) >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		if n == math.floor(n) then
			return tostring(n)
		end
		return string.format("%.1f", n)
	end
	local s = string.format("%.2f", n):gsub("%.?0+$", "")
	return s .. suffixes[i]
end

--[[
	数字缩写，保留三位有效数字（1.00T / 10.0B / 100B），用于商品价签
	@param n number - 原值
	@return string - 展示串；小于 1000 取整
]]
function ArmWrestleConfig.FormatFixed(n: number): string
	n = math.max(tonumber(n) or 0, 0)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	-- 999.5 级别四舍五入后会变成 4 位整数，提前进位到下一个单位
	while n >= 999.5 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n + 0.5))
	end
	local fmt = if n >= 99.95 then "%.0f" elseif n >= 9.995 then "%.1f" else "%.2f"
	return string.format(fmt, n) .. suffixes[i]
end

--[[
	关卡原点
	@param levelIndex number - 1-based
	@return Vector3 - 原点
]]
function ArmWrestleConfig.ZoneOrigin(levelIndex: number): Vector3
	return Vector3.new((levelIndex - 1) * ArmWrestleConfig.ZoneLength, 0, 0)
end

--[[
	对局结束出场位姿：EXIT_ATTR 沿其朝向外推 EXIT_PUSH_STUDS，再水平转向桌子，方便玩家转身就能再次交互
	（服务端 Battle 出场写 HRP、客户端交还镜头时摆机位共用，保证两侧朝向一致）
	@param tableModel Model - 比赛桌（读 EXIT_ATTR，桌面中心读 Pivot 属性，缺省用模型 Pivot）
	@return CFrame? - 出场 HRP 位姿（面朝桌子）；桌子缺少 EXIT_ATTR 时为 nil
]]
function ArmWrestleConfig.GetExitCFrame(tableModel: Model): CFrame?
	local exitCf = tableModel:GetAttribute(ArmWrestleConfig.EXIT_ATTR)
	if typeof(exitCf) ~= "CFrame" then
		return nil
	end
	local pos = exitCf.Position + exitCf.LookVector * ArmWrestleConfig.EXIT_PUSH_STUDS
	local center = tableModel:GetAttribute("Pivot")
	if typeof(center) ~= "Vector3" then
		center = tableModel:GetPivot().Position
	end
	local look = Vector3.new(center.X, pos.Y, center.Z)
	if (look - pos).Magnitude < 1e-3 then
		return CFrame.new(pos) * exitCf.Rotation
	end
	return CFrame.lookAt(pos, look)
end

--[[
	基础行走速度（CMS 默认）
	@return number - 16
]]
function ArmWrestleConfig.GetBaseWalkSpeed(): number
	return _WALK_SPEED[1].Value
end

--[[
	查找哑铃 Tool 模板（ReplicatedStorage / TOOL_ASSET_PATH / TOOL_NAME）
	@return Tool? - 模板本体，调用方须 Clone 后使用、禁止直接修改；路径缺失或类型不是 Tool 时为 nil
]]
function ArmWrestleConfig.FindToolTemplate(): Tool?
	local node: Instance? = ReplicatedStorage
	for _, name in ipairs(ArmWrestleConfig.TOOL_ASSET_PATH) do
		node = node and node:FindFirstChild(name)
	end
	local template = node and node:FindFirstChild(ArmWrestleConfig.TOOL_NAME)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

return ArmWrestleConfig
