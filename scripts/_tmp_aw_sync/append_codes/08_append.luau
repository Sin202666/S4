local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[ nil
end

--[[
	商品键是否允许走真实收据发货
	@param key string - 商品键
	@return boolean - Kind 属于 Strength / StrengthTier / Cash / Potion 时为 true
]]
function ArmWrestleConfig.IsReceiptProduct(key: string): boolean
	local row = _PRODUCTS[key]
	return row ~= nil and _RECEIPT_KINDS[row.Kind] == true
end

--[[
	力量倍数最高档
	@return number - 档数（当前 6，对应 x64）
]]
function ArmWrestleConfig.GetMaxStrengthTier(): number
	return #_STRENGTH_TIER_KEYS
end

--[[
	按档位取力量倍数商品
	@param tier number - 1..GetMaxStrengthTier()
	@return string? - 商品键（StrengthTier1 等）；越界为 nil
	@return table? - 商品配置深拷贝 { Id, ZhName, Robux, Kind = "StrengthTier", Tier, Mult }
]]
function ArmWrestleConfig.GetStrengthTierProduct(tier: number): (string?, { [string]: any }?)
	local key = _STRENGTH_TIER_KEYS[tier]
	if not key then
		return nil, nil
	end
	return key, _clone(_PRODUCTS[key])
end

--[[
	已购档位对应的力量总倍数（替换式，不与低档叠乘）
	@param tier number? - 存档 StrengthTier；nil / 0 / 非法为未购买
	@return number - 倍数；未购买为 1
]]
function ArmWrestleConfig.GetStrengthTierMult(tier: number?): number
	local key = if type(tier) == "number" then _STRENGTH_TIER_KEYS[math.min(tier, #_STRENGTH_TIER_KEYS)] else nil
	local row = key and _PRODUCTS[key]
	return if row then row.Mult else 1
end

--[[
	奖池概率（按条目 Weight；加成越高 Weight 越低 → Chance 越低）
	@param pool {string} - 材质 Id 列表
	@return {table} - { Id, Chance }；Chance 之和为 1
]]
function ArmWrestleConfig.PoolOdds(pool: { string }): { { Id: string, Chance: number } }
	local weights = table.create(#pool)
	local total = 0
	for i, id in ipairs(pool) do
		local mat = ArmWrestleConfig.GetMaterial(id)
		local rarity = mat and _RARITIES[mat.Rarity]
		local base = (mat and mat.Weight) or (rarity and rarity.Weight) or 1
		local weight = if type(base) == "number" and base > 0 then base else 0
		weights[i] = weight
		total += weight
	end
	local odds = table.create(#pool)
	for i, id in ipairs(pool) do
		odds[i] = { Id = id, Chance = if total > 0 then weights[i] / total else 0 }
	end
	return odds
end

--[[
	从奖池抽一个材质 Id
	@param pool {string} - 材质 Id
	@return string? - 抽中的 Id
]]
function ArmWrestleConfig.PickFromPool(pool: { string }): string?
	local odds = ArmWrestleConfig.PoolOdds(pool)
	if #odds == 0 then
		return nil
	end
	local roll = math.random()
	local acc = 0
	for _, row in ipairs(odds) do
		acc += row.Chance
		if roll <= acc then
			return row.Id
		end
	end
	return odds[#odds].Id
end

--[[
	数字缩写
	@param n number - 原值
	@return string - 展示串
]]
function ArmWrestleConfig.Format(n: number): string
	n = tonumber(n) or 0
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	while math.abs(n) >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		if n == math.floor(n) then
			return tostring(n)
		end
		return string.format("%.1f", n)
	end
	local s = string.format("%.2f", n):gsub("%.?0+$", "")
	return s .. suffixes[i]
end

--[[
	数字缩写，保留三位有效数字（1.00T / 10.0B / 100B），用于商品价签
	@param n number - 原值
	@return string - 展示串；小于 1000 取整
]]
function ArmWrestleConfig.FormatFixed(n: number): str]=]
return #m.Source
