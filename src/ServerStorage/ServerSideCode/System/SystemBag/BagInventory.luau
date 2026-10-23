--[[
	Module: BagInventory
	Description: 背包物品增删查核心逻辑（AddItems 走 BagPipeline；成功后 Toolbar 空槽自动上栏）
	Author: 林奥宇
	Created: 2026-06-30
	Last Modified: 2026-10-12
]]

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local SystemSave = Utils.SystemSave
local SystemRecord = Utils.SystemRecord
local CfgFind = Utils.CfgFind
local Log = Utils.Log
local Copy = Utils.Copy

local BagShared = require(script.Parent.BagShared)
local BagValueSync = require(script.Parent.BagValueSync)
local BagPipeline = require(script.Parent.BagPipeline)
local BagEquip = require(script.Parent.BagEquip)
local BagRemovePlan = require(script.Parent.BagRemovePlan)

-- ========================================
-- 模块定义
-- ========================================
local BagInventory = {}

-- ========================================
-- 公共函数
-- ========================================

--[[
	按唯一 ID 获取背包条目深拷贝（禁止返回存档活引用）

	@param plr Player - 玩家对象
	@param onlyID number - 唯一 ID
	@return table? - 条目深拷贝 { id, tp, count, onlyID, lock?, equip? }；不存在为 nil
]]
function BagInventory.GetItemByOnlyID(plr: Player, onlyID: number)
	if not BagShared.validatePlayer(plr) or not onlyID or onlyID == 0 then
		return nil
	end

	local bagData = BagShared.getBagData(plr)
	if not bagData then
		return nil
	end

	local row = bagData[tostring(onlyID)]
	if type(row) ~= "table" then
		return nil
	end
	return Copy.deepCopy(row)
end

--[[
	获取玩家拥有某物品的数量

	@param plr Player - 玩家对象
	@param itemID number - 物品 ID
	@return number - 数量
]]
function BagInventory.GetItemCountByID(plr: Player, itemID: number): number
	local numItemID = tonumber(itemID)
	if not numItemID or not BagShared.validatePlayer(plr) or numItemID == 0 then
		return 0
	end

	itemID = numItemID

	local bagData = BagShared.getBagData(plr)
	if not bagData then
		return 0
	end

	local cfg = CfgFind.FindCfgByID(itemID)
	if not cfg then
		Log.warn("没有这个物品的配置表:", itemID)
		return 0
	end

	local hasNum = 0
	for _, row in pairs(bagData) do
		if row.id == itemID and BagRemovePlan.IsPositiveInteger(row.count) then hasNum += row.count end
	end
	return hasNum
end

--[[
	直接写入完整背包条目数据（绕过 BagPipeline：不检满仓、不自动上栏）

	@param plr Player - 玩家对象
	@param itemData table - 条目数据 { id, tp?, count?, lock? }；onlyID 由本函数重新分配
	@return boolean, string? - 成功 true；失败 false 与 INVALID_PLAYER / INVALID_PARAM / NO_BAG_DATA
]]
function BagInventory.AddData(plr: Player, itemData): (boolean, string?)
	if not BagShared.validatePlayer(plr) then
		return false, BagShared.ERROR_INVALID_PLAYER
	end
	if type(itemData) ~= "table" then
		return false, BagShared.ERROR_INVALID_PARAM
	end

	if not BagRemovePlan.IsPositiveInteger(itemData.id) or not CfgFind.FindCfgByID(itemData.id)
		or not BagRemovePlan.IsPositiveInteger(itemData.count) then return false, "INVALID_ITEM" end
	return SystemSave.Mutate(plr, function(data)
		local newOnlyID = (data.onlyID or 1) + 1
		if not BagRemovePlan.IsPositiveInteger(newOnlyID) or data.Bag[tostring(newOnlyID)] then return false, "INVALID_ONLY_ID" end
		local itemCopy = Copy.deepCopy(itemData)
		itemCopy.onlyID = newOnlyID
		data.onlyID, data.Bag[tostring(newOnlyID)] = newOnlyID, itemCopy
		SystemSave.AfterCommit(plr, function() BagValueSync.update(plr) end)
		return true
	end)
end

--[[
	批量添加物品（可选容量策略；默认不检满仓，三参调用保持兼容）

	@param plr Player - 玩家对象
	@param itemIDVt {number} - 物品 ID 列表
	@param itemCountVt {number} - 对应数量列表
	@param opts { capacity: string? }? - 可选；capacity 为 GetData.BagCapacity.Capacity 键，默认 None
	@return boolean, number|string? - 成功 true 与最后写入的 onlyID；失败 false 与 INVALID_PLAYER / INVALID_PARAM / INVALID_ITEM / NO_BAG_DATA / BAG_FULL
]]
function BagInventory.AddItems(
	plr: Player,
	itemIDVt: { number },
	itemCountVt: { number },
	opts: { capacity: string? }?
): (boolean, number | string?)
	local ok, lastOrErr, newOnlyIds = BagPipeline.AddItems(plr, itemIDVt, itemCountVt, opts)
	if ok then
		SystemSave.AfterCommit(plr, function()
			BagEquip.TryAutoEquipNewItems(plr, newOnlyIds)
		end)
	end
	return ok, lastOrErr
end

--[[
	清空玩家背包中某物品 ID 的全部数量

	@param plr Player - 玩家对象
	@param itemID number - 物品 ID
	@return boolean, string? - 成功 true；失败 false 与 INVALID_PLAYER / NO_BAG_DATA / INVALID_ITEM
]]
function BagInventory.RemoveAllItem(plr: Player, itemID: number): (boolean, string?)
	return SystemSave.Mutate(plr, function(data)
		if not BagRemovePlan.IsPositiveInteger(itemID) or not CfgFind.FindCfgByID(itemID) then return false, "INVALID_ITEM" end
		local count = 0
		for _, row in pairs(data.Bag) do
			if row.id == itemID then
				if BagShared.isItemLocked(row) then return false, "ITEM_LOCKED" end
				count += row.count
			end
		end
		if count == 0 then return true end
		return BagInventory.RemoveItem(plr, { itemID }, { count })
	end)
end

--[[
	按唯一 ID 删除背包条目

	@param plr Player - 玩家对象
	@param onlyID number - 唯一 ID
	@param isIgnoreLock boolean? - 是否忽略锁定
	@return boolean, string? - 成功 true；失败 false 与 INVALID_PLAYER / NO_BAG_DATA / NOT_FOUND / ITEM_LOCKED
]]
function BagInventory.RemoveItemByOnlyID(plr: Player, onlyID: number, isIgnoreLock: boolean?): (boolean, string?)
	if not BagRemovePlan.IsPositiveInteger(onlyID) then return false, "INVALID_PARAM" end
	return SystemSave.Mutate(plr, function(data)
		local row = data.Bag[tostring(onlyID)]
		if not row then return false, "NOT_FOUND" end
		if BagShared.isItemLocked(row) and not isIgnoreLock then return false, "ITEM_LOCKED" end
		data.Bag[tostring(onlyID)] = nil
		local ok, err = SystemRecord.RecordDelBagItem(plr, row.id, row.count)
		if not ok then return false, err end
		SystemSave.AfterCommit(plr, function() BagValueSync.update(plr) end)
		return true
	end)
end

--[[
	批量扣除多种物品（先校验数量再扣除）

	@param plr Player - 玩家对象
	@param itemIDVt {number} - 物品 ID 列表
	@param itemCountVt {number} - 对应数量列表
	@param onlyID number? - 可选，限定扣除唯一条目
	@return boolean, string? - 成功 true；失败 false 与 INVALID_PARAM / INSUFFICIENT_COUNT / INVALID_ITEM
]]
function BagInventory.RemoveItem(plr: Player, itemIDVt: { number }, itemCountVt: { number }, onlyID: number?): (boolean, string?)
	return SystemSave.Mutate(plr, function(data)
		local ok, plan = BagRemovePlan.Build(data.Bag, itemIDVt, itemCountVt, CfgFind.FindCfgByID, BagShared.isItemLocked, onlyID)
		if not ok then return false, plan end
		data.Bag = plan.bag
		for _, item in ipairs(plan.batch) do
			local recorded, err = SystemRecord.RecordDelBagItem(plr, item.id, item.count)
			if not recorded then return false, err end
		end
		SystemSave.AfterCommit(plr, function() BagValueSync.update(plr) end)
		return true
	end)
end

return BagInventory
