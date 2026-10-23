--[[
	Module: BagUseItem
	Description: 消耗品使用与 UseScript 预加载
	Author: 林奥宇
	Created: 2026-06-30
	Last Modified: 2026-10-12
]]

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local SystemSave = Utils.SystemSave
local HttpService = Utils.HttpService
local EnumMgr = Utils.EnumMgr
local CfgFind = Utils.CfgFind
local ServerStorage = Utils.ServerStorage

local BagInventory = require(script.Parent.BagInventory)
local BagRemovePlan = require(script.Parent.BagRemovePlan)

-- ========================================
-- 模块定义
-- ========================================
local BagUseItem = {}

-- ========================================
-- 私有变量
-- ========================================
local _useScriptCache: { [string]: any } = {}

do
	local itemScriptFolder = ServerStorage.ServerSideCode.ItemScript
	for _, child in itemScriptFolder:GetChildren() do
		if child:IsA("ModuleScript") then
			_useScriptCache[child.Name] = require(child)
		end
	end
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	使用消耗品

	@param plr Player - 玩家对象
	@param onlyID number - 唯一 ID
	@param num number? - 使用数量，默认 1
	@return boolean, any? - 成功 true 与脚本结果；失败 false 与错误码。UseScript 须声明 Transactional=true，并返回 true,payload / false,error。
]]
function BagUseItem.UseItem(plr: Player, onlyID: number, num: number?)
	local useCount = num or 1
	if not BagRemovePlan.IsPositiveInteger(onlyID) or not BagRemovePlan.IsPositiveInteger(useCount) then
		return false, "INVALID_PARAM"
	end
	local result
	local ok, err = SystemSave.Transact(plr, "use:" .. HttpService:GenerateGUID(false), function(data)
		local row = data.Bag[tostring(onlyID)]
		if not row then return false, "NOT_FOUND" end
		local cfg = CfgFind.FindCfgByID(row.id, EnumMgr.ItemType.UseItem)
		local useScript = cfg and _useScriptCache[cfg.UseScript]
		-- 外部脚本必须明确遵守无 yield、所有持久修改走 SystemSave、表现走 AfterCommit 的契约。
		if not useScript or useScript.Transactional ~= true then return false, "USE_SCRIPT_NOT_TRANSACTIONAL" end
		local removed, removeErr = BagInventory.RemoveItem(plr, { row.id }, { useCount }, onlyID)
		if not removed then return false, removeErr end
		local accepted, payload = useScript.Use(plr, cfg.parms, useCount)
		if accepted ~= true then return false, payload or "USE_REJECTED" end
		result = payload
		return true
	end)
	if not ok then return false, err end
	return true, result
end

return BagUseItem
