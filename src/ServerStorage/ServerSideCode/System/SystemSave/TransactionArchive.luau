--[[
	Module: TransactionArchive
	Description: 将顶层事务账本分桶归档；先确认归档，再移除玩家档内标记。绝不按时间删除去重证据。
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
	由 SystemSave 在会话事务锁内调用。gamepass 等嵌套事务保留在主档，归档类型禁止嵌套。
]]
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Store = Utils.SystemDataStore
local TransactionArchive = {}
local PREFIXES = { receipt = true, mail = true, ["legacy-mail"] = true, use = true, ["gift-intent"] = true, ["gift-cancel"] = true, code = true, cdk = true, daily = true, online = true, reconcile = true }
local MIN_ENTRIES = 512

--[[ 判断是否为只允许顶层执行的归档事务。
	@param id string - 事务 ID
	@return boolean - 是否采用归档查询
]]
function TransactionArchive.IsArchivable(id)
	return PREFIXES[string.match(id, "^([^:]+):")] == true
end

--[[ 稳定分桶；存储键长度不受原始订单 ID 长度影响。
	@param id string - 事务 ID
	@return string - 0..63 桶号
]]
local function bucketFor(id)
	local hash = 0
	for index = 1, #id do hash = (hash * 33 + string.byte(id, index)) % 65536 end
	return tostring(hash % 64)
end

--[[ 会话最多缓存四个小桶；大桶只作本次查询，避免历史账本撑大服务器内存。
	@param session table - 会话
	@param bucket string - 桶号
	@param rows table - 已确认的归档内容
	@return nil - 无返回值
]]
local function cacheBucket(session, bucket, rows)
	session.archiveCache = session.archiveCache or {}
	if not Store.ValidateValue(rows, 65536) then session.archiveCache[bucket] = nil; return end
	local count = 0
	for _ in pairs(session.archiveCache) do count += 1 end
	if count >= 4 then table.clear(session.archiveCache) end
	session.archiveCache[bucket] = rows
end

--[[ 在授予奖励前读取去重证据；读取失败必须拒绝发奖。
	@param session table - SystemSave 持有锁的会话
	@param id string - 事务 ID
	@return boolean, boolean|string - 查询成功与是否存在，或错误码
]]
function TransactionArchive.Contains(session, id)
	if not TransactionArchive.IsArchivable(id) then return true, false end
	local bucket = bucketFor(id)
	if not session.data._ArchiveBuckets or not session.data._ArchiveBuckets[bucket] then return true, false end
	session.archiveCache = session.archiveCache or {}
	local rows = session.archiveCache[bucket]
	if not rows then
		local ok, result = Store.Get(Store.STORE.TransactionArchive, session.key .. ":" .. bucket, { fresh = true })
		if not ok or type(result) ~= "table" then return false, "ARCHIVE_UNAVAILABLE" end
		rows = result
		cacheBucket(session, bucket, rows)
	end
	return true, rows[id] == true
end

--[[ 每轮最多归档一个桶，避免挤占租约续期预算；只能归档已确认的快照。
	@param session table - 无未确认写入且已上锁的会话
	@return boolean - 是否变更主档，需要再次保存
]]
function TransactionArchive.Compact(session)
	local groups, count = {}, 0
	for id in pairs(session.data._Transactions) do
		if TransactionArchive.IsArchivable(id) then
			local bucket = bucketFor(id)
			groups[bucket] = groups[bucket] or {}
			groups[bucket][id] = true
			count += 1
		end
	end
	if count <= MIN_ENTRIES then return false end
	local selected, largest = nil, 0
	for bucket, rows in pairs(groups) do
		local size = 0
		for _ in pairs(rows) do size += 1 end
		if size > largest then selected, largest = bucket, size end
	end
	local ok, merged = Store.Update(Store.STORE.TransactionArchive, session.key .. ":" .. selected, function(old)
		local rows = if type(old) == "table" then old else {}
		for id in pairs(groups[selected]) do rows[id] = true end
		return rows
	end)
	if not ok or type(merged) ~= "table" then return false end
	-- 归档内容先得到确认。此后宕机只可能保留重复标记，不会遗失去重证据。
	session.data._ArchiveBuckets = session.data._ArchiveBuckets or {}
	session.data._ArchiveBuckets[selected] = true
	cacheBucket(session, selected, merged)
	for id in pairs(groups[selected]) do session.data._Transactions[id] = nil end
	return true
end

return TransactionArchive
