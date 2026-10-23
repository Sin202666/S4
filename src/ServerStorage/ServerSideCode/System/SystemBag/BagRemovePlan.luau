--[[
	Module: BagRemovePlan
	Description: 扣除整批物品的纯规划；合并重复 ID、跳过锁定条目、失败不修改输入
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
]]
local BagRemovePlan = {}

--[[ 检查安全范围内的正整数。
	@param value any - 待校验值
	@return boolean - 是否为安全正整数
]]
function BagRemovePlan.IsPositiveInteger(value)
	return type(value) == "number" and value == value and value > 0 and value < 2^53 and value % 1 == 0
end

--[[ 基于快照生成整批扣除计划，不产生任何外部效果。
	@param bag table - 背包字典
	@param ids table - 密集物品 ID 数组
	@param counts table - 同长正整数数量数组
	@param findConfig function - 服务端配置查询
	@param isLocked function - 锁定检查
	@param onlyID number? - 指定唯一条目，仅供消费使用
	@return boolean, table|string - {bag, batch} 或错误码
]]
function BagRemovePlan.Build(bag, ids, counts, findConfig, isLocked, onlyID)
	if type(bag) ~= "table" or type(ids) ~= "table" or type(counts) ~= "table" or #ids == 0 or #ids ~= #counts or #ids > 1000 then
		return false, "INVALID_PARAM"
	end
	for _, array in ipairs({ ids, counts }) do
		local size = 0
		for key in pairs(array) do
			if not BagRemovePlan.IsPositiveInteger(key) or key > #array then return false, "INVALID_PARAM" end
			size += 1
		end
		if size ~= #array then return false, "INVALID_PARAM" end
	end
	if onlyID ~= nil and not BagRemovePlan.IsPositiveInteger(onlyID) then return false, "INVALID_PARAM" end
	local required = {}
	for index, id in ipairs(ids) do
		if not BagRemovePlan.IsPositiveInteger(id) or not BagRemovePlan.IsPositiveInteger(counts[index]) then return false, "INVALID_PARAM" end
		if not findConfig(id) then return false, "INVALID_ITEM" end
		required[id] = (required[id] or 0) + counts[index]
		if required[id] >= 2^53 then return false, "COUNT_OVERFLOW" end
	end
	local result, batch = table.clone(bag), {}
	for id, count in pairs(required) do
		local remaining = count
		for key, row in pairs(bag) do
			if row.id == id and (onlyID == nil or key == tostring(onlyID)) and not isLocked(row) then
				if not BagRemovePlan.IsPositiveInteger(row.count) then return false, "INVALID_ITEM_COUNT" end
				local taken = math.min(remaining, row.count)
				if taken > 0 then
					local changed = table.clone(row)
					changed.count -= taken
					result[key] = if changed.count == 0 then nil else changed
					remaining -= taken
				end
			end
			if remaining == 0 then break end
		end
		if remaining ~= 0 then return false, "INSUFFICIENT_COUNT" end
		table.insert(batch, { id = id, count = count })
	end
	return true, { bag = result, batch = batch }
end

return BagRemovePlan
