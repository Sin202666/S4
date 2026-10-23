--[[
	Module: ValueGuard
	Description: 存储值结构与 JSON 字节保守上界校验；为租约、账本等元数据保留空间
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
]]
local ValueGuard = {}
ValueGuard.MAX_BYTES = 3800000

--[[ 估算 JSON 字符串大小；控制符按六字节转义保守计数。
	@param value string - UTF-8 字符串
	@return number? - 字节上界，非法 UTF-8 为 nil
]]
local function stringBytes(value)
	if utf8.len(value) == nil then return nil end
	local _, escaped = string.gsub(value, '[%z\1-\31\\"]', "")
	return #value + escaped * 5 + 2
end

--[[ 校验并估算序列化大小，不接受循环、引擎对象、稀疏或混合数组。
	@param value any - 待存储值
	@param limit number? - 上限字节，默认 MAX_BYTES
	@return boolean, string?, number - 是否有效、错误码、大小上界
]]
function ValueGuard.Check(value, limit)
	local bytes, seen = 0, {}
	local function visit(node, depth)
		local kind = type(node)
		if kind == "string" then
			local size = stringBytes(node)
			if not size then return false end
			bytes += size
		elseif kind == "number" then
			if node ~= node or math.abs(node) == math.huge then return false end
			bytes += 32
		elseif kind == "boolean" or kind == "nil" then bytes += 5
		elseif kind == "table" then
			if seen[node] or depth > 16 then return false end
			seen[node] = true
			local numeric, strings, maximum = 0, 0, 0
			bytes += 2
			for key, child in pairs(node) do
				if type(key) == "number" and key > 0 and key < 2^53 and key % 1 == 0 then
					numeric += 1; maximum = math.max(maximum, key)
				elseif type(key) == "string" then
					local size = stringBytes(key)
					if not size then return false end
					strings += 1; bytes += size
				else return false end
				bytes += 2
				if not visit(child, depth + 1) then return false end
			end
			seen[node] = nil
			if numeric > 0 and (strings > 0 or maximum ~= numeric) then return false end
		else return false end
		return bytes <= (limit or ValueGuard.MAX_BYTES)
	end
	local ok = visit(value, 0)
	return ok, if ok then nil elseif bytes > (limit or ValueGuard.MAX_BYTES) then "VALUE_TOO_LARGE" else "UNSERIALIZABLE_VALUE", bytes
end

return ValueGuard
