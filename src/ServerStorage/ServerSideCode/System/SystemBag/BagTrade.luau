--[[
	Module: BagTrade
	Description: 背包物品锁定与交易扣除
	Author: 林奥宇
	Created: 2026-06-30
	Last Modified: 2026-10-12
]]

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local PlayerData = Utils.PlayerData
local SystemSave = Utils.SystemSave
local CfgFind = Utils.CfgFind
local Log = Utils.Log
local Copy = Utils.Copy
local EnumMgr = Utils.EnumMgr

local BagShared = require(script.Parent.BagShared)
local BagValueSync = require(script.Parent.BagValueSync)
local BagInventory = require(script.Parent.BagInventory)
local BagRemovePlan = require(script.Parent.BagRemovePlan)

-- ========================================
-- 模块定义
-- ========================================
local BagTrade = {}

-- ========================================
-- 公共函数
-- ========================================

--[[
	检查 onlyID 列表中的物品是否均可删除（未锁定且存在）

	@param plr Player - 玩家对象
	@param onlyIDVt {number} - 唯一 ID 列表
	@return boolean - 全部可删除时返回 true
]]
function BagTrade.CanRemove(plr: Player, onlyIDVt: { number }): boolean
	for _, onlyID in onlyIDVt do
		local data = BagInventory.GetItemByOnlyID(plr, onlyID)
		if data == nil then
			return false
		end
		if BagShared.isItemLocked(data) then
			return false
		end
	end

	return true
end

--[[
	交易扣除：按 onlyID 扣除数量并返回拷贝条目

	@param plr Player - 玩家对象
	@param onlyID number - 唯一 ID
	@param itemCount number - 扣除数量，须 > 0 且不超过持有
	@return boolean, table|string? - 成功 true 与条目拷贝 { id, tp, count, onlyID, lock? }；失败 false 与 errorCode
]]
function BagTrade.RemoveTradeItem(plr: Player, onlyID: number, itemCount: number): (boolean, any?)
	if not BagRemovePlan.IsPositiveInteger(onlyID) or not BagRemovePlan.IsPositiveInteger(itemCount) then return false, "INVALID_PARAM" end
	return SystemSave.Mutate(plr, function(data)
		local row = data.Bag[tostring(onlyID)]
		if not row then return false, "NOT_FOUND" end
		local cfg = CfgFind.FindCfgByID(row.id)
		if not cfg or not cfg.isTrade or cfg.isTrade == EnumMgr.BagTrade.NotTradeable then return false, "NOT_TRADEABLE" end
		local transferred = Copy.deepCopy(row)
		transferred.count = itemCount
		local ok, err = BagInventory.RemoveItem(plr, {row.id}, {itemCount}, onlyID)
		if not ok then return false, err end
		return true, transferred
	end)
end

--[[
	批量设置物品锁定状态

	@param plr Player - 玩家对象
	@param onlyIDVt {number} - 唯一 ID 列表
	@param lockState boolean - 是否锁定
	@return boolean, string? - 成功 true；失败 false 与 INVALID_PLAYER / NO_BAG_DATA
]]
function BagTrade.LockItem(plr: Player, onlyIDVt: { number }, lockState: boolean): (boolean, string?)
	if type(onlyIDVt) ~= "table" or type(lockState) ~= "boolean" then return false, "INVALID_PARAM" end
	return SystemSave.Mutate(plr, function(data)
		local count = 0
		for index, onlyID in pairs(onlyIDVt) do
			if not BagRemovePlan.IsPositiveInteger(index) or index > #onlyIDVt or not BagRemovePlan.IsPositiveInteger(onlyID) then return false, "INVALID_PARAM" end
			local row = data.Bag[tostring(onlyID)]
			if not row then return false, "NOT_FOUND" end
			row.lock = BagShared.toLockValue(lockState)
			count += 1
		end
		if count ~= #onlyIDVt then return false, "INVALID_PARAM" end
		SystemSave.AfterCommit(plr, function() BagValueSync.update(plr) end)
		return true
	end)
end

return BagTrade
