local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpAwSync"
	folder.Parent = game.ReplicatedStorage
end
local sub = folder:FindFirstChild("ArmWrestleConfig")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ArmWrestleConfig"
	sub.Parent = folder
end
local v = sub:FindFirstChild("3")
if not v then
	v = Instance.new("StringValue")
	v.Name = "3"
	v.Parent = sub
end
v.Value = [=[
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
	StrengthPotion = { ZhName = "力量药水", ZhDes = "力量药水描述", Effect = "Strength", Mult = 2, Duration]=]
return #v.Value
