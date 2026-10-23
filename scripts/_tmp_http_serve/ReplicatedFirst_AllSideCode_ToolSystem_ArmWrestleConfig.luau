--[[
	Module: ArmWrestleConfig
	Description: 扳手腕玩法共享配置（关卡、手臂、材质、哑铃、升级、商品表）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	功能：
	- 提供关卡/对手/手臂/材质/哑铃/训练与移速阶、Studio 商品表
	- ApplyDumbbellLook：按哑铃配置给模板克隆体改色（服务端发 Tool、客户端卡片预览共用）
	- 手臂 / 材质 / 哑铃条目的 Rarity 均指向 _RARITIES（GetRarity），仅用于 UI 底色、文案与表现档位，不参与结算
	- 手臂 / 材质 / 哑铃条目的 Icon：弹窗卡片 Preview（ImageLabel）展示图，带黑描边的透明 PNG（rbxassetid，群组资源）
	- 材质抽取权重读条目自身 Weight（与稀有度解耦，改稀有度不改掉率）；缺省才回退 _RARITIES.Weight；PoolOdds 仅按 Weight
	- 查询 API 一律返回深拷贝，禁止把内存表活引用交给调用方
	- 玩家可见名称走 ZhName / ZhDes，由 TranslationHelper 按字面量或 Zh* 字段翻译

	与相关模块：
	- SystemArmWrestle 读本表做服务端结算；客户端只读展示
	- 不写存档、不发奖、不绑 Remote
	- 线上 Robux 商品 Id 一期全为 0，仅 Studio DevGrant 可用
	- 填入真实 Id 后，Strength / StrengthTier / Cash / Potion 种类经 SystemBuyRoblox.ProcessReceipt 幂等发货（FindReceiptProductKey）
	- 通行证真实 Id 经 FindGamePassKey 反查；拥有权以 Roblox 为准（进服 UserOwnsGamePassAsync），不落存档
	- 力量倍数档 StrengthTier1..6 为替换式（x2..x64），GetStrengthTierMult 由 Profile.GetMults 唯一消费
	- 药水 GetPotion：库存是背包物品（ItemId 对应 itemdataConf 201~203），使用后按在线秒数计时（服务端 SystemArmWrestle.Potion）
	- 商城分区顺序：ShopPassOrder / ShopPackOrder / PotionOrder
	- FormatFixed：三位有效数字价签（1.00T / 10.0B）；Format 为通用缩写（去尾零）
	- 离线奖励参数 OFFLINE_RATE / OFFLINE_MIN_SEC / OFFLINE_MAX_SEC：服务端 SystemArmWrestle.Offline 结算
	- 菜单挽留礼物倍数 MENU_GIFT_CASH_MULT：服务端 SystemArmWrestle.MenuGift 结算（每账号一次）

	加载：
		local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
		local ArmWrestleConfig = Utils.ArmWrestleConfig
		local arm = ArmWrestleConfig.GetArm(1)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Copy = Utils.Copy

local ArmWrestleConfig = {}

local function _clone(value: any): any
	if type(value) ~= "table" then
		return value
	end
	return Copy.deepCopy(value)
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
-- 出场时沿 EXIT_ATTR 朝向再外推的距离（studs）；落点须留在 TABLE_PROMPT_DISTANCE 之内，出场后不走动即可再按 E 开局（场景出场点距 Prompt 约 11.7）
ArmWrestleConfig.EXIT_PUSH_STUDS = 3
-- 获胜演出（客户端 SystemArmWrestle/WinCinematic）总秒数；服务端获胜后交还控制的延迟须大于它，否则演出会被出场传送打断
ArmWrestleConfig.WIN_CINEMATIC_SEC = 4.6
ArmWrestleConfig.WIN_RELEASE_DELAY_SEC = 5.2
ArmWrestleConfig.LOSE_RELEASE_DELAY_SEC = 2.6
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
ArmWrestleConfig.LIMITED_ARM_ID = 12
ArmWrestleConfig.LIMITED_SOLD_DEFAULT = 96
ArmWrestleConfig.NEAR_MACHINE_STUDS = 25
-- 比赛桌「扳手腕」E 交互距离（studs），服务端 Battle.BindWorld 统一覆盖场景 Prompt 的值
ArmWrestleConfig.TABLE_PROMPT_DISTANCE = 18
-- 材质箱 3D 抽取表演（客户端 MachineShowcase：旧手臂缩回、合盖、开盖、升起、定格）的总秒数；服务端同一玩家两次抽取 / 换一个的最小间隔与之对齐，防表演期间连按 E 连续扣钱
ArmWrestleConfig.ROLL_ANIM_SEC = 3.2
ArmWrestleConfig.ROLL_COOLDOWN_SEC = ArmWrestleConfig.ROLL_ANIM_SEC
-- 现金加成：同服每位好友 +10%（封顶 +50%），Roblox 会员 +25%；两者与其它现金倍率独立相乘
ArmWrestleConfig.FRIEND_BOOST_PER = 0.1
ArmWrestleConfig.FRIEND_BOOST_MAX = 0.5
ArmWrestleConfig.PREMIUM_BOOST = 0.25
-- 离线奖励：按在线挂机训练效率的 10% 折算力量；离线不足 5 分钟不给（Studio 为 10 秒便于测试），累计封顶 8 小时（服务端 SystemArmWrestle.Offline）
ArmWrestleConfig.OFFLINE_RATE = 0.1
ArmWrestleConfig.OFFLINE_MIN_SEC = if RunService:IsStudio() then 10 else 300
ArmWrestleConfig.OFFLINE_MAX_SEC = 28800
-- 菜单挽留礼物：关闭 Roblox 菜单后弹窗，免费领「已解锁关最强对手奖励 × 10」现金，与 25 Robux「一沓现金」等额，每账号永久一次
ArmWrestleConfig.MENU_GIFT_CASH_MULT = 10

ArmWrestleConfig.ZoneLength = 170
ArmWrestleConfig.ZoneWidth = 130
ArmWrestleConfig.BattleTime = 15
ArmWrestleConfig.TapPower = 0.035
ArmWrestleConfig.OpponentDrift = 0.13
ArmWrestleConfig.MaxTapsPerSecond = 14
ArmWrestleConfig.AutoTapsPerSecond = 8

local _RARITIES = {
	Common = { ZhName = "普通", Color = Color3.fromRGB(170, 170, 170), Weight = 60, Rank = 1 },
	Uncommon = { ZhName = "优秀", Color = Color3.fromRGB(85, 220, 90), Weight = 30, Rank = 2 },
	Rare = { ZhName = "稀有", Color = Color3.fromRGB(70, 160, 255), Weight = 12, Rank = 3 },
	Epic = { ZhName = "史诗", Color = Color3.fromRGB(180, 90, 255), Weight = 5, Rank = 4 },
	Legendary = { ZhName = "传说", Color = Color3.fromRGB(255, 170, 30), Weight = 1.5, Rank = 5 },
	Mythic = { ZhName = "神话", Color = Color3.fromRGB(255, 60, 80), Weight = 0.4, Rank = 6 },
	Exclusive = { ZhName = "专属", Color = Color3.fromRGB(255, 90, 220), Weight = 0, Rank = 7 },
}

-- Weight 按 Mult 单调递减：同奖池内加成越高越难抽（与 Rarity 解耦）
local _MATERIALS = {
	{ Id = "Sand", ZhName = "沙子", Mult = 1.2, Rarity = "Common", Weight = 60, Mat = "Sand", Color = Color3.fromRGB(226, 205, 145), OfferPrice = 40, Icon = "rbxassetid://122192010470765" },
	{ Id = "Wood", ZhName = "木头", Mult = 1.5, Rarity = "Common", Weight = 48, Mat = "Wood", Color = Color3.fromRGB(160, 110, 60), OfferPrice = 80, Icon = "rbxassetid://128126726660785" },
	{ Id = "Grass", ZhName = "草地", Mult = 2, Rarity = "Uncommon", Weight = 30, Mat = "Grass", Color = Color3.fromRGB(90, 170, 60), OfferPrice = 150, Icon = "rbxassetid://126845964848626" },
	{ Id = "Snow", ZhName = "冰雪", Mult = 2.5, Rarity = "Uncommon", Weight = 22, Mat = "Snow", Color = Color3.fromRGB(235, 245, 255), Icon = "rbxassetid://122005236129409" },
	{ Id = "Rock", ZhName = "岩石", Mult = 3.5, Rarity = "Rare", Weight = 12, Mat = "Slate", Color = Color3.fromRGB(110, 110, 120), Icon = "rbxassetid://130795413314674" },
	{ Id = "Metal", ZhName = "金属", Mult = 5, Rarity = "Rare", Weight = 8, Mat = "DiamondPlate", Color = Color3.fromRGB(170, 175, 185), Icon = "rbxassetid://126111622075252" },
	{ Id = "Water", ZhName = "流水", Mult = 7, Rarity = "Epic", Weight = 5, Mat = "Glass", Color = Color3.fromRGB(60, 150, 255), Icon = "rbxassetid://116870538790500" },
	{ Id = "Brick", ZhName = "砖块", Mult = 10, Rarity = "Epic", Weight = 3, Mat = "Brick", Color = Color3.fromRGB(170, 70, 50), Icon = "rbxassetid://124670707684711" },
	{ Id = "Magma", ZhName = "岩浆", Mult = 15, Rarity = "Epic", Weight = 1.5, Mat = "CrackedLava", Color = Color3.fromRGB(255, 100, 30), Icon = "rbxassetid://104796958921544" },
	{ Id = "Neon", ZhName = "霓虹", Mult = 25, Rarity = "Epic", Weight = 0.8, Mat = "Neon", Color = Color3.fromRGB(255, 60, 200), Icon = "rbxassetid://81720242495997" },
	{ Id = "Diamond", ZhName = "钻石", Mult = 40, Rarity = "Legendary", Weight = 0.4, Mat = "Glass", Color = Color3.fromRGB(120, 240, 255), Icon = "rbxassetid://100212317246111" },
	{ Id = "Arcane", ZhName = "奥术", Mult = 100, Rarity = "Legendary", Weight = 0, Mat = "ForceField", Color = Color3.fromRGB(170, 80, 255), ProductKey = "ArcaneMaterial", Icon = "rbxassetid://110621231829163" },
}

local _ARMS = {
	{ Id = 1, ZhName = "新手之臂", Mult = 1, Rarity = "Common", Price = 0, Color = Color3.fromRGB(234, 184, 146), Icon = "rbxassetid://74809006284031" },
	{ Id = 2, ZhName = "结实之臂", Mult = 1.5, Rarity = "Common", Price = 75, Color = Color3.fromRGB(205, 150, 110), Icon = "rbxassetid://79060817271352" },
	{ Id = 3, ZhName = "青铜之臂", Mult = 2, Rarity = "Uncommon", Price = 250, Color = Color3.fromRGB(205, 127, 50), Icon = "rbxassetid://78998063862787" },
	{ Id = 4, ZhName = "钢铁之臂", Mult = 3, Rarity = "Uncommon", Price = 600, Color = Color3.fromRGB(160, 165, 175), Icon = "rbxassetid://125017192128258" },
	{ Id = 5, ZhName = "冰晶之臂", Mult = 4.5, Rarity = "Rare", Price = 1500, Color = Color3.fromRGB(110, 200, 255), Icon = "rbxassetid://135758805551826" },
	{ Id = 6, ZhName = "雷霆之臂", Mult = 6.5, Rarity = "Rare", Price = 4000, Color = Color3.fromRGB(255, 230, 60), Icon = "rbxassetid://98827391711336" },
	{ Id = 7, ZhName = "翡翠之臂", Mult = 9, Rarity = "Epic", Price = 10000, Color = Color3.fromRGB(60, 220, 110), Icon = "rbxassetid://104373057742300" },
	{ Id = 8, ZhName = "紫晶之臂", Mult = 13, Rarity = "Epic", Price = 40000, Color = Color3.fromRGB(170, 80, 255), Icon = "rbxassetid://116669000221342" },
	{ Id = 9, ZhName = "烈焰之臂", Mult = 18, Rarity = "Epic", Price = 150000, Color = Color3.fromRGB(255, 110, 30), Icon = "rbxassetid://125285035215604" },
	{ Id = 10, ZhName = "深渊之臂", Mult = 25, Rarity = "Epic", Price = 600000, Color = Color3.fromRGB(200, 30, 60), Icon = "rbxassetid://82645023916736" },
	{ Id = 11, ZhName = "神圣之臂", Mult = 40, Rarity = "Legendary", Robux = 249, ProductKey = "HolyArm", Color = Color3.fromRGB(255, 215, 90), Icon = "rbxassetid://75627413068113" },
	{ Id = 12, ZhName = "审判之臂", Mult = 60, Rarity = "Legendary", Robux = 399, ProductKey = "JudgementArm", Limited = 250, Color = Color3.fromRGB(30, 30, 40), Icon = "rbxassetid://106638998049834" },
}

-- 外观由哑铃模板改色：PlateColor/PlateMat 作用于杠铃片，PlateScale 放大杠铃片截面，HandleColor 作用于握把
local _DUMBBELLS = {
	{ Id = 1, ZhName = "训练哑铃", Mult = 1, Rarity = "Common", Price = 0, PlateColor = Color3.fromRGB(35, 35, 40), PlateMat = "Metal", PlateScale = 1, HandleColor = Color3.fromRGB(190, 190, 200), Icon = "rbxassetid://79149397540649" },
	{ Id = 2, ZhName = "铁片哑铃", Mult = 1.3, Rarity = "Common", Price = 150, PlateColor = Color3.fromRGB(110, 110, 120), PlateMat = "DiamondPlate", PlateScale = 1.05, HandleColor = Color3.fromRGB(190, 190, 200), Icon = "rbxassetid://108608298227670" },
	{ Id = 3, ZhName = "青铜哑铃", Mult = 1.7, Rarity = "Uncommon", Price = 600, PlateColor = Color3.fromRGB(205, 127, 50), PlateMat = "Metal", PlateScale = 1.1, HandleColor = Color3.fromRGB(150, 95, 45), Icon = "rbxassetid://91634863308487" },
	{ Id = 4, ZhName = "白银哑铃", Mult = 2.2, Rarity = "Uncommon", Price = 2000, PlateColor = Color3.fromRGB(215, 220, 230), PlateMat = "Metal", PlateScale = 1.15, HandleColor = Color3.fromRGB(160, 165, 175), Icon = "rbxassetid://83444554423906" },
	{ Id = 5, ZhName = "黄金哑铃", Mult = 3, Rarity = "Rare", Price = 7000, PlateColor = Color3.fromRGB(255, 200, 40), PlateMat = "Metal", PlateScale = 1.2, HandleColor = Color3.fromRGB(200, 150, 30), Icon = "rbxassetid://134229591004130" },
	{ Id = 6, ZhName = "冰晶哑铃", Mult = 4, Rarity = "Rare", Price = 25000, PlateColor = Color3.fromRGB(120, 210, 255), PlateMat = "Ice", PlateScale = 1.25, HandleColor = Color3.fromRGB(210, 240, 255), Icon = "rbxassetid://94366573381853" },
	{ Id = 7, ZhName = "翡翠哑铃", Mult = 5.5, Rarity = "Epic", Price = 90000, PlateColor = Color3.fromRGB(40, 210, 110), PlateMat = "Glass", PlateScale = 1.3, HandleColor = Color3.fromRGB(30, 120, 70), Icon = "rbxassetid://119581829333036" },
	{ Id = 8, ZhName = "紫晶哑铃", Mult = 7.5, Rarity = "Epic", Price = 350000, PlateColor = Color3.fromRGB(170, 80, 255), PlateMat = "Glass", PlateScale = 1.35, HandleColor = Color3.fromRGB(90, 40, 140), Icon = "rbxassetid://99369701283844" },
	{ Id = 9, ZhName = "熔岩哑铃", Mult = 10, Rarity = "Epic", Price = 1200000, PlateColor = Color3.fromRGB(255, 100, 30), PlateMat = "CrackedLava", PlateScale = 1.4, HandleColor = Color3.fromRGB(60, 40, 40), Icon = "rbxassetid://108797683466319" },
	{ Id = 10, ZhName = "钻石哑铃", Mult = 14, Rarity = "Epic", Price = 5000000, PlateColor = Color3.fromRGB(120, 240, 255), PlateMat = "Neon", PlateScale = 1.5, HandleColor = Color3.fromRGB(230, 250, 255), Icon = "rbxassetid://104387525439155" },
}

local _TRAIN_SPEED = {
	{ Value = 1 },
	{ Value = 0.8, Price = 50, Level = 1 },
	{ Value = 0.6, Price = 500, Level = 2 },
	{ Value = 0.45, Price = 6000, Level = 3 },
	{ Value = 0.35, Price = 80000, Level = 4 },
	{ Value = 0.25, Price = 900000, Level = 5 },
}

local _WALK_SPEED = {
	{ Value = 16 },
	{ Value = 20, Price = 150, Level = 1 },
	{ Value = 24, Price = 1500, Level = 2 },
	{ Value = 28, Price = 20000, Level = 3 },
	{ Value = 32, Price = 250000, Level = 4 },
	{ Value = 36, Price = 2000000, Level = 5 },
}

local _LEVELS = {
	{
		ZhName = "青草公园",
		Theme = "Grass",
		Gate = 0,
		Ground = { Mat = "Grass", Color = Color3.fromRGB(100, 175, 70) },
		Opponents = {
			{ Id = "L1_1", ZhName = "稻草人", Model = "Scarecrow", Power = 5, Reward = 25, Scale = 1 },
			{ Id = "L1_2", ZhName = "木头人", Model = "Wooden", Power = 15, Reward = 60, Scale = 1.1 },
			{ Id = "L1_3", ZhName = "树桩怪", Model = "Stump", Power = 40, Reward = 150, Scale = 1.25 },
		},
		Machine = { Mode = "Offer", ZhName = "材质木箱", Pool = { "Sand", "Wood", "Grass" } },
	},
	{
		ZhName = "岩石峡谷",
		Theme = "Stone",
		Gate = 60,
		Ground = { Mat = "Slate", Color = Color3.fromRGB(120, 125, 140) },
		Opponents = {
			{ Id = "L2_1", ZhName = "小石怪", Model = "Rock", Power = 120, Reward = 400, Scale = 0.9 },
			{ Id = "L2_2", ZhName = "石头人", Model = "Rock", Power = 300, Reward = 900, Scale = 1.15 },
			{ Id = "L2_3", ZhName = "岩石巨人", Model = "Rock", Power = 700, Reward = 2000, Scale = 1.45 },
		},
		Machine = { Mode = "Gacha", ZhName = "岩石石箱", Price = 500, Pool = { "Wood", "Grass", "Snow", "Rock" } },
	},
	{
		ZhName = "炙热沙漠",
		Theme = "Desert",
		Gate = 800,
		Ground = { Mat = "Sand", Color = Color3.fromRGB(225, 200, 140) },
		Opponents = {
			{ Id = "L3_1", ZhName = "小仙人掌", Model = "Cactus", Power = 2000, Reward = 5000, Scale = 0.9 },
			{ Id = "L3_2", ZhName = "仙人掌战士", Model = "Cactus", Power = 5000, Reward = 12000, Scale = 1.15 },
			{ Id = "L3_3", ZhName = "仙人掌之王", Model = "CactusKing", Power = 12000, Reward = 28000, Scale = 1.4 },
		},
		Machine = { Mode = "Gacha", ZhName = "沙漠宝箱", Price = 5000, Pool = { "Snow", "Rock", "Metal", "Water" } },
	},
	{
		ZhName = "冰雪山地",
		Theme = "Snow",
		Gate = 15000,
		Ground = { Mat = "Snow", Color = Color3.fromRGB(235, 242, 250) },
		Opponents = {
			{ Id = "L4_1", ZhName = "小雪人", Model = "Snowman", Power = 35000, Reward = 60000, Scale = 0.9 },
			{ Id = "L4_2", ZhName = "大雪人", Model = "Snowman", Power = 90000, Reward = 140000, Scale = 1.2 },
			{ Id = "L4_3", ZhName = "雪怪", Model = "Yeti", Power = 220000, Reward = 320000, Scale = 1.4 },
		},
		Machine = { Mode = "Gacha", ZhName = "冰晶宝箱", Price = 50000, Pool = { "Metal", "Water", "Brick", "Magma" } },
	},
	{
		ZhName = "熔岩火山",
		Theme = "Lava",
		Gate = 250000,
		Ground = { Mat = "Basalt", Color = Color3.fromRGB(55, 45, 45) },
		Opponents = {
			{ Id = "L5_1", ZhName = "熔岩小鬼", Model = "Lava", Power = 600000, Reward = 700000, Scale = 0.9 },
			{ Id = "L5_2", ZhName = "熔岩巨人", Model = "Lava", Power = 1500000, Reward = 1600000, Scale = 1.2 },
			{ Id = "L5_3", ZhName = "火山之王", Model = "LavaKing", Power = 4000000, Reward = 4000000, Scale = 1.5 },
		},
		Machine = { Mode = "Gacha", ZhName = "熔岩宝箱", Price = 2000000, Pool = { "Brick", "Magma", "Neon", "Diamond" } },
	},
}

local _GAME_PASSES = {
	AutoClicker = { Id = 2038322520, ZhName = "自动点击", ZhDes = "训练和扳手腕自动点击", Robux = 99 },
	DoubleStrength = { Id = 2036996538, ZhName = "2 倍力量", ZhDes = "永久获得双倍力量", Robux = 149 },
	DoubleCash = { Id = 2040056271, ZhName = "2 倍金钱", ZhDes = "永久获得双倍金钱", Robux = 129 },
}

local _PRODUCTS = {
	CashSmall = { Id = 3718674363, ZhName = "一沓现金", ZhDes = "当前关卡 10 倍奖励", Robux = 25, Kind = "Cash", Amount = 10 },
	CashMedium = { Id = 3718674369, ZhName = "一箱现金", ZhDes = "当前关卡 40 倍奖励", Robux = 79, Kind = "Cash", Amount = 40 },
	CashLarge = { Id = 3718674377, ZhName = "金库", ZhDes = "当前关卡 150 倍奖励", Robux = 199, Kind = "Cash", Amount = 150 },
	StrengthSmall = { Id = 3718674386, ZhName = "蛋白粉", ZhDes = "立即获得 300 次训练的力量", Robux = 49, Kind = "Strength", Amount = 300 },
	StrengthLarge = { Id = 3718674391, ZhName = "超级蛋白粉", ZhDes = "立即获得 1500 次训练的力量", Robux = 149, Kind = "Strength", Amount = 1500 },
	HolyArm = { Id = 0, ZhName = "神圣之臂", ZhDes = "40 倍力量手臂", Robux = 249, Kind = "Arm", ArmId = 11 },
	JudgementArm = { Id = 0, ZhName = "审判之臂 (限量)", ZhDes = "60 倍力量，全服限量 250 个", Robux = 399, Kind = "Arm", ArmId = 12 },
	ArcaneMaterial = { Id = 0, ZhName = "奥术材质", ZhDes = "100 倍力量材质", Robux = 499, Kind = "Material", MatId = "Arcane" },
	-- 力量倍数档：替换式（当前档 Mult 即总倍数），须按 Tier 顺序展示；存档 ArmWrestle.StrengthTier
	StrengthTier1 = { Id = 3718674398, ZhName = "力量倍数", Robux = 19, Kind = "StrengthTier", Tier = 1, Mult = 2 },
	StrengthTier2 = { Id = 3718674403, ZhName = "力量倍数", Robux = 49, Kind = "StrengthTier", Tier = 2, Mult = 4 },
	StrengthTier3 = { Id = 3718674406, ZhName = "力量倍数", Robux = 99, Kind = "StrengthTier", Tier = 3, Mult = 8 },
	StrengthTier4 = { Id = 3718674408, ZhName = "力量倍数", Robux = 199, Kind = "StrengthTier", Tier = 4, Mult = 16 },
	StrengthTier5 = { Id = 3718674416, ZhName = "力量倍数", Robux = 399, Kind = "StrengthTier", Tier = 5, Mult = 32 },
	StrengthTier6 = { Id = 3718674420, ZhName = "力量倍数", Robux = 799, Kind = "StrengthTier", Tier = 6, Mult = 64 },
	-- 力量包：每次训练力量 × Amount，随进度增长
	StrengthPack1 = { Id = 3718674421, ZhName = "力量包", Robux = 19, Kind = "Strength", Amount = 200 },
	StrengthPack2 = { Id = 3718674424, ZhName = "力量包", Robux = 99, Kind = "Strength", Amount = 2000 },
	StrengthPack3 = { Id = 3718674429, ZhName = "力量包", Robux = 299, Kind = "Strength", Amount = 20000 },
	-- 药水：发货只把 _POTIONS[PotionKey].ItemId 加进背包，使用另走 UsePotion；键与 _POTIONS 一致
	StrengthPotion = { Id = 3718674436, ZhName = "力量药水", Robux = 49, Kind = "Potion", PotionKey = "StrengthPotion", Count = 1 },
	TrainSpeedPotion = { Id = 3718674437, ZhName = "训练速度药水", Robux = 49, Kind = "Potion", PotionKey = "TrainSpeedPotion", Count = 1 },
	CashPotion = { Id = 3718674438, ZhName = "金币药水", Robux = 49, Kind = "Potion", PotionKey = "CashPotion", Count = 1 },
}

-- 药水：Effect 为生效维度（Strength 每次训练力量 / TrainSpeed 训练频率 / Cash 对局金币），Duration 为单瓶在线秒数，Icon 为 ArmWrestleStyle.Icons 的键
-- ItemId 为背包物品 Id（itemdataConf），须与表中 UseScript = ArmWrestlePotion、parms = 本键 的行一一对应
local _POTIONS = {
	StrengthPotion = { ZhName = "力量药水", ZhDes = "力量药水描述", Effect = "Strength", Mult = 2, Duration = 900, ProductKey = "StrengthPotion", Icon = "potionStrength", ItemId = 201 },
	TrainSpeedPotion = { ZhName = "训练速度药水", ZhDes = "训练速度药水描述", Effect = "TrainSpeed", Mult = 2, Duration = 900, ProductKey = "TrainSpeedPotion", Icon = "potionTrainSpeed", ItemId = 202 },
	CashPotion = { ZhName = "金币药水", ZhDes = "金币药水描述", Effect = "Cash", Mult = 2, Duration = 900, ProductKey = "CashPotion", Icon = "potionCash", ItemId = 203 },
}

-- 可走真实收据发货的商品种类；Arm/Material 含限量库存与装备逻辑，收据路径未覆盖，不得加入
local _RECEIPT_KINDS = { Strength = true, StrengthTier = true, Cash = true, Potion = true }

local _STRENGTH_TIER_KEYS = { "StrengthTier1", "StrengthTier2", "StrengthTier3", "StrengthTier4", "StrengthTier5", "StrengthTier6" }

ArmWrestleConfig.GamePassOrder = { "AutoClicker", "DoubleStrength", "DoubleCash" }
ArmWrestleConfig.ProductOrder = { "CashSmall", "CashMedium", "CashLarge", "StrengthSmall", "StrengthLarge" }
-- 主界面右侧力量包，自上而下
ArmWrestleConfig.StrengthPackOrder = { "StrengthPack3", "StrengthPack2", "StrengthPack1" }
-- 商城：通行证区、力量区（从小到大）、药水区
ArmWrestleConfig.ShopPassOrder = { "DoubleStrength", "DoubleCash", "AutoClicker" }
ArmWrestleConfig.ShopPackOrder = { "StrengthPack1", "StrengthPack2", "StrengthPack3" }
ArmWrestleConfig.PotionOrder = { "StrengthPotion", "TrainSpeedPotion", "CashPotion" }

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
	@param id string - Common / Uncommon / Rare / Epic / Legendary / Mythic / Exclusive
	@return table? - 稀有度条目
]]
function ArmWrestleConfig.GetRarity(id: string): { [string]: any }?
	local row = _RARITIES[id]
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
	奖池概率（按条目 Weight；加成越高 Weight 越低 → Chance 越低）
	@param pool {string} - 材质 Id 列表
	@return {table} - { Id, Chance }；Chance 之和为 1
]]
function ArmWrestleConfig.PoolOdds(pool: { string }): { { Id: string, Chance: number } }
	local weights = table.create(#pool)
	local total = 0
	for i, id in ipairs(pool) do
		local mat = ArmWrestleConfig.GetMaterial(id)
		local rarity = mat and _RARITIES[mat.Rarity]
		local base = (mat and mat.Weight) or (rarity and rarity.Weight) or 1
		local weight = if type(base) == "number" and base > 0 then base else 0
		weights[i] = weight
		total += weight
	end
	local odds = table.create(#pool)
	for i, id in ipairs(pool) do
		odds[i] = { Id = id, Chance = if total > 0 then weights[i] / total else 0 }
	end
	return odds
end

--[[
	从奖池抽一个材质 Id
	@param pool {string} - 材质 Id
	@return string? - 抽中的 Id
]]
function ArmWrestleConfig.PickFromPool(pool: { string }): string?
	local odds = ArmWrestleConfig.PoolOdds(pool)
	if #odds == 0 then
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
