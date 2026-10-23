--[[
	Module: SessionPolicy
	Description: 无引擎依赖的原子会话租约规则；只在 UpdateAsync transform 内调用
	Author: 林奥宇
]]
local Policy = {}
Policy.LEASE_SECONDS = 120

-- 判断是否可接档；兼容旧 IsInServer 心跳，但不覆盖仍活跃的旧服。
function Policy.CanAcquire(data, owner, now)
	if data == nil then return true end
	if type(data) ~= "table" then return false end
	local lease = data._Session
	if type(lease) == "table" then
		return lease.owner == owner or (type(lease.expires) == "number" and lease.expires <= now)
	end
	return data.IsInServer ~= 1 or (type(data.LastSaveTime) == "number" and data.LastSaveTime + Policy.LEASE_SECONDS <= now)
end

-- 保存必须仍持有未过期租约；失去所有权的旧服不能覆盖新服。
function Policy.CanWrite(data, owner, now)
	local lease = type(data) == "table" and data._Session
	return type(lease) == "table" and lease.owner == owner and lease.expires > now
end

return Policy
