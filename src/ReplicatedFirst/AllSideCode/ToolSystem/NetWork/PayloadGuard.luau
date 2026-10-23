--[[ Module: PayloadGuard | Description: 网络载荷大小和有限数检查 | Author: 林奥宇 ]]
local Guard = {}

-- 检查完整参数列表；无参/nil 合法，语义校验仍由各业务路由负责。
function Guard.Check(value)
	local seen, nodes, bytes = {}, 0, 0
	local function visit(item, depth)
		nodes += 1
		if nodes > 512 or depth > 8 then return false end
		local kind = typeof(item)
		if kind == "number" then return item == item and math.abs(item) < math.huge end
		if kind == "string" then bytes += #item; return #item <= 8192 and bytes <= 32768 end
		if kind == "nil" or kind == "boolean" or kind == "Instance" or kind == "EnumItem" then return true end
		if kind == "Vector3" then return visit(item.X, depth) and visit(item.Y, depth) and visit(item.Z, depth) end
		if kind == "Vector2" then return visit(item.X, depth) and visit(item.Y, depth) end
		if kind == "Color3" then return visit(item.R, depth) and visit(item.G, depth) and visit(item.B, depth) end
		if kind == "CFrame" then return visit({ item:GetComponents() }, depth + 1) end
		if kind ~= "table" or seen[item] then return false end
		seen[item] = true
		for key, child in pairs(item) do
			if (type(key) ~= "string" and type(key) ~= "number") or not visit(key, depth + 1) or not visit(child, depth + 1) then return false end
		end
		seen[item] = nil
		return true
	end
	return visit(value, 0)
end
return Guard
