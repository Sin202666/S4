local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[ 秒便于测试
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

local _RARITIES = {
	Common = { ZhName = "普通", Color = Color3.fromRGB(170, 170, 170), Weight = 60, Rank = 1 },
	Uncommon = { ZhName = "优秀", Color = Color3.fromRGB(85, 220, 90), Weight = 30, Rank = 2 },
	Rare = { ZhName = "稀有", Color = Color3.fromRGB(70, 160, 255), Weight = 12, Rank = 3 },
	Epic = { ZhName = "史诗", Color = Color3.fromRGB(180, 90, 255), Weight = 5, Rank = 4 },
	Legendary = { ZhName = "传说", Color = Color3.fromRGB(255, 170, 30), Weight = 1.5, Rank = 5 },
	Mythic = { ZhName = "神话", Color = Color3.fromRGB(255, 60, 80), Weight = 0.4, Rank = 6 },
	Exclusive = { ZhName = "专属", Color = Color3.fromRGB(255, 90, 220), Weight = 0, Rank = 7 },
}

local _MATERIALS = _loadMaterials()
local _ARMS = _loadArms()
local _DUMBBELLS = _loadDumbbells()
local _TRAIN_SPEED = _loadUpgradeKind("TrainSpeed")
local _WALK_SPEED = _loadUpgradeKind("WalkSpeed")
local _LEVELS = _loadLevels()

local _GAME_PASSES = {
	AutoClicker = { Id = 2038322520, ZhName = "自动点击", ZhDes = "训练和扳手腕自动点击", Robux = 99 },
	DoubleStrength = { Id = 2036996538, ZhName = "2 倍力量", ZhDes = "永久获得双倍力量", Robux = 149 },
	DoubleCash = { Id = 2040056271, ZhName = "2 倍金钱", ZhDes = "永久获得双倍金钱", Robux = 129 },
}

local _PRODUCTS = {
	HolyArm = { Id = 0, ZhName = "神圣之臂", ZhDes = "40 倍力量手臂", Robux = 249, Kind = "Arm", ArmId = 11 },
	JudgementArm = { Id = 0, ZhName = "审判之臂 (限量)", ZhDes = "60 倍力量，全服限量]=]
return #m.Source
