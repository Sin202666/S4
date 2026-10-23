local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[DoubleCash", "AutoClicker" }
ArmWrestleConfig.ShopPackOrder = { "StrengthPack1", "StrengthPack2", "StrengthPack3" }
ArmWrestleConfig.PotionOrder = { "StrengthPotion", "TrainSpeedPotion", "CashPotion" }

--[[
	默认存档子树（深拷贝后写入 SaveMetaData / 会话）
	@return table - ArmWrestle 可变副本
]]
function ArmWrestleConfig.GetDefaultProfile(): { [string]: any }
	return {
		Strength = 0,
		Cash = 0,
		Wins = 0,
		Unlocked = 1,
		TrainTier = 1,
		SpeedTier = 1,
		Arms = { ["1"] = true },
		Arm = 1,
		Mats = {},
		Mat = "",
		Dumbbells = { ["1"] = true },
		Dumbbell = 1,
		StrengthTier = 0,
		PotionLeft = {},
		LastOnline = 0,
		OfflinePending = 0,
		MenuGiftClaimed = false,
	}
end

--[[
	稀有度表深拷贝
	@param id string - Common / Uncommon / Rare / Epic / Legendary / Mythic / Exclusive
	@return table? - 稀有度条目
]]
function ArmWrestleConfig.GetRarity(id: string): { [string]: any }?
	local row = _RARITIES[id]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	材质表（深拷贝数组）
	@return {table} - 材质列表
]]
function ArmWrestleConfig.GetMaterials(): { { [string]: any } }
	return _clone(_MATERIALS)
end

--[[
	按 Id 取材质
	@param id string - 材质 Id
	@return table? - 材质条目
]]
function ArmWrestleConfig.GetMaterial(id: string): { [string]: any }?
	if type(id) ~= "string" or id == "" then
		return nil
	end
	for _, row in ipairs(_MATERIALS) do
		if row.Id == id then
			return _clone(row)
		end
	end
	return nil
end

--[[
	手臂表（深拷贝数组）
	@return {table} - 手臂列表
]]
function ArmWrestleConfig.GetArms(): { { [string]: any } }
	return _clone(_ARMS)
end

--[[
	按 Id 取手臂
	@param id number - 手臂 Id（1-12）
	@return table? - 手臂条目
]]
function ArmWrestleConfig.GetArm(id: number): { [string]: any }?
	local row = _ARMS[id]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	哑铃表（深拷贝数组）
	@return {table} - 哑铃列表 { Id, ZhName, Mult, Price, PlateColor, PlateMat, PlateScale, HandleColor }
]]
function ArmWrestleConfig.GetDumbbells(): { { [string]: any } }
	return _clone(_DUMBBELLS)
end

--[[
	按 Id 取哑铃
	@param id number - 哑铃 Id（1-10）；非数字或越界返回 nil
	@return table? - 哑铃条目
]]
function ArmWrestleConfig.GetDumbbell(id: number): { [string]: any }?
	if type(id) ~= "number" then
		return nil
	end
	local row = _DUMBBELLS[id]
	if not row then
		return nil
	end
	return _clone(row)
end

--[[
	按哑铃配置给模板克隆体改外观：名为 Handle 的部件改握把色，其余 BasePart 视为杠铃片（改色/材质/截面放大）
	只能作用于 FindToolTemplate() 的克隆体，禁止直接改模板
	@param root Instance - Tool 克隆体或由其拼出的展示 Model
	@param id number - 哑铃 Id；无效时不做修改
]]
function ArmWrestleConfig.ApplyDumbbellLook(root: Instance, id: number)
	local row = _DUMBBELLS[id]
	if not row then
		return
	end
	local material = (Enum.Material :: any)[row.PlateMat] or Enum.Material.Metal
	for _, part in ipairs(root:GetDescendants()) do
		if not part:IsA("BasePart") then
			continue
		end
		if part.Name == "Handle" then
			part.Color = row.HandleColor
		else
			part.Color = row.PlateColor
			part.Material = material
			local size = part.Size
			part.Size = Vector3.new(size.X, size.Y * row.PlateScale, size.Z * row.PlateScale)
		]=]
return #m.Source
