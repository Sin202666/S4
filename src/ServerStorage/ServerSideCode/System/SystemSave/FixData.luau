--[[
	Module: FixData
	Description: 玩家存档版本迁移（加载流程内执行，禁止写在业务 System.Init 中）
	Author: 林奥宇
	Created: 2026-07-03
	Last Modified: 2026-10-15

	功能：
	- 按 _SchemaVersion 依次执行一次性字段含义/结构迁移（v1 设置/技能，v2 扳手腕旧引导步骤 → Record 引导进度，
	  v3 扳手腕药水库存 ArmWrestle.Potions → 背包物品，并清掉已删配置的旧物品 11 宝物背包容量 / 101/102 幸运药水）
	- 由 SystemSave 在结构补全后、PlayerData 同步前调用

	调用关系：
	- SystemSave._setPlayerStat 加载会话后调用 FixData.Run(plr, playerStat)
	- 禁止在 SystemSet.Init 等业务 Init 中编写迁移逻辑

	示例：
	local FixData = require(script.FixData)
	FixData.Run(player, sessionData[playerId])
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemGameConfig = Utils.SystemGameConfig
local ArmWrestleConfig = Utils.ArmWrestleConfig
local CfgFind = Utils.CfgFind

-- ========================================
-- 模块定义
-- ========================================
local FixData = {}

-- ========================================
-- 常量定义
-- ========================================
local SETTING_KEY_BGM = "BGM"
local SETTING_KEY_EFFECT = "EFFECT"
local SETTING_KEY_SHAKE = "Shake"
local LEGACY_AUDIO_SCALE_KEYS = { SETTING_KEY_BGM, SETTING_KEY_EFFECT }
-- 旧框架主动样例 SkillDemoCast；槽 1 仍为该 ID 且配置默认已换时迁移
local LEGACY_ACTIVE_SAMPLE_SKILL_ID = 10000010
local SCHEMA_VERSION = 3
-- 配置已删除的旧物品 Id（11 宝物背包容量、101/102 幸运药水）；背包残留行查不到配置，迁移时直接清掉
local LEGACY_REMOVED_ITEM_IDS = { [11] = true, [101] = true, [102] = true }
-- 旧 ArmWrestle.Tutorial：1..10 为当前步骤，0 为全部完成；新进度为已完成阶段数，键对齐 SystemGuide
local LEGACY_TUTORIAL_STAGE_COUNT = 10
local GUIDE_RECORD_ARM_WRESTLE = "Guide_新手扳手腕"

-- ========================================
-- 私有函数
-- ========================================

--[[
	旧档 BGM/EFFECT 为 0~1 比例时升级为 0~100 整数（100 等同旧 1 档满音量）
	@param settingData table - 玩家 Setting 存档表，可原地修改
	@return nil - 无返回值
]]
local function _migrateLegacyAudioSettingScale(settingData: { [string]: any })
	if not settingData then
		return
	end
	for _, key in ipairs(LEGACY_AUDIO_SCALE_KEYS) do
		local val = settingData[key]
		if type(val) == "number" and val > 0 and val <= 1 then
			settingData[key] = math.clamp(math.floor(val * 100 + 0.5), 0, 100)
		end
	end
end

--[[
	旧档「屏幕震动」为开关 0/1 时升级为 0~100 强度滑条（1→100，0 保持）
	@param settingData table - 玩家 Setting 存档表，可原地修改
	@return nil - 无返回值
]]
local function _migrateLegacyShakeSettingScale(settingData: { [string]: any })
	if not settingData then
		return
	end
	local val = settingData[SETTING_KEY_SHAKE]
	if type(val) == "number" and val > 0 and val <= 1 then
		settingData[SETTING_KEY_SHAKE] = math.clamp(math.floor(val * 100 + 0.5), 0, 100)
	end
end

--[[
	主动槽 1 仍为旧样例 SkillDemoCast 时迁移到 GameConfig 默认主动技能1ID
	@param playerStat table - 会话存档，可原地修改
	@return nil - 无返回值
]]
local function _migrateLegacyActiveSampleSkill(playerStat: { [string]: any })
	local skills = playerStat.skills
	if type(skills) ~= "table" then
		return
	end
	local slot1 = skills[1]
	if type(slot1) ~= "table" then
		return
	end
	local curId = slot1.skillID or 0
	if curId ~= LEGACY_ACTIVE_SAMPLE_SKILL_ID then
		return
	end
	local defaultId = SystemGameConfig.GetValue({ "技能系统", "默认主动技能1ID" }) or 0
	if type(defaultId) ~= "number" or defaultId <= 0 or defaultId == LEGACY_ACTIVE_SAMPLE_SKILL_ID then
		return
	end
	slot1.skillID = defaultId
	slot1.Power = slot1.Power or 1
	slot1.purity = slot1.purity or 1
end

--[[
	旧档 ArmWrestle.Tutorial（当前步骤）迁到 Record 引导进度（已完成阶段数），并删除旧字段
	@param playerStat table - 会话存档，可原地修改
	@return nil - 无返回值
]]
local function _migrateArmWrestleTutorial(playerStat: { [string]: any })
	local armWrestle = playerStat.ArmWrestle
	if type(armWrestle) ~= "table" then
		return
	end
	local step = armWrestle.Tutorial
	armWrestle.Tutorial = nil
	if type(step) ~= "number" then
		return
	end
	local done = if step == 0 then LEGACY_TUTORIAL_STAGE_COUNT else math.clamp(math.floor(step) - 1, 0, LEGACY_TUTORIAL_STAGE_COUNT)
	if done <= 0 then
		return
	end
	if type(playerStat.Record) ~= "table" then
		playerStat.Record = {}
	end
	local record = playerStat.Record
	record[GUIDE_RECORD_ARM_WRESTLE] = math.max(tonumber(record[GUIDE_RECORD_ARM_WRESTLE]) or 0, done)
end

--[[
	往存档背包加可叠加物品（同 Id 已有行则累加，否则按 onlyID 递增新建行；行结构同 BagPlan）
	@param playerStat table - 会话存档，可原地修改（读写 Bag / onlyID）
	@param itemId number - 物品 Id，须在 itemdataConf 中
	@param count number - 正整数数量
	@return nil - 无返回值；配置缺失时跳过
]]
local function _addStackableBagItem(playerStat: { [string]: any }, itemId: number, count: number)
	local cfg = CfgFind.FindCfgByID(itemId)
	if type(cfg) ~= "table" then
		return
	end
	for _, row in pairs(playerStat.Bag) do
		if type(row) == "table" and row.id == itemId then
			row.count = (tonumber(row.count) or 0) + count
			return
		end
	end
	local onlyID = (tonumber(playerStat.onlyID) or 1) + 1
	playerStat.onlyID = onlyID
	playerStat.Bag[tostring(onlyID)] = { id = itemId, tp = cfg.tp, count = count, onlyID = onlyID }
end

--[[
	旧档 ArmWrestle.Potions（{ [药水键] = 瓶数 }）转成背包药水物品并删除旧字段；同时清掉已删配置的旧物品背包行（LEGACY_REMOVED_ITEM_IDS）
	@param playerStat table - 会话存档，可原地修改
	@return nil - 无返回值
]]
local function _migrateArmWrestlePotionsToBag(playerStat: { [string]: any })
	if type(playerStat.Bag) ~= "table" then
		return
	end
	for key, row in pairs(playerStat.Bag) do
		if type(row) == "table" and LEGACY_REMOVED_ITEM_IDS[tonumber(row.id) or 0] then
			playerStat.Bag[key] = nil
		end
	end
	local armWrestle = playerStat.ArmWrestle
	if type(armWrestle) ~= "table" then
		return
	end
	local potions = armWrestle.Potions
	armWrestle.Potions = nil
	if type(potions) ~= "table" then
		return
	end
	for _, key in ipairs(ArmWrestleConfig.PotionOrder) do
		local count = math.floor(tonumber(potions[key]) or 0)
		local potion = ArmWrestleConfig.GetPotion(key)
		if count > 0 and potion then
			_addStackableBagItem(playerStat, potion.ItemId, count)
		end
	end
end

-- ========================================
-- 公共 API
-- ========================================

--[[
	对玩家会话存档执行版本迁移
	@param plr Player - 玩家对象（预留扩展，当前迁移仅读写 playerStat）
	@param playerStat table - sessionData 中的存档表，可原地修改
	@return nil - 无返回值
]]
function FixData.Run(plr: Player, playerStat: any)
	if not playerStat then
		return
	end
	local version = playerStat._SchemaVersion or 0
	if version >= SCHEMA_VERSION then
		return
	end
	if version < 1 then
		_migrateLegacyAudioSettingScale(playerStat.Setting)
		_migrateLegacyShakeSettingScale(playerStat.Setting)
		_migrateLegacyActiveSampleSkill(playerStat)
	end
	if version < 2 then
		_migrateArmWrestleTutorial(playerStat)
	end
	if version < 3 then
		_migrateArmWrestlePotionsToBag(playerStat)
	end
	playerStat._SchemaVersion = SCHEMA_VERSION
end

return FixData
