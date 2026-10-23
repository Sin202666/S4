local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[, ZhDes = "60 倍力量，全服限量 250 个", Robux = 399, Kind = "Arm", ArmId = 12 },
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
-- 主界面右侧力量包，自上而下
ArmWrestleConfig.StrengthPackOrder = { "StrengthPack3", "StrengthPack2", "StrengthPack1" }
-- 商城：通行证区、力量区（从小到大）、药水区
ArmWrestleConfig.ShopPassOrder = { "DoubleStrength", "]=]
return #m.Source
