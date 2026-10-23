local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= [=[ing
	n = math.max(tonumber(n) or 0, 0)
	local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }
	local i = 1
	-- 999.5 级别四舍五入后会变成 4 位整数，提前进位到下一个单位
	while n >= 999.5 and i < #suffixes do
		n /= 1000
		i += 1
	end
	if i == 1 then
		return tostring(math.floor(n + 0.5))
	end
	local fmt = if n >= 99.95 then "%.0f" elseif n >= 9.995 then "%.1f" else "%.2f"
	return string.format(fmt, n) .. suffixes[i]
end

--[[
	关卡原点
	@param levelIndex number - 1-based
	@return Vector3 - 原点
]]
function ArmWrestleConfig.ZoneOrigin(levelIndex: number): Vector3
	return Vector3.new((levelIndex - 1) * ArmWrestleConfig.ZoneLength, 0, 0)
end

--[[
	对局结束出场位姿：EXIT_ATTR 沿其朝向外推 EXIT_PUSH_STUDS，再水平转向桌子，方便玩家转身就能再次交互
	（服务端 Battle 出场写 HRP、客户端交还镜头时摆机位共用，保证两侧朝向一致）
	@param tableModel Model - 比赛桌（读 EXIT_ATTR，桌面中心读 Pivot 属性，缺省用模型 Pivot）
	@return CFrame? - 出场 HRP 位姿（面朝桌子）；桌子缺少 EXIT_ATTR 时为 nil
]]
function ArmWrestleConfig.GetExitCFrame(tableModel: Model): CFrame?
	local exitCf = tableModel:GetAttribute(ArmWrestleConfig.EXIT_ATTR)
	if typeof(exitCf) ~= "CFrame" then
		return nil
	end
	local pos = exitCf.Position + exitCf.LookVector * ArmWrestleConfig.EXIT_PUSH_STUDS
	local center = tableModel:GetAttribute("Pivot")
	if typeof(center) ~= "Vector3" then
		center = tableModel:GetPivot().Position
	end
	local look = Vector3.new(center.X, pos.Y, center.Z)
	if (look - pos).Magnitude < 1e-3 then
		return CFrame.new(pos) * exitCf.Rotation
	end
	return CFrame.lookAt(pos, look)
end

--[[
	基础行走速度（CMS 默认）
	@return number - 16
]]
function ArmWrestleConfig.GetBaseWalkSpeed(): number
	return _WALK_SPEED[1].Value
end

--[[
	查找哑铃 Tool 模板（ReplicatedStorage / TOOL_ASSET_PATH / TOOL_NAME）
	@return Tool? - 模板本体，调用方须 Clone 后使用、禁止直接修改；路径缺失或类型不是 Tool 时为 nil
]]
function ArmWrestleConfig.FindToolTemplate(): Tool?
	local node: Instance? = ReplicatedStorage
	for _, name in ipairs(ArmWrestleConfig.TOOL_ASSET_PATH) do
		node = node and node:FindFirstChild(name)
	end
	local template = node and node:FindFirstChild(ArmWrestleConfig.TOOL_NAME)
	if template and template:IsA("Tool") then
		return template
	end
	return nil
end

return ArmWrestleConfig
]=]
return #m.Source
