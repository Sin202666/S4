--[[
	Module: BagPipeline
	Description: 背包原子入包规划与统计提交
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
]]
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemSave, CfgFind = Utils.SystemSave, Utils.CfgFind
local SystemRecord = Utils.SystemRecord
local BagCapacity = Utils.GetData.BagCapacity
local BagValueSync = require(script.Parent.BagValueSync)
local BagPlan = require(script.Parent.BagPlan)
local BagPipeline = {}

-- 同一草稿写入 Bag 与 onlyID；事件只在外层事务提交后触发。
function BagPipeline.AddItems(plr, ids, counts, opts)
	if opts ~= nil and type(opts) ~= "table" then return false, "INVALID_PARAM" end
	local policy = opts and opts.capacity or BagCapacity.Capacity.None
	if not BagCapacity.HasCapacityPolicy(policy) then return false, "INVALID_PARAM" end
	return SystemSave.Mutate(plr, function(data)
		local ok, plan = BagPlan.Build(data.Bag, data.onlyID, ids, counts, CfgFind.FindCfgByID, BagCapacity.IsStackable)
		if not ok then return false, plan end
		if BagCapacity.WouldExceedBatch(data.Bag, plan.batch, policy) then return false, "BAG_FULL" end
		data.Bag, data.onlyID = plan.bag, plan.onlyId
		for _, item in ipairs(plan.batch) do
			local recorded, recordErr = SystemRecord.RecordGetBagItem(plr, item.id, item.count)
			if not recorded then return false, recordErr end
		end
		SystemSave.AfterCommit(plr, function()
			BagValueSync.update(plr)
		end)
		return true, plan.lastId, plan.created
	end)
end
return BagPipeline
