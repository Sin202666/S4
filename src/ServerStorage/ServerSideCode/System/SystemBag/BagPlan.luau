--[[ Module: BagPlan | Description: 纯函数批量入包规划 | Author: 林奥宇 ]]
local BagPlan = {}

-- 所有配置和数量先验证，返回新背包；失败不修改输入。
function BagPlan.Build(bag, onlyId, ids, counts, findConfig, isStackable)
	if type(bag) ~= "table" or type(ids) ~= "table" or type(counts) ~= "table" or #ids == 0 or #ids ~= #counts then
		return false, "INVALID_PARAM"
	end
	for _, array in ipairs({ ids, counts }) do
		local entries = 0
		for key in pairs(array) do
			if type(key) ~= "number" or key < 1 or key % 1 ~= 0 or key > #array then return false, "INVALID_PARAM" end
			entries += 1
		end
		if entries ~= #array then return false, "INVALID_PARAM" end
	end
	local batch, uniqueCount = {}, 0
	for index, id in ipairs(ids) do
		local count = counts[index]
		if type(id) ~= "number" or id ~= id or id <= 0 or id == math.huge or id % 1 ~= 0
			or type(count) ~= "number" or count ~= count or count <= 0 or count >= 2^53 or count % 1 ~= 0 then
			return false, "INVALID_PARAM"
		end
		local cfg = findConfig(id)
		if not cfg then return false, "INVALID_ITEM" end
		if not isStackable(cfg) then uniqueCount += count end
		if uniqueCount > 10000 then return false, "BATCH_TOO_LARGE" end
		table.insert(batch, { id = id, count = count, cfg = cfg })
	end
	local result = {}
	for key, row in pairs(bag) do result[key] = table.clone(row) end
	local nextId, lastId, created = onlyId or 1, nil, {}
	for _, item in ipairs(batch) do
		local existing
		if isStackable(item.cfg) then
			for _, row in pairs(result) do if row.id == item.id then existing = row; break end end
		end
		if existing then
			existing.count += item.count
			if existing.count >= 2^53 then return false, "COUNT_OVERFLOW" end
			lastId = existing.onlyID
		else
			local stack = isStackable(item.cfg)
			for _ = 1, if stack then 1 else item.count do
				nextId += 1
				if nextId >= 2^53 or result[tostring(nextId)] then return false, "INVALID_ONLY_ID" end
				result[tostring(nextId)] = { id = item.id, tp = item.cfg.tp, count = if stack then item.count else 1, onlyID = nextId }
				lastId = nextId
				table.insert(created, nextId)
			end
		end
	end
	return true, { bag = result, onlyId = nextId, lastId = lastId, created = created, batch = batch }
end
return BagPlan
