local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[ maxId
end

--[[
	从 awmaterialConf 组装材质数组（按 Mult 升序；OfferPrice/ProductKey 为 0/空则省略字段）
	@return {table} - 材质列表
]]
local function _loadMaterials(): { { [string]: any } }
	local conf = ConfigInstance.awmaterialConf or {}
	local list = {}
	for id, row in pairs(conf) do
		if type(row) == "table" and type(id) == "string" then
			local entry: { [string]: any } = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Rarity = row.Rarity,
				Weight = row.Weight,
				Mat = row.Mat,
				Color = _rgb(row.ColorR, row.ColorG, row.ColorB),
				Icon = row.Icon,
			}
			if type(row.OfferPrice) == "number" and row.OfferPrice > 0 then
				entry.OfferPrice = row.OfferPrice
			end
			if type(row.ProductKey) == "string" and row.ProductKey ~= "" then
				entry.ProductKey = row.ProductKey
			end
			table.insert(list, entry)
		end
	end
	table.sort(list, function(a, b)
		return (a.Mult or 0) < (b.Mult or 0)
	end)
	return list
end

--[[
	从 awarmConf 组装手臂稠密数组；Robux/Limited/ProductKey 仅在 >0 / 非空时写入（兼容 if arm.Robux）
	@return {table} - 手臂列表（下标=Id）
]]
local function _loadArms(): { { [string]: any } }
	local conf = ConfigInstance.awarmConf or {}
	local maxId = _maxNumericKey(conf)
	local list = table.create(maxId)
	for id = 1, maxId do
		local row = conf[id]
		if type(row) == "table" then
			local entry: { [string]: any } = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Rarity = row.Rarity,
				Price = row.Price or 0,
				Color = _rgb(row.ColorR, row.ColorG, row.ColorB),
				Icon = row.Icon,
			}
			if type(row.Robux) == "number" and row.Robux > 0 then
				entry.Robux = row.Robux
			end
			if type(row.ProductKey) == "string" and row.ProductKey ~= "" then
				entry.ProductKey = row.ProductKey
			end
			if type(row.Limited) == "number" and row.Limited > 0 then
				entry.Limited = row.Limited
			end
			list[id] = entry
		end
	end
	return list
end

--[[
	从 awdumbbellConf 组装哑铃稠密数组
	@return {table} - 哑铃列表（下标=Id）
]]
local function _loadDumbbells(): { { [string]: any } }
	local conf = ConfigInstance.awdumbbellConf or {}
	local maxId = _maxNumericKey(conf)
	local list = table.create(maxId)
	for id = 1, maxId do
		local row = conf[id]
		if type(row) == "table" then
			list[id] = {
				Id = id,
				ZhName = row.ZhName,
				Mult = row.Mult,
				Rarity = row.Rarity,
				Price = row.Price or 0,
				PlateColor = _rgb(row.PlateR, row.PlateG, row.PlateB),
				PlateMat = row.PlateMat,
				PlateScale = row.PlateScale,
				HandleColor = _rgb(row.HandleR, row.HandleG, row.HandleB),
				Icon = row.Icon,
			}
		end
	end
	return list
end

--[[
	从 awupgradeConf 按 Kind 组装阶数组；Level=0 为基础档（不写 Price/Level 字段，与旧表形状一致）
	@param kind string - TrainSpeed / WalkSpeed
	@return {table} - 阶列表（按 Level 升序）
]]
local function _loadUpgradeKind(kind: string): { { [string]: any } }
	local conf = ConfigInstance.awupgradeConf or {}
	local rows = {}
	for _, row in pairs(conf) do
		if type(row) == "table" and row.Kind == kind then
			table.insert(rows, row)
		end
	end
	table.sort(rows, function(a, ]=]
return #m.Source
