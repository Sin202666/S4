--[[
	Module: SaveMetaData
	Description: SystemSave 玩家存档默认结构与 Value 暴露列表
	Author: 林奥宇
	Created: 2026-06-30
	Last Modified: 2026-10-15
]]

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Copy = Utils.Copy

-- ========================================
-- 模块定义
-- ========================================
local SaveMetaData = {}

-- ========================================
-- 常量定义
-- ========================================

-- 存档表内常用字段键名，与 PLAYER_META_DATA 字段保持一致
SaveMetaData.STAT_KEY = {
	IsInServer = "IsInServer",
	LastSaveTime = "LastSaveTime",
	LAST_VERSION = "LAST_VERSION",
}

-- 玩家默认存档结构；加载时用于结构补全，与重生初始化数据叠加
-- 只读模板，禁止外部直接修改；新建玩家请用 GetDefaultPlayerMeta()
local _PLAYER_META_DATA = {
	IsOldPlayer = 0,

	LastDailyTime = 0,
	NextDailyID = 1,
	DailyWeekID = 1,

	LastSaveTime = 0,
	IsInServer = 0,

	Email = {},
	-- 最近一次由 SystemSave 写入的游戏版本号；供 FixData / 排查，不参与会话互斥
	LAST_VERSION = "",
	GamePass = {},
	payData = {},
	GiftIntents = {},
	buff = {},
	onlyID = 1,
	Bag = {},
	Shop = {},
	Record = {},
	Achieve = {},
	Code = {},
	-- 在线奖励：持久轮次；RoundId / OnlineSeconds / [tierId]={ State=1已领 | Unlock=1付费可领 }；全领完重置
	OnlineBox = {},
	Setting = {},
	RedPoint = {},
	PityData = {},
	InputBindings = {},

	-- 技能槽（一期：skills 主动栏 + dashSkill 冲刺；普攻/格挡占位）
	skills = {},
	normalAtk = 0,
	dashSkill = 0,
	blockSkill = 0,

	-- 扳手腕玩法进度（力量/现金/装备）；礼物为会话态不落盘；新手引导进度在 Record["Guide_<引导键>"]
	ArmWrestle = {
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
		-- 已购力量倍数档（0 未购，1..6 对应 x2..x64，见 ArmWrestleConfig.StrengthTier*）
		StrengthTier = 0,
		-- 药水剩余在线秒数 { [药水键] = 秒 }，键见 ArmWrestleConfig.PotionOrder；药水库存是背包物品（Bag，ItemId 201~203）
		PotionLeft = {},
		-- 离线奖励：最后确认在线的服务器时间 os.time()（秒）与待领离线秒数（封顶 ArmWrestleConfig.OFFLINE_MAX_SEC）
		LastOnline = 0,
		OfflinePending = 0,
		-- 菜单挽留礼物是否已领（每账号一次，SystemArmWrestle.MenuGift）
		MenuGiftClaimed = false,
	},
}

SaveMetaData.PLAYER_META_DATA = _PLAYER_META_DATA

-- 需要同步到 Player 下 Value 实例的字段
SaveMetaData.PLAYER_VALUE_LIST = {
	{ "LastDailyTime", "NumberValue" },
	{ "NextDailyID", "NumberValue" },
	{ "DailyWeekID", "NumberValue" },
}

-- ========================================
-- 私有函数
-- ========================================

--[[
	递归冻结表及其嵌套表，防止外部改默认模板

	@param target any - 待冻结值；非 table 原样返回
	@return any - 冻结后的同一引用（非 table 则为原值）
]]
local function _deepFreeze(target: any): any
	if type(target) ~= "table" then
		return target
	end
	if table.isfrozen(target) then
		return target
	end
	for _, value in pairs(target) do
		if type(value) == "table" then
			_deepFreeze(value)
		end
	end
	return table.freeze(target)
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	获取玩家默认存档结构深拷贝

	@return table - 与 PLAYER_META_DATA 同形的可变副本（含 IsInServer、Bag、skills 等顶层键），可安全写入会话
]]
function SaveMetaData.GetDefaultPlayerMeta(): { [string]: any }
	return Copy.deepCopy(_PLAYER_META_DATA)
end

_deepFreeze(SaveMetaData.STAT_KEY)
_deepFreeze(_PLAYER_META_DATA)
_deepFreeze(SaveMetaData.PLAYER_VALUE_LIST)

return SaveMetaData
