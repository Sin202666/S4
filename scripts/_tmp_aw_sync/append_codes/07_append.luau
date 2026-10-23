local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[速度阶
	@return {table} - 阶列表
]]
function ArmWrestleConfig.GetTrainSpeed(): { { [string]: any } }
	return _clone(_TRAIN_SPEED)
end

--[[
	行走速度阶
	@return {table} - 阶列表
]]
function ArmWrestleConfig.GetWalkSpeed(): { { [string]: any } }
	return _clone(_WALK_SPEED)
end

--[[
	关卡表
	@return {table} - 关卡列表
]]
function ArmWrestleConfig.GetLevels(): { { [string]: any } }
	return _clone(_LEVELS)
end

--[[
	单关配置
	@param index number - 1-based 关卡下标
	@return table? - 关卡条目
]]
function ArmWrestleConfig.GetLevel(index: number): { [string]: any }?
	local row = _LEVELS[index]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按对手 Id 查找
	@param id string - 对手 Id
	@return table? - 对手条目
	@return number? - 关卡下标
]]
function ArmWrestleConfig.GetOpponent(id: string): ({ [string]: any }?, number?)
	if type(id) ~= "string" then
		return nil, nil
	end
	for levelIndex, level in ipairs(_LEVELS) do
		for _, opponent in ipairs(level.Opponents) do
			if opponent.Id == id then
				return _clone(opponent), levelIndex
			end
		end
	end
	return nil, nil
end

--[[
	通行证表（深拷贝）
	@return table - key → 配置
]]
function ArmWrestleConfig.GetGamePasses(): { [string]: any }
	return _clone(_GAME_PASSES)
end

--[[
	单条通行证
	@param key string - AutoClicker 等
	@return table? - 配置
]]
function ArmWrestleConfig.GetGamePass(key: string): { [string]: any }?
	local row = _GAME_PASSES[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按 Roblox GamePass Id 查通行证键（Id 为 0 的 Studio 占位不参与）
	@param passId number - GamePass 资产 Id
	@return string? - 通行证键（AutoClicker 等）；非本玩法通行证为 nil
]]
function ArmWrestleConfig.FindGamePassKey(passId: number): string?
	if type(passId) ~= "number" or passId <= 0 then
		return nil
	end
	for key, row in pairs(_GAME_PASSES) do
		if row.Id == passId then
			return key
		end
	end
	return nil
end

--[[
	单条药水配置
	@param key string - StrengthPotion / TrainSpeedPotion / CashPotion
	@return table? - { ZhName, ZhDes, Effect = "Strength" | "TrainSpeed" | "Cash", Mult, Duration(秒), ProductKey, Icon(ArmWrestleStyle.Icons 键), ItemId(背包物品 Id) }；未知键为 nil
]]
function ArmWrestleConfig.GetPotion(key: string): { [string]: any }?
	local row = _POTIONS[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	开发者商品表
	@return table - key → 配置
]]
function ArmWrestleConfig.GetProducts(): { [string]: any }
	return _clone(_PRODUCTS)
end

--[[
	单条商品
	@param key string - 商品键
	@return table? - 配置
]]
function ArmWrestleConfig.GetProduct(key: string): { [string]: any }?
	local row = _PRODUCTS[key]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按 Roblox 开发者商品 Id 查可走收据发货的商品键（Id 为 0 的 Studio 占位不参与）
	@param productId number - 收据 ProductId
	@return string? - 商品键；非本玩法商品或种类不支持收据发货时为 nil
]]
function ArmWrestleConfig.FindReceiptProductKey(productId: number): string?
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for key, row in pairs(_PRODUCTS) do
		if row.Id == productId and _RECEIPT_KINDS[row.Kind] then
			return key
		end
	end
	return]=]
return #m.Source
