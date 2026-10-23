--[[
	Module: SystemSave
	Description: 玩家存档唯一写口；原子租约、串行保存与同档幂等奖励事务
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
	事务回调禁止 yield；所有持久字段修改必须经本模块，外部效果经 AfterCommit。
]]
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Copy, Log, Players = Utils.Copy, Utils.Log, Utils.Players
local Store, UpdateModule = Utils.SystemDataStore, Utils.UpdateModule
local HttpService = game:GetService("HttpService")
local Meta = require(script.SaveMetaData)
local FixData = require(script.FixData)
local Policy = require(script.SessionPolicy)
local Archive = require(script.TransactionArchive)
local SystemSave = {}
local sessions = {}
local contexts = {}
local initialized, shuttingDown = false, false
local version = Utils.SystemGameConfig.GetValue("版本号")
local STORE = Store.STORE.Player
local OPTIONS = { maxTries = 3, retryIntervalSec = 1, priority = "critical" }
local WAIT_SECONDS = 20

-- 深拷贝标量/表，避免 Copy 实现对非表值的约定影响字段查询。
local function copy(value)
	return if type(value) == "table" then Copy.deepCopy(value) else value
end

-- 拒绝循环、非有限数、混合/稀疏数组及引擎对象，提前发现不能可靠序列化的数据。
local function serializable(value, depth, seen)
	local kind = type(value)
	if kind == "number" then return value == value and math.abs(value) < math.huge end
	if kind == "string" then return utf8.len(value) ~= nil end
	if kind == "nil" or kind == "boolean" then return true end
	if kind ~= "table" or depth > 16 or seen[value] then return false end
	seen[value] = true
	local count, maxIndex, hasString = 0, 0, false
	for key, child in pairs(value) do
		if type(key) == "number" then
			if key < 1 or key % 1 ~= 0 or key == math.huge then return false end
			count += 1
			maxIndex = math.max(maxIndex, key)
		elseif type(key) == "string" then
			if utf8.len(key) == nil then return false end
			hasString = true
		else return false end
		if not serializable(child, depth + 1, seen) then return false end
	end
	seen[value] = nil
	return count == 0 or (not hasString and maxIndex == count)
end

-- 仅返回该 Player 实例的会话；旧 Player 的延迟回调不能写入重连会话。
local function sessionFor(plr)
	local session = plr and sessions[Store.BuildPlayerKey(plr.UserId)]
	return if session and session.player == plr then session else nil
end

-- 当前事务上下文只对执行回调的协程可见。
local function contextFor(plr)
	local context = contexts[coroutine.running()]
	return if context and context.player == plr then context else nil
end

-- 等待同玩家事务结束；任何读改写调用在读取前获得已确认快照。
local function waitTransaction(session)
	local deadline = os.clock() + WAIT_SECONDS
	while session.transactionBusy do
		if os.clock() >= deadline then return false end
		task.wait()
	end
	return true
end

-- 内部租约与交易账本永不下发客户端。
local function publicSnapshot(data)
	local result = {}
	for key in pairs(Meta.PLAYER_META_DATA) do result[key] = copy(data[key]) end
	return result
end

-- 提交后统一同步镜像与客户端；同步故障不改变持久化结果。
local function sync(session, path, value)
	if session.player.Parent ~= Players then return end
	local ok, err = pcall(function()
		for _, config in ipairs(Meta.PLAYER_VALUE_LIST) do
			local value = session.player:FindFirstChild(config[1])
			if not value then
				value = Instance.new(config[2])
				value.Name = config[1]
				value.Parent = session.player
			end
			value.Value = session.data[config[1]]
		end
		Utils.PlayerData.Update(session.player, path, if path then copy(value) else publicSnapshot(session.data))
	end)
	if not ok then Log.warn("Save sync failed", err) end
end

-- 串行保存。失败的写入保留相同 WriteId，重试确认时不会覆盖后来接档服务器。
local function saveLocked(session, release)
	local ok, err = true, nil
	local requested
	repeat
		local pending = session.pending
		if not pending then
			local data = copy(session.data)
			data._WriteId = HttpService:GenerateGUID(false)
			pending = { data = data, release = release == true }
			requested = pending
			session.pending = pending
		end
		local called, success, result, storeErr = pcall(Store.Update, STORE, session.key, function(old)
			if type(old) == "table" and old._WriteId == pending.data._WriteId then return old end
			if not Policy.CanWrite(old, session.owner, os.time()) then return nil end
			local data = copy(pending.data)
			data.LastSaveTime = os.time()
			data.IsInServer = if pending.release then 0 else 1
			data.LAST_VERSION = version
			data._Session = if pending.release then nil else { owner = session.owner, expires = os.time() + Policy.LEASE_SECONDS }
			return data
		end, OPTIONS)
		if not called or not success then
			ok, err = false, if called then storeErr else success
			break
		end
		if type(result) ~= "table" or result._WriteId ~= pending.data._WriteId then
			session.lost = true
			-- 已被新 owner 接管，旧草稿不能再重试，也不能阻挡本服再次接档。
			if sessions[session.key] == session then sessions[session.key] = nil end
			ok, err = false, "SESSION_LOST"
			if session.player.Parent == Players then session.player:Kick("Data session expired. Please rejoin.") end
			break
		end
		session.pending = nil
		if pending.release then
			session.released = true
			if sessions[session.key] == session then sessions[session.key] = nil end
			break
		end
		-- 已确认旧的不确定写入后，还需把最新内存快照（含事务）真正保存。
		if pending == requested then break end
	until false
	return ok, err
end

--[[ 有界等待与异常释放；超时不强行解锁仍在执行的 IO。
	@param session table - 本服会话
	@param release boolean? - 是否释放租约
	@return boolean, string? - 确认写入或可重试错误
]]
local function save(session, release)
	local deadline = os.clock() + WAIT_SECONDS
	while session.saving do
		if os.clock() >= deadline then return false, "SAVE_BUSY" end
		task.wait()
	end
	if session.released then return true end
	if session.lost then return false, "SESSION_LOST" end
	session.saving = true
	local called, ok, err = pcall(saveLocked, session, release)
	session.saving = false
	if not called then ok, err = false, "SAVE_EXCEPTION" end
	session.uncertain = not ok
	if ok then session.readData = nil end
	if not ok then Log.warn("Save failed", session.key, err) end
	return ok, if ok then nil elseif err == "SESSION_LOST" then err else "SAVE_PENDING"
end

-- 原子接档并迁移；尚未离开的旧 Player 实例持有的会话不得复用。
function SystemSave.InitialPlayerData(plr)
	if shuttingDown or plr.Parent ~= Players then return false end
	local key = Store.BuildPlayerKey(plr.UserId)
	if sessions[key] then
		local previous = sessions[key]
		local deadline = os.clock() + 25
		while sessions[key] == previous and previous.closing and os.clock() < deadline do
			if not previous.loading then save(previous, true) end
			if sessions[key] == previous then task.wait(1) end
		end
		if sessions[key] then plr:Kick("Previous data session is still closing. Please rejoin."); return false end
	end
	local session = { key = key, player = plr, owner = game.JobId .. ":" .. HttpService:GenerateGUID(false), loading = true }
	sessions[key] = session
	local isNew = false
	for attempt = 1, 5 do
		local called, ok, result = pcall(Store.Update, STORE, key, function(old)
			if not Policy.CanAcquire(old, session.owner, os.time()) then return nil end
			isNew = old == nil or old._NewPlayerGrantPending == true or (type(old._Session) == "table" and old._Session.owner == session.owner and old._Session.newPlayer == true)
			local data = if old then copy(old) else Meta.GetDefaultPlayerMeta()
			if old == nil then data._NewPlayerGrantPending = true end
			for name, default in pairs(Meta.PLAYER_META_DATA) do
				if data[name] == nil then data[name] = copy(default) end
			end
			FixData.Run(plr, data)
			data._Transactions = data._Transactions or {}
			data._Session = { owner = session.owner, expires = os.time() + Policy.LEASE_SECONDS, newPlayer = isNew }
			data.IsInServer, data.LastSaveTime, data.LAST_VERSION = 1, os.time(), version
			return data
		end, OPTIONS)
		if called and ok and type(result) == "table" and result._Session and result._Session.owner == session.owner then
			session.data, session.loading = result, false
			if plr.Parent ~= Players or shuttingDown or session.closing then
				session.closing = true
				save(session, true)
				return false
			end
			sync(session)
			return true, isNew
		end
		if plr.Parent ~= Players or shuttingDown then break end
		if attempt < 5 then task.wait(6) end
	end
	sessions[key] = nil
	if plr.Parent == Players then plr:Kick("Can't load your game data, please login again!") end
	return false
end

-- 获取公开存档快照；内部字段只由本模块访问。
function SystemSave.GetStat(plr)
	if not plr then
		local result = {}
		for key, session in pairs(sessions) do
			if session.data and not session.closing and not session.lost then result[key] = publicSnapshot(session.readData or session.data) end
		end
		return result
	end
	local context = contextFor(plr)
	if context then return publicSnapshot(context.data) end
	local session = sessionFor(plr)
	if not session or session.loading then return nil end
	if not waitTransaction(session) then return nil end
	if session.closing or session.lost then return nil end
	return publicSnapshot(session.readData or session.data)
end

-- 字段级深拷贝，避免读取小字段时复制整个背包。
function SystemSave.GetStatByKey(plr, path)
	local context = contextFor(plr)
	local session = sessionFor(plr)
	if not context then
		if not session or session.loading then return nil end
		if not waitTransaction(session) then return nil end
		if session.closing or session.lost then return nil end
	end
	local keys = if type(path) == "table" then path else { path }
	if Meta.PLAYER_META_DATA[keys[1]] == nil then return nil end
	local value = if context then context.data else (session.readData or session.data)
	for _, key in ipairs(keys) do
		if type(value) ~= "table" then return nil end
		value = value[key]
	end
	return copy(value)
end

-- 执行不可 yield 的内存事务；失败或异常丢弃整个草稿。
local function runDraft(plr, data, callback)
	local context = { player = plr, data = copy(data), effects = {} }
	local thread = coroutine.create(function() return callback(context.data) end)
	contexts[thread] = context
	local result = table.pack(coroutine.resume(thread))
	contexts[thread] = nil
	if coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
		return nil, "TRANSACTION_MUST_NOT_YIELD"
	end
	if not result[1] then Log.warn("Transaction callback failed", result[2]); return nil, "TRANSACTION_CALLBACK_ERROR" end
	if context.failed then return nil, context.failed end
	if result[2] ~= true then return nil, result[3] or "TRANSACTION_REJECTED" end
	if not serializable(context.data, 0, {}) then return nil, "UNSERIALIZABLE_VALUE" end
	local valid, validationErr = Store.ValidateValue(context.data, 3700000)
	if not valid then return nil, validationErr end
	return context, result
end

--[[ 嵌套调用加入外层事务；任何子操作失败均令整个草稿失效，调用方不能忽略失败而提交部分数据。
	@param context table - 外层草稿
	@param callback function - 无 yield 的变更函数
	@return boolean, any - 业务结果或错误
]]
local function runNested(context, callback)
	if context.failed then return false, context.failed end
	local result = table.pack(pcall(callback, context.data))
	if not result[1] or result[2] ~= true then
		context.failed = if result[1] then (result[3] or "TRANSACTION_REJECTED") else "TRANSACTION_CALLBACK_ERROR"
		return false, context.failed
	end
	return table.unpack(result, 2, result.n)
end

-- 提交后的通知不参与发货成功判定；异常单独记录。
local function effects(context)
	for _, effect in ipairs(context.effects) do
		local ok, err = pcall(effect)
		if not ok then Log.warn("AfterCommit failed", err) end
	end
end

-- 将副作用延后；事务失败时不会执行。
function SystemSave.AfterCommit(plr, callback)
	local context = contextFor(plr)
	if context then table.insert(context.effects, callback) else callback() end
end

-- 原子修改多个字段（不立即持久化）；callback(data) 必须返回 true 或 false,error。
function SystemSave.Mutate(plr, callback)
	local context = contextFor(plr)
	if context then return runNested(context, callback) end
	local session = sessionFor(plr)
	if not session or session.loading then return false, "NO_SESSION_DATA" end
	if not waitTransaction(session) then return false, "TRANSACTION_BUSY" end
	if session.closing or session.lost or session.uncertain then return false, "SESSION_UNAVAILABLE" end
	local draft, result = runDraft(plr, session.data, callback)
	if not draft then return false, result end
	session.data = draft.data
	session.sizeByRoot = nil
	sync(session)
	effects(draft)
	return table.unpack(result, 2, result.n)
end

-- 奖励和去重标记同档持久化。IO 失败保留草稿，重试同 id 只确认保存，不再发奖。
function SystemSave.Transact(plr, transactionId, callback)
	if type(transactionId) ~= "string" or #transactionId == 0 or #transactionId > 256 then return false, "INVALID_TRANSACTION_ID" end
	local context = contextFor(plr)
	if context then
		if Archive.IsArchivable(transactionId) then context.failed = "TOP_LEVEL_TRANSACTION_REQUIRED"; return false, context.failed end
		if context.data._Transactions[transactionId] then return true, "ALREADY_APPLIED" end
		local ok, err = runNested(context, callback)
		if ok then context.data._Transactions[transactionId] = os.time() end
		return ok, err
	end
	local session = sessionFor(plr)
	if not session or session.loading then return false, "NO_SESSION_DATA" end
	if not waitTransaction(session) then return false, "TRANSACTION_BUSY" end
	if session.closing or session.lost then return false, "SESSION_UNAVAILABLE" end
	session.transactionBusy = true
	local called, accepted, failure = pcall(function()
		-- 先确认上次不确定的 IO，再接收新交易，避免把尚未提交的奖励用于下一笔业务。
		if session.uncertain then
			local recovered, recoverErr = save(session, false)
			if not recovered then return false, recoverErr end
		end
		local draft, result
		if not session.data._Transactions[transactionId] then
			local checked, archived = Archive.Contains(session, transactionId)
			if not checked then return false, archived end
			if archived then return true, "ALREADY_APPLIED" end
			draft, result = runDraft(plr, session.data, callback)
			if not draft then return false, result end
			draft.data._Transactions[transactionId] = os.time()
			session.readData = session.data
			session.data = draft.data
			session.sizeByRoot = nil
			session.transactionEffects = session.transactionEffects or {}
			session.transactionEffects[transactionId] = draft
		end
		local ok, err = save(session, false)
		if not ok then return false, err end
		return true, if draft then nil else "ALREADY_APPLIED"
	end)
	session.transactionBusy = false
	if not called then
		Log.warn("Transaction failed", transactionId, accepted)
		return false, "TRANSACTION_EXCEPTION"
	end
	if accepted then
		sync(session)
		local pendingEffects = session.transactionEffects or {}
		session.transactionEffects = {}
		for _, committed in pairs(pendingEffects) do effects(committed) end
	end
	return accepted, failure
end

-- 单字段写口与旧 API 兼容；内部账本/租约不能由业务覆盖。
function SystemSave.ChangeStat(plr, path, value)
	local context = contextFor(plr)
	local function reject(reason)
		if context then context.failed = reason end
		return false, reason
	end
	local keys = if type(path) == "table" then path else { path }
	if #keys == 0 or Meta.PLAYER_META_DATA[keys[1]] == nil then return reject("UNKNOWN_STAT_KEY") end
	for _, key in ipairs(keys) do
		if type(key) ~= "string" and type(key) ~= "number" then return reject("INVALID_STAT_PATH") end
		if type(key) == "number" and (key ~= key or key < 1 or key >= math.huge or key % 1 ~= 0) then return reject("INVALID_STAT_PATH") end
	end
	if not serializable(value, 0, {}) then return reject("UNSERIALIZABLE_VALUE") end
	local session = sessionFor(plr)
	if not context then
		if not session or session.loading then return reject("NO_SESSION_DATA") end
		if not waitTransaction(session) then return reject("TRANSACTION_BUSY") end
		if session.closing or session.lost or session.uncertain then return reject("SESSION_UNAVAILABLE") end
	end
	local data = if context then context.data else session.data
	local root = copy(data[keys[1]])
	if #keys == 1 then
		root = copy(value)
	else
		if type(root) ~= "table" then root = {} end
		local target = root
		for index = 2, #keys - 1 do
			local key = keys[index]
			if type(target[key]) ~= "table" then target[key] = {} end
			target = target[key]
		end
		target[keys[#keys]] = copy(value)
	end
	if not serializable(root, 0, {}) then return reject("UNSERIALIZABLE_VALUE") end
	if not context then
		-- 常见的小字段修改只重新计量对应根字段，避免每秒统计更新遍历整个背包。
		if not session.sizeByRoot then
			local sizes, total = {}, 2
			for key, child in pairs(data) do
				local valid, err, size = Store.ValidateValue({ [key] = child }, 3700000)
				if not valid then return reject(err) end
				sizes[key], total = size, total + size
			end
			session.sizeByRoot, session.sizeTotal = sizes, total
		end
		local valid, err, size = Store.ValidateValue({ [keys[1]] = root }, 3700000)
		if not valid then return reject(err) end
		local total = session.sizeTotal - (session.sizeByRoot[keys[1]] or 0) + size
		if total > 3700000 then return reject("VALUE_TOO_LARGE") end
		session.sizeByRoot[keys[1]], session.sizeTotal = size, total
	end
	data[keys[1]] = root
	if not context then sync(session, path, value) end
	return true
end

-- 离服先禁止新修改；保存确认后才移除缓存，失败由自动保存继续重试。
function SystemSave.PlayerLeaveSave(plr)
	local session = sessionFor(plr)
	if not session then return true end
	session.closing = true
	if not waitTransaction(session) then return false, "TRANSACTION_BUSY" end
	if session.loading then return false end
	return save(session, true)
end

-- 请求立即保存当前玩家。
function SystemSave.TradeSave(plr)
	local session = sessionFor(plr)
	if not session or session.loading then return false end
	if not waitTransaction(session) then return false, "TRANSACTION_BUSY" end
	return save(session, session.closing)
end

-- 并发限制为四名玩家；同玩家保存始终串行，失败离服会话也保留重试。
function SystemSave.AutoSave()
	local queue = {}
	for _, session in pairs(sessions) do if not session.loading then table.insert(queue, session) end end
	local cursor, workers = 0, math.min(4, #queue)
	local remaining = workers
	for _ = 1, workers do
		task.spawn(function()
			while true do
				cursor += 1
				local session = queue[cursor]
				if not session then break end
				local ownsLock = false
				local called, err = pcall(function()
					if not waitTransaction(session) then return end
					local saved = save(session, session.closing)
					-- 普通自动保存期间仍接受内存修改；仅归档移除标记时持有事务锁。
					if saved and not session.closing and not session.transactionBusy then
						session.transactionBusy, ownsLock = true, true
						if Archive.Compact(session) then
							session.sizeByRoot = nil
							saved = save(session, false)
						end
						session.transactionBusy, ownsLock = false, false
					end
					if saved and not session.closing and not session.transactionBusy and session.transactionEffects and next(session.transactionEffects) then
						sync(session)
						local pendingEffects = session.transactionEffects
						session.transactionEffects = {}
						for _, context in pairs(pendingEffects) do effects(context) end
					end
				end)
				if ownsLock then session.transactionBusy = false end
				if not called then Log.warn("Autosave worker failed", session.key, err) end
			end
			remaining -= 1
		end)
	end
	while remaining > 0 do task.wait() end
end

-- 关服等待保存完成，最多 25 秒；不再接受新会话/修改。
function SystemSave.Shutdown()
	shuttingDown = true
	for _, session in pairs(sessions) do session.closing = true end
	local deadline = os.clock() + 25
	local done = false
	task.spawn(function()
		repeat
			SystemSave.AutoSave()
			if next(sessions) == nil then break end
			task.wait(1)
		until os.clock() >= deadline
		done = true
	end)
	while not done and os.clock() < deadline do task.wait() end
	if next(sessions) then Log.warn("Shutdown ended with unsaved sessions") end
end

-- 注册不重叠自动保存任务。
function SystemSave.Init()
	if initialized then return end
	initialized = true
	UpdateModule.Register(UpdateModule.INTERVAL.SEC_30, SystemSave.AutoSave, { spawn = true })
end
return SystemSave
