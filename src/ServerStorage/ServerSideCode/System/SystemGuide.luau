--[[
	Module: SystemGuide
	Description: 新手引导服务端：按 GameConfig「引导」判定阶段完成、记录进度、向客户端发布当前阶段
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	功能：
	- 阶段完成只由服务端判定：业务结算后调 Evaluate，用状态快照与结算事件匹配阶段 Done，满足即推进（一次可连跳多阶段）
	- 进度存 Record["Guide_<引导键>"] = 已完成阶段数，经 SystemRecord.RecordCover 落档
	- 当前阶段以玩家 Attribute（EnumMgr.PlayerAttr.GuideName）发布为 "引导键|阶段序号"，阶段前置未满足时为 "引导键|阶段序号|Pre"，全部完成或无可进行引导为 ""
	- 不提供客户端上报完成的 Remote：客户端只读 GuideName 做表现，不能推进或跳过引导

	配置（GameConfig「引导」.Cfg[引导键]，字段详见 GameConfig 注释）：
	- Order 排序；Stages 阶段数组；Check 前置条件（全部满足）；SkipWhenCheckFails 前置不满足时跳过；ReStart 入服重来
	- 条件 { 字段, 门槛 }：快照字段 >= 门槛；{ "Event", 事件名, 参数? }：本次 Evaluate 的事件匹配（参数缺省时只比事件名）
	- 一次 Evaluate 的事件最多完成一个阶段，避免一场胜利连跳多个「赢 X」阶段
	- 阶段 Pre.Need（全部满足）只影响表现：先判 Done（已完成照常推进），未完成且 Pre.Need 不满足时发布 Pre 变体

	与相关模块：
	- 状态快照由业务模块构造并传入（当前为 SystemArmWrestle：Strength / Wins / TrainTier / Unlocked / ArmCount / MatCount / Coin / Can* 0/1 前置字段），本模块不读业务存档
	- 进度读写只经 SystemRecord；版本迁移（旧 ArmWrestle.Tutorial → Record）在 FixData v2
	- 客户端 SystemGuide（ClientSideCode.SystemModule）解析 GuideName 显示箭头 / 引导线 / 高光；主界面已无引导文案框

	加载（仅服务端）：
		local SystemGuide = Utils.SystemGuide
		SystemGuide.SetupPlayer(player, state)          -- 入服：处理 ReStart 并发布首个阶段
		SystemGuide.Evaluate(player, state)             -- 业务状态变化后
		SystemGuide.Evaluate(player, state, "win", "L1_3") -- 带结算事件
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemGameConfig = Utils.SystemGameConfig
local SystemRecord = Utils.SystemRecord
local EnumMgr = Utils.EnumMgr
local Log = Utils.Log

local SystemGuide = {}

-- ========================================
-- 常量定义
-- ========================================
local RECORD_PREFIX = "Guide_"
local EVENT_KEY = "Event"
local NAME_SEPARATOR = "|"
local PRE_SUFFIX = "Pre"
local GUIDE_NAME_ATTR = EnumMgr.PlayerAttr.GuideName

type Condition = { any }
type GuideDef = {
	key: string,
	order: number,
	stages: { { [string]: any } },
	check: { Condition }?,
	skipWhenCheckFails: boolean,
	reStart: boolean,
}

-- ========================================
-- 私有变量
-- ========================================
local _guides: { GuideDef }? = nil

-- ========================================
-- 私有函数
-- ========================================

--[[
	是否在线有效玩家
	@param plr any - 待校验对象
	@return boolean - 仍在服务器内的 Player 为 true
]]
local function _isPlayer(plr: any): boolean
	return typeof(plr) == "Instance" and plr:IsA("Player") and plr.Parent ~= nil
end

--[[
	按 Order（同序按引导键）排好的引导列表；首次调用时从 GameConfig 读取
	@return {GuideDef} - 有阶段的引导，按进行顺序排列
]]
local function _getGuides(): { GuideDef }
	if _guides then
		return _guides
	end
	local list: { GuideDef } = {}
	local cfg = SystemGameConfig.GetValue({ "引导", "Cfg" })
	if type(cfg) == "table" then
		for key, def in pairs(cfg) do
			if type(def) == "table" and type(def.Stages) == "table" and #def.Stages > 0 then
				table.insert(list, {
					key = tostring(key),
					order = tonumber(def.Order) or math.huge,
					stages = def.Stages,
					check = if type(def.Check) == "table" then def.Check else nil,
					skipWhenCheckFails = def.SkipWhenCheckFails == true,
					reStart = def.ReStart == true,
				})
			end
		end
	else
		Log.warn("SystemGuide：GameConfig 缺少「引导.Cfg」")
	end
	table.sort(list, function(a, b)
		if a.order ~= b.order then
			return a.order < b.order
		end
		return a.key < b.key
	end)
	_guides = list
	return list
end

--[[
	单个条件是否满足
	@param cond any - { 字段, 门槛 } 或 { "Event", 事件名, 参数? }
	@param state table - 状态快照 { [字段]: number }
	@param event string? - 本次结算事件名；nil 表示无事件
	@param arg any? - 事件参数（如对手 Id）
	@return boolean - 满足为 true；格式非法为 false
]]
local function _matchCondition(cond: any, state: { [string]: number }, event: string?, arg: any?): boolean
	if type(cond) ~= "table" then
		return false
	end
	if cond[1] == EVENT_KEY then
		return event ~= nil and cond[2] == event and (cond[3] == nil or cond[3] == arg)
	end
	local value = state[cond[1]]
	local threshold = cond[2]
	return type(value) == "number" and type(threshold) == "number" and value >= threshold
end

--[[
	条件列表中是否有任一满足（阶段 Done 语义）
	@param conds any - 条件数组；非表视为永不满足
	@param state table - 状态快照
	@param event string? - 结算事件名
	@param arg any? - 事件参数
	@return boolean - 任一满足为 true
]]
local function _matchAny(conds: any, state: { [string]: number }, event: string?, arg: any?): boolean
	if type(conds) ~= "table" then
		return false
	end
	for _, cond in ipairs(conds) do
		if _matchCondition(cond, state, event, arg) then
			return true
		end
	end
	return false
end

--[[
	条件列表是否全部满足（引导 Check 语义；事件条件在此恒不满足）
	@param conds {Condition} - 条件数组
	@param state table - 状态快照
	@return boolean - 全部满足为 true
]]
local function _matchAll(conds: { Condition }, state: { [string]: number }): boolean
	for _, cond in ipairs(conds) do
		if not _matchCondition(cond, state, nil, nil) then
			return false
		end
	end
	return true
end

--[[
	读取某引导已完成阶段数
	@param plr Player - 玩家
	@param guide GuideDef - 引导
	@return number - 0 ~ 阶段总数
]]
local function _getProgress(plr: Player, guide: GuideDef): number
	local done = math.floor(SystemRecord.GetDataByID(plr, RECORD_PREFIX .. guide.key))
	return math.clamp(done, 0, #guide.stages)
end

--[[
	写入某引导已完成阶段数
	@param plr Player - 玩家
	@param guide GuideDef - 引导
	@param done number - 已完成阶段数
	@return boolean - 落档成功为 true
]]
local function _setProgress(plr: Player, guide: GuideDef, done: number): boolean
	local ok, err = SystemRecord.RecordCover(plr, RECORD_PREFIX .. guide.key, done)
	if not ok then
		Log.warn("SystemGuide 写进度失败", plr.UserId, guide.key, done, err)
	end
	return ok
end

--[[
	阶段前置是否未满足（阶段配了 Pre.Need 且其中有条件不满足）
	@param stage table - 阶段配置
	@param state table - 状态快照
	@return boolean - 前置未满足为 true；无前置为 false
]]
local function _isPreBlocked(stage: { [string]: any }, state: { [string]: number }): boolean
	local pre = stage.Pre
	if type(pre) ~= "table" or type(pre.Need) ~= "table" then
		return false
	end
	return not _matchAll(pre.Need, state)
end

--[[
	发布当前阶段给客户端
	@param plr Player - 玩家
	@param key string? - 引导键；nil 表示无引导
	@param index number? - 阶段序号（从 1 开始）
	@param preBlocked boolean? - 阶段前置未满足时为 true，客户端改用 Pre 表现
]]
local function _publish(plr: Player, key: string?, index: number?, preBlocked: boolean?)
	local value = ""
	if key and index then
		value = key .. NAME_SEPARATOR .. tostring(index)
		if preBlocked then
			value ..= NAME_SEPARATOR .. PRE_SUFFIX
		end
	end
	if plr:GetAttribute(GUIDE_NAME_ATTR) ~= value then
		plr:SetAttribute(GUIDE_NAME_ATTR, value)
	end
end

-- ========================================
-- 公共 API
-- ========================================

--[[
	按状态快照与结算事件推进引导，并发布当前阶段；业务每次结算后调用（无变化时不写档）
	@param plr Player - 玩家；须在线且存档已加载
	@param state table - 状态快照 { [字段名]: number }，字段与 GameConfig「引导」条件一致（如 Strength / Wins）
	@param event string? - 结算事件名（如 "win"）；缺省表示仅按快照判定
	@param arg any? - 事件参数（如对手 Id "L1_3"）；与条件第 3 项比较
]]
function SystemGuide.Evaluate(plr: Player, state: { [string]: number }, event: string?, arg: any?)
	if not _isPlayer(plr) or type(state) ~= "table" then
		return
	end
	local pendingEvent = event
	for _, guide in ipairs(_getGuides()) do
		local total = #guide.stages
		local done = _getProgress(plr, guide)
		if done >= total then
			continue
		end
		if guide.check and not _matchAll(guide.check, state) then
			if guide.skipWhenCheckFails then
				continue
			end
			_publish(plr, nil, nil)
			return
		end
		local reached = done
		while reached < total and _matchAny(guide.stages[reached + 1].Done, state, pendingEvent, arg) do
			reached += 1
			pendingEvent = nil
		end
		if reached > done and not _setProgress(plr, guide, reached) then
			reached = done
		end
		if reached < total then
			_publish(plr, guide.key, reached + 1, _isPreBlocked(guide.stages[reached + 1], state))
			return
		end
	end
	_publish(plr, nil, nil)
end

--[[
	入服初始化：ReStart 引导未完成时清零进度，再按快照推进并发布当前阶段
	@param plr Player - 玩家；须在 SystemRecord.Init 之后、存档已加载
	@param state table - 状态快照，同 Evaluate
]]
function SystemGuide.SetupPlayer(plr: Player, state: { [string]: number })
	if not _isPlayer(plr) then
		return
	end
	for _, guide in ipairs(_getGuides()) do
		if guide.reStart then
			local done = _getProgress(plr, guide)
			if done > 0 and done < #guide.stages then
				_setProgress(plr, guide, 0)
			end
		end
	end
	SystemGuide.Evaluate(plr, state)
end

return SystemGuide
