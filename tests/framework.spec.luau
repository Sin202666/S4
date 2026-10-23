-- Fault injection against real source, loaded by scripts/check_framework.py.
local passed = 0
local function test(name, callback)
	local ok, err = pcall(callback)
	assert(ok, name .. ": " .. tostring(err))
	passed += 1
	print("PASS", name)
end
local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end
local sys = "ServerStorage/ServerSideCode/System/"
local shared = "ReplicatedFirst/AllSideCode/ToolSystem/"
local policy = loadModule(sys .. "SystemSave/SessionPolicy.luau")
test("lease takeover excludes active server and fences expired owner", function()
	local data = { _Session = { owner = "A", expires = 120 } }
	assert(not policy.CanAcquire(data, "B", 119))
	assert(policy.CanAcquire(data, "B", 120))
	assert(not policy.CanWrite(data, "A", 120))
	assert(not policy.CanWrite(data, "B", 119))
	assert(not policy.CanAcquire({ IsInServer = 1, LastSaveTime = 50 }, "B", 60))
end)

local guard = loadModule(sys .. "SystemDataStore/ValueGuard.luau")
local function fixture()
	local storage, writes, faults = {}, 0, {}
	local clock, guid = 1000, 0
	local player = { UserId = 123, Name = "Test", DisplayName = "Test", children = {} }
	local players = { GetPlayers = function() return { player } end, GetPlayerByUserId = function(_, id) return if id == 123 then player else nil end }
	player.Parent = players
	function player:FindFirstChild(name) return self.children[name] end
	function player:Kick(message) self.kicked = message end
	function player:IsA(name) return name == "Player" end
	local store = { STORE = { Player = "Player", PurchaseHistory = "PurchaseHistory", TransactionArchive = "TransactionArchive", Email = "Email" }, BuildPlayerKey = function(id) return "Player" .. id end }
	store.ValidateValue = guard.Check
	function store.Get(_, key) return true, copy(storage[key]) end
	function store.Update(_, key, callback)
		writes += 1
		if faults.pause then faults.pause = false; coroutine.yield() end
		if faults.before then faults.before = false; return false, nil, "injected before write" end
		local result = callback(copy(storage[key]))
		if result ~= nil then storage[key] = copy(result) end
		if faults.after and (not faults.key or faults.key == key) then faults.after = false; return false, nil, "injected after write" end
		return true, copy(result)
	end
	local effects = {}
	local utils = {
		Copy = { deepCopy = copy }, Log = { warn = function() end }, Players = players,
		SystemDataStore = store, UpdateModule = {},
		SystemGameConfig = { GetValue = function() return "1.0.0" end },
		PlayerData = { Update = function(_, _, data) table.insert(effects, data) end },
	}
	local gameMock = { JobId = "server-A", ReplicatedFirst = { AllSideCode = { UtilsSystem = "utils" } } }
	function gameMock:GetService(name)
		if name == "Players" then return players end
		assert(name == "HttpService")
		return { GenerateGUID = function() guid += 1; return "guid-" .. guid end }
	end
	local env = {
		game = gameMock, os = { time = function() return clock end, clock = function() return clock end },
		task = { wait = function() error("unexpected yield") end, cancel = coroutine.close, defer = function() end, spawn = function() end },
		Instance = { new = function() return {} end },
		script = { SaveMetaData = "meta", FixData = "fix", SessionPolicy = "policy", TransactionArchive = "archive" },
	}
	local meta, fix
	env.require = function(name)
		if name == "utils" then return utils end
		if name == "meta" then return meta end
		if name == "fix" then return fix end
		if name == "policy" then return policy end
		if name == "archive" then return loadModule(sys .. "SystemSave/TransactionArchive.luau", env) end
		error("unknown module " .. tostring(name))
	end
	meta = loadModule(sys .. "SystemSave/SaveMetaData.luau", env)
	fix = loadModule(sys .. "SystemSave/FixData.luau", env)
	local save = loadModule(sys .. "SystemSave/init.luau", env)
	return {
		save = save, player = player, storage = storage, faults = faults, fix = fix, utils = utils, env = env,
		clock = function(value) clock = value end, writes = function() return writes end,
	}
end

test("migration is one-time and preserves subsequent 1 percent setting", function()
	local f = fixture()
	local data = { Setting = { BGM = 1, Shake = 1 } }
	f.fix.Run(f.player, data)
	assert(data.Setting.BGM == 100 and data._SchemaVersion == 1)
	data.Setting.BGM, data.Setting.Shake = 1, 1
	f.fix.Run(f.player, data)
	assert(data.Setting.BGM == 1 and data.Setting.Shake == 1)
end)

local function receiptFixture()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	local cfg = { OnlyTag = "Pack", passID = 10, cost = 2, price = 5, itemID = { 1 }, itemCount = { 3 } }
	f.utils.SystemSave = f.save
	f.utils.EnumMgr = { RobuxType = { GamePass = 1 }, PlayerInst = { GiftPlayer = "GiftPlayer" }, BuyRobloxErr = {} }
	f.utils.CfgFind = {
		FindCfgByPassID = function(id) return if id == 10 then cfg else nil end,
		FindCfgByPassID_Gift = function(id) return if id == 20 then cfg else nil end,
		FindCfgByOnlyTag = function() return cfg end,
	}
	f.utils.RankConfig = { GetRecordField = function() return "Spend" end }
	f.utils.TipsModule = { ShowAwardPop = function() end }
	f.utils.SystemBag = { AddItems = function(player, _, counts)
		return f.save.Mutate(player, function(data)
			data.Bag.Coins = { id = 1, count = (data.Bag.Coins and data.Bag.Coins.count or 0) + counts[1] }
			return not f.rejectGrant
		end)
	end }
	f.env.Enum = { ProductPurchaseDecision = { NotProcessedYet = "pending", PurchaseGranted = "granted" } }
	f.buy = loadModule(sys .. "SystemBuyRoblox.luau", f.env)
	f.cfg = cfg
	return f
end

test("ProcessReceipt acknowledges only confirmed reward and deduplicates retries", function()
	local f = receiptFixture()
	local receipt = { PlayerId = 123, ProductId = 10, PurchaseId = "A" }
	f.faults.after, f.faults.key = true, "Player123"
	assert(f.buy.ProcessReceipt(receipt) == "pending")
	assert(f.storage.Player123.Bag.Coins.count == 3)
	assert(f.buy.ProcessReceipt(receipt) == "granted")
	assert(f.buy.ProcessReceipt(receipt) == "granted")
	assert(f.storage.Player123.Bag.Coins.count == 3 and f.storage.Player123.Record.Spend == 5)
end)

test("failed product grant does not leave a successful purchase marker", function()
	local f = receiptFixture()
	f.rejectGrant = true
	assert(f.buy.ProcessReceipt({ PlayerId = 123, ProductId = 10, PurchaseId = "B" }) == "pending")
	assert(f.storage["123_B"].state == "Pending" and f.storage.Player123.Bag.Coins == nil)
end)

test("gift receipt route survives lost response and changed UI selection", function()
	local f, receiver = receiptFixture(), nil
	f.utils.SystemEmail = { GivePlrEmail = function(mail) receiver = mail.UserID; return true end }
	assert(f.save.ChangeStat(f.player, "GiftIntents", { ["20"] = { target = 44 } }))
	local receipt = { PlayerId = 123, ProductId = 20, PurchaseId = "G" }
	f.faults.after = true
	assert(f.buy.ProcessReceipt(receipt) == "pending")
	assert(f.save.ChangeStat(f.player, "GiftIntents", { ["20"] = { target = 55 } }))
	assert(f.buy.ProcessReceipt(receipt) == "granted" and receiver == 44)
end)

test("failed batch, thrown callback and yielding callback change nothing", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	assert(not f.save.Transact(f.player, "reject", function(data) data.onlyID = 99; return false end))
	assert(not f.save.Transact(f.player, "throw", function(data) data.onlyID = 99; error("boom") end))
	assert(not f.save.Transact(f.player, "yield", function(data) data.onlyID = 99; coroutine.yield(); return true end))
	assert(f.save.GetStat(f.player).onlyID == 1)
	assert(f.storage.Player123.onlyID == 1)
end)

test("receipt response lost after durable write retries without duplicate reward", function()
	local f, grants = fixture(), 0
	assert(f.save.InitialPlayerData(f.player))
	local function grant(data) grants += 1; data.onlyID += 10; return true end
	f.faults.after = true
	assert(not f.save.Transact(f.player, "receipt:1", grant))
	assert(f.storage.Player123.onlyID == 11)
	assert(f.save.Transact(f.player, "receipt:1", grant))
	assert(f.save.Transact(f.player, "receipt:1", grant))
	assert(grants == 1 and f.storage.Player123.onlyID == 11)
	assert(f.storage.Player123._Transactions["receipt:1"])
	assert(f.save.GetStat(f.player)._Transactions == nil)
end)

test("write failure before commit retains pending reward and succeeds on retry", function()
	local f, grants = fixture(), 0
	assert(f.save.InitialPlayerData(f.player))
	f.faults.before = true
	local function grant(data) grants += 1; data.onlyID += 2; return true end
	assert(not f.save.Transact(f.player, "mail:1", grant))
	assert(f.storage.Player123.onlyID == 1)
	assert(f.save.Transact(f.player, "mail:1", grant))
	assert(grants == 1 and f.storage.Player123.onlyID == 3)
end)

test("new server owner fences previous session writes", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.storage.Player123._Session = { owner = "server-B", expires = 99999 }
	f.storage.Player123.onlyID = 888
	assert(not f.save.TradeSave(f.player))
	assert(f.storage.Player123.onlyID == 888 and f.player.kicked)
end)

test("ordinary mutations during autosave are retained for the next snapshot", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.faults.pause = true
	local thread = coroutine.create(function() assert(f.save.TradeSave(f.player)) end)
	assert(coroutine.resume(thread))
	assert(coroutine.status(thread) == "suspended")
	assert(f.save.ChangeStat(f.player, "onlyID", 7))
	assert(coroutine.resume(thread))
	assert(f.save.GetStat(f.player).onlyID == 7)
	assert(f.save.TradeSave(f.player))
	assert(f.storage.Player123.onlyID == 7)
end)

test("failed leave retains session until release is durably confirmed", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.faults.after = true
	assert(not f.save.PlayerLeaveSave(f.player))
	assert(not f.save.ChangeStat(f.player, "onlyID", 9))
	assert(f.save.PlayerLeaveSave(f.player))
	assert(f.storage.Player123._Session == nil and f.storage.Player123.IsInServer == 0)
	assert(f.save.GetStat(f.player) == nil)
end)

test("nested gamepass grant joins receipt transaction", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	assert(f.save.Transact(f.player, "receipt:gift", function()
		return f.save.Transact(f.player, "pass:1", function(data)
			data.GamePass.Pass = 1
			return f.save.ChangeStat(f.player, "onlyID", 8)
		end)
	end))
	assert(f.storage.Player123.onlyID == 8)
	assert(f.storage.Player123._Transactions["pass:1"] and f.storage.Player123._Transactions["receipt:gift"])
	assert(f.writes() == 2, "one acquisition and one commit expected")
end)

local plan = loadModule(sys .. "SystemBag/BagPlan.luau")
local config = function(id) return if id < 3 then { tp = id, stack = id == 1 } else nil end
local stackable = function(cfg) return cfg.stack end
test("bag rejects partial invalid batch and nonfinite/zero/fractional counts", function()
	local bag = {}
	assert(not plan.Build(bag, 1, { 1, 999 }, { 1, 1 }, config, stackable))
	for _, count in ipairs({ 0, -1, math.huge, 0/0, 1.5 }) do
		assert(not plan.Build(bag, 1, { 1 }, { count }, config, stackable))
	end
	assert(next(bag) == nil)
end)
test("bag merges duplicate stacks and allocates unique IDs atomically", function()
	local bag = { ["2"] = { id = 1, count = 4, onlyID = 2 } }
	local ok, result = plan.Build(bag, 2, { 1, 1, 2 }, { 2, 3, 2 }, config, stackable)
	assert(ok and result.bag["2"].count == 9 and result.onlyId == 4)
	assert(#result.created == 2 and bag["2"].count == 4)
end)

test("scheduler delivers elapsed once and prevents overlapping async callbacks", function()
	local heartbeat, queue, total, calls = nil, {}, 0, 0
	local utils = { Log = { warn = function() end }, RunService = {
		IsServer = function() return true end,
		Heartbeat = { Connect = function(_, callback) heartbeat = callback; return {} end },
	} }
	local update = loadModule(shared .. "UpdateModule.luau", {
		game = { ReplicatedFirst = { AllSideCode = {} } }, require = function() return utils end,
		task = { spawn = function(fn) table.insert(queue, fn) end },
	})
	update.Register(1, function(elapsed) calls += 1; total += elapsed end, { spawn = true })
	update.Start()
	heartbeat(2.5); heartbeat(0.25); heartbeat(0.25)
	assert(#queue == 1)
	table.remove(queue, 1)()
	heartbeat(0.5)
	table.remove(queue, 1)()
	assert(calls == 2 and total == 3.5)
end)

test("payload guard rejects nested NaN, infinity, cyclic and excessive data", function()
	local guard = loadModule(shared .. "NetWork/PayloadGuard.luau")
	assert(guard.Check(table.pack(nil, 1, "ok")))
	assert(not guard.Check({ extra = { target = 0/0 } }))
	assert(not guard.Check({ math.huge }))
	local cycle = {}; cycle.self = cycle
	assert(not guard.Check(cycle))
	assert(not guard.Check(string.rep("x", 9000)))
end)
test("reserved CDK resumes after expiry with frozen rewards and cannot be stolen", function()
	local f = fixture()
	f.storage.Pool = { cdks = { CODE = { redeemed = false }, OLD = { redeemed = true, redeemedBy = 123 } } }
	f.utils.CfgFind = { GetCfgByName = function()
		return { { codeType = 3, code = "Pool", rewardId = { 1 }, rewardNum = { 5 }, startTime = 0, endTime = 1100 } }
	end }
	local cdk = loadModule(sys .. "SystemCDK.luau", f.env)
	local ok, ids, counts = cdk.Redeem(f.player, "CODE")
	assert(ok and ids[1] == 1 and counts[1] == 5)
	f.clock(1200)
	local other = { UserId = 456, Parent = true, IsA = function() return true end }
	assert(not cdk.Redeem(other, "CODE"))
	assert(not cdk.RollbackRedeem(f.player, "Pool", "CODE"))
	assert(cdk.Redeem(f.player, "CODE"))
	assert(not cdk.Redeem(f.player, "OLD"))
end)

test("likes survive CAS retry, concurrent clicks and stale operations", function()
	local like = loadModule("ReplicatedStorage/ShortVideoFeature/Server/LikePolicy.luau")
	local row = like.Apply({ likeCount = 0 }, "123", true, 0, false)
	row = like.Apply(row, "123", true, 0, false)
	assert(row.likeCount == 1 and row._votes["123"].revision == 1)
	row = like.Apply(row, "123", false, 1, false)
	row = like.Apply(row, "123", true, 0, false)
	assert(row.likeCount == 0)
	row = like.Apply(row, "456", true, 0, false)
	assert(row.likeCount == 1)
end)

test("RemoteFunction and BindableFunction preserve nil and error returns", function()
	local remote, bindable = {}, {}
	local pipes = {
		IsInboundMatch = function() return true end,
		ForEach = function(kind, callback)
			if kind == "RemoteFunction" then callback(remote) end
			if kind == "BindableFunction" then callback(bindable) end
		end,
	}
	local services = { IsServer = function() return true end, IsClient = function() return false end, IsStudio = function() return false end }
	local utils = { Log = { warn = function() end }, RequestRateLimit = { CheckRateLimit = function() return true end, IsCheatDetectionEnabled = function() return false end } }
	local modules = { utils = utils, channel = { DEFAULT = "Default" }, map = {}, pipes = pipes, guard = loadModule(shared .. "NetWork/PayloadGuard.luau"), budget = loadModule(shared .. "NetWork/RequestBudget.luau") }
	local player = { Parent = true, IsA = function() return true end }
	local dispatch = loadModule(shared .. "NetWork/InboundDispatch.luau", {
		game = { GetService = function() return services end, ReplicatedFirst = { AllSideCode = { UtilsSystem = "utils", ToolBasic = { NetChannel = "channel", NetChannelMap = "map" } } } },
		script = { Parent = { ChannelPipes = "pipes", PayloadGuard = "guard", RequestBudget = "budget" } },
		require = function(name) return assert(modules[name]) end,
		typeof = function(value) return if value == player then "Instance" else typeof(value) end,
	})
	dispatch.RegisterServerRemoteFunction("Test", function() return false, "EXPECTED", nil, 9 end)
	dispatch.RegisterBindableFunction("Test", function() return nil, "EXPECTED", false end)
	dispatch.BindAll()
	local values = table.pack(remote.OnServerInvoke(player, "Test"))
	assert(values.n == 4 and values[1] == false and values[2] == "EXPECTED" and values[3] == nil and values[4] == 9)
	values = table.pack(bindable.OnInvoke("Test"))
	assert(values.n == 3 and values[1] == nil and values[2] == "EXPECTED" and values[3] == false)
end)

test("client InvokeServer preserves all return values", function()
	local remote = { InvokeServer = function() return false, "BUSY", nil, 7 end }
	local modules = {
		pipes = { Resolve = function() return remote end, LoadAll = function() end },
		dispatch = { BindAll = function() end, LogWarn = function() end },
	}
	local network = loadModule(shared .. "NetWork/init.luau", {
		game = { GetService = function() return { IsServer = function() return false end, IsClient = function() return true end } end },
		script = { ChannelPipes = "pipes", InboundDispatch = "dispatch" }, require = function(name) return modules[name] end,
	})
	local result = table.pack(network.InvokeServer("Test"))
	assert(result.n == 4 and result[1] == false and result[2] == "BUSY" and result[4] == 7)
end)

test("20 Hz aim samples and exact window boundary remain accepted", function()
	local now = 0
	local player = { UserId = 1, Parent = true, Name = "Test", IsA = function() return true end }
	local utils = {
		Log = { warn = function() end }, TipsModule = { ErrorTips = function() end }, Copy = { deepCopy = copy },
		NetMsg = setmetatable({}, { __index = function(_, key) return key end }),
	}
	local rate = loadModule(shared .. "RequestRateLimit.luau", {
		game = { GetService = function(_, name) return if name == "RunService" then { IsServer = function() return true end } else {} end,
			ReplicatedFirst = { AllSideCode = {} } },
		require = function() return utils end, os = { clock = function() return now end },
		typeof = function(value) return if value == player then "Instance" else typeof(value) end,
	})
	rate.SetRateLimitConfig("Aim", { maxRequests = 30, timeWindow = 1 })
	for index = 1, 200 do now = index / 20; assert(rate.CheckRateLimit(player, "Aim")) end
	rate.SetRateLimitConfig("Boundary", { maxRequests = 1, timeWindow = 1 })
	now = 100; assert(rate.CheckRateLimit(player, "Boundary"))
	now = 101; assert(rate.CheckRateLimit(player, "Boundary"))
end)


test("ignored nested failures abort the entire transaction including effects", function()
	local f, emitted = fixture(), 0
	assert(f.save.InitialPlayerData(f.player))
	assert(not f.save.Transact(f.player, "outer", function(data)
		f.save.Mutate(f.player, function(inner)
			inner.onlyID = 999
			f.save.AfterCommit(f.player, function() emitted += 1 end)
			return false, "REJECT"
		end)
		data.GamePass.Bad = 1
		return true
	end))
	assert(f.save.GetStat(f.player).onlyID == 1 and emitted == 0)
	assert(f.storage.Player123.GamePass.Bad == nil)
end)

test("uncertain transaction is hidden from business reads until confirmed", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.faults.before = true
	assert(not f.save.Transact(f.player, "one", function(data) data.onlyID = 10; return true end))
	assert(f.save.GetStatByKey(f.player, "onlyID") == 1)
	assert(not f.save.ChangeStat(f.player, "onlyID", 99))
	assert(f.save.Transact(f.player, "one", function() error("must not replay") end))
	assert(f.save.GetStatByKey(f.player, "onlyID") == 10)
end)

test("store exceptions release locks and allow a later confirmed save", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	local original = f.utils.SystemDataStore.Update
	f.utils.SystemDataStore.Update = function() error("transport") end
	assert(not f.save.Transact(f.player, "retry", function(data) data.onlyID = 7; return true end))
	f.utils.SystemDataStore.Update = original
	assert(f.save.Transact(f.player, "retry", function() error("duplicate") end))
	assert(f.storage.Player123.onlyID == 7)
end)

test("lost session is detached and cannot block a later lease acquisition", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.storage.Player123._Session = { owner = "B", expires = 1001 }
	assert(not f.save.TradeSave(f.player))
	f.clock(1002)
	assert(f.save.InitialPlayerData(f.player))
	assert(f.save.ChangeStat(f.player, "onlyID", 8))
end)

test("batch removal combines duplicate ids, respects locks and is atomic", function()
	local remove = loadModule(sys .. "SystemBag/BagRemovePlan.luau")
	local bag = { a = { id = 1, count = 5 }, b = { id = 1, count = 4, lock = true }, c = { id = 2, count = 2 } }
	local locked = function(row) return row.lock == true end
	assert(not remove.Build(bag, {1,1}, {3,3}, config, locked))
	assert(not remove.Build(bag, {1,2}, {4,3}, config, locked))
	for _, bad in ipairs({0,-1,1.5,math.huge,0/0}) do assert(not remove.Build(bag, {1}, {bad}, config, locked)) end
	local ok, result = remove.Build(bag, {1,1,2}, {2,3,2}, config, locked)
	assert(ok and result.bag.a == nil and result.bag.c == nil and result.bag.b.count == 4)
	assert(bag.a.count == 5 and bag.c.count == 2)
end)

test("serialization rejects malformed UTF8, mixed tables and oversized payload", function()
	assert(not guard.Check({ text = string.char(255) }))
	assert(not guard.Check({[1]=1, field=2}))
	assert(not guard.Check({string.rep("x", 500)}, 400))
	assert(guard.Check({ message = "有效中文", values = {1,2,3} }))
end)

test("archive is durable before player markers are removed and blocks replay", function()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	local archive = loadModule(sys .. "SystemSave/TransactionArchive.luau", f.env)
	local data = copy(f.storage.Player123)
	for index=1,600 do data._Transactions["mail:" .. index] = 1000 end
	local session = { key="Player123", data=data }
	f.faults.before = true
	assert(not archive.Compact(session))
	assert(session.data._ArchiveBuckets == nil)
	assert(archive.Compact(session))
	local moved
	for index=1,600 do
		local id = "mail:" .. index
		if not data._Transactions[id] then moved = id; break end
	end
	assert(moved)
	session.archiveCache = nil
	local checked, found = archive.Contains(session, moved)
	assert(checked and found)
end)


test("global request budget limits cross-route floods and in-flight calls", function()
	local budget = loadModule(shared .. "NetWork/RequestBudget.luau")
	local player = {}
	for _=1,240 do assert(budget.Take(player,0)) end
	assert(not budget.Take(player,0))
	assert(budget.Take(player,1))
	for _=1,8 do assert(budget.Enter(player)) end
	assert(not budget.Enter(player))
	budget.Leave(player)
	assert(budget.Enter(player))
	assert(budget.Take({},0))
end)


local function emailFixture()
	local f = receiptFixture()
	f.utils.SystemBuyRoblox = f.buy
	f.utils.HttpService = f.env.game:GetService("HttpService")
	f.utils.EnumMgr.GmEmailErr = { QueuedGrantFailed = "QUEUED" }
	f.utils.CfgFind.FindCfgByID = function(id) return { id=id } end
	f.utils.PlayerData.GetPlrData = f.save.GetStat
	f.utils.PlayerData.GetPlrDataByKey = f.save.GetStatByKey
	f.env.workspace = { GetServerTimeNow = function() return 1000 end }
	f.email = loadModule(sys .. "SystemEmail.luau", f.env)
	f.utils.SystemEmail = f.email
	return f
end

test("actual gift receipt queues snapshot-only mail with empty direct rewards", function()
	local f = emailFixture()
	assert(f.save.ChangeStat(f.player, "GiftIntents", {["20"]={target=44}}))
	assert(f.buy.ProcessReceipt({PlayerId=123,ProductId=20,PurchaseId="GiftMail"}) == "granted")
	assert(#f.storage["44"] == 1)
	local mail = f.storage["44"][1]
	assert(mail.MailId == "receipt:123_GiftMail" and mail.Ex_Data.GrantSnapshot.itemCount[1] == 3)
	f.cfg.itemCount[1] = 900
	assert(f.buy.ProcessReceipt({PlayerId=123,ProductId=20,PurchaseId="GiftMail"}) == "granted")
	assert(#f.storage["44"] == 1 and mail.Ex_Data.GrantSnapshot.itemCount[1] == 3)
end)

test("mail delivery retry uses permanent player ledger after mailbox confirmation failure", function()
	local f = emailFixture()
	f.storage["123"] = {{MailId="M", RewardID={1}, RewardCount={3}, IsSynced=0}}
	f.faults.after, f.faults.key = true, "Player123"
	assert(not f.email.DeliverPending(f.player))
	assert(f.storage.Player123.Bag.Coins.count == 3)
	assert(f.email.DeliverPending(f.player))
	assert(f.storage["123"][1].IsSynced == 1 and f.storage.Player123.Bag.Coins.count == 3)
end)

test("receipt retries use frozen grants even when product config is removed", function()
	local f = receiptFixture()
	f.faults.after = true
	local receipt = {PlayerId=123,ProductId=10,PurchaseId="Frozen"}
	assert(f.buy.ProcessReceipt(receipt) == "pending")
	f.cfg.itemCount[1] = 999
	f.utils.CfgFind.FindCfgByPassID = function() return nil end
	f.utils.CfgFind.FindCfgByPassID_Gift = function() return nil end
	assert(f.buy.ProcessReceipt(receipt) == "granted")
	assert(f.storage.Player123.Bag.Coins.count == 3)
end)

test("verified legacy compensation is immutable and idempotent", function()
	local f = receiptFixture()
	f.utils.SystemBuyRoblox = f.buy
	local recovery = loadModule(sys .. "SystemPurchaseRecovery.luau", f.env)
	f.storage["123_old"] = true
	assert(recovery.Preview(f.player,"old").state == "LegacyUnverified")
	local grant = f.buy.CreateGrantSnapshot(f.cfg)
	assert(recovery.ApplyVerified(f.player,"old","case-1","reviewed platform order",grant))
	assert(recovery.ApplyVerified(f.player,"old","case-1","retry",grant))
	assert(not recovery.ApplyVerified(f.player,"old","case-2","different case",grant))
	assert(f.storage.Player123.Bag.Coins.count == 3)
end)

local function socialFixture()
	local stores, faults, queue = {}, {}, {}
	local constants = {
		DATASTORE = { Stats="Stats",Comments="Legacy",CommentBody="Body",Player="SocialPlayer",CommentRank="Rank",CommentTime="Time" },
		COMMENT_SORT = {Hot="hot",Newest="newest"}, COMMENT_SCORE_LIKE_MUL=1000000000,
		COMMENT_BODY_CACHE_TTL_SEC=5,
	}
	local gateway = {ValidateValue=guard.Check}
	function gateway.OpenStore(name, scope)
		local key = name .. (scope or "")
		stores[key] = stores[key] or {}
		local data = stores[key]
		return {
			GetAsync=function(_,id) return copy(data[id]) end,
			SetAsync=function(_,id,value)
				if faults.store == key then faults.store=nil; error("write failure") end
				data[id]=copy(value)
			end,
			UpdateAsync=function(_,id,fn)
				if faults.store == key then faults.store=nil; error("write failure") end
				local result=fn(copy(data[id]))
				if result ~= nil then data[id]=copy(result) end
				if faults.after == key then faults.after=nil; error("response lost") end
				return copy(result)
			end,
			RemoveAsync=function(_,id) data[id]=nil end,
		}
	end
	local env = {
		game={ReplicatedFirst={AllSideCode={UtilsSystem="utils"}}},
		script={Parent={Parent={Shared={Constants="constants"}},LikePolicy="likes"}},
		require=function(name)
			if name=="utils" then return {SystemDataStore=gateway} end
			if name=="constants" then return constants end
			if name=="likes" then return loadModule("ReplicatedStorage/ShortVideoFeature/Server/LikePolicy.luau") end
		end,
		warn=function() end,
		task={spawn=function(fn,...) table.insert(queue,{fn=fn,args=table.pack(...)}) end,wait=function() end},
	}
	local social=loadModule("ReplicatedStorage/ShortVideoFeature/Server/SocialStore.luau",env)
	social.EnsureUnderHardCap=function() return true end
	social.KickLifecycleIfNeeded=function() end
	local function drain()
		while #queue>0 do local job=table.remove(queue,1); job.fn(table.unpack(job.args,1,job.args.n)) end
	end
	return {social=social,stores=stores,faults=faults,drain=drain}
end

test("partial legacy comment migration keeps source and preserves concurrent votes on retry", function()
	local f=socialFixture()
	f.stores.Legacy.V={{cid="C",videoId="V",text="hello",createdAt=100,likeCount=0}}
	f.faults.store="RankV"
	f.social.KickMigrateIfNeeded("V"); f.drain()
	assert(f.stores.Legacy.V[1] and f.stores.Body.C)
	f.stores.Body.C.likeCount=5; f.stores.Body.C._votes={u={liked=true,revision=1}}
	f.social.KickMigrateIfNeeded("V"); f.drain()
	assert(f.stores.Legacy.V.migrated and f.stores.Body.C.likeCount==5 and f.stores.Body.C._votes.u)
end)

test("durable comment outbox recovers stats failure without deletion or duplicate count", function()
	local f=socialFixture()
	f.social.KickMigrateIfNeeded("V"); f.drain()
	f.faults.after="Stats"
	local ok,_,pending=f.social.AddComment("V",{cid="C",videoId="V",text="hello",createdAt=100,likeCount=0})
	assert(ok and pending and f.stores.Body.C and f.stores.ShortVideoCommentRepair.V.C)
	assert(f.social.RepairComments("V"))
	assert(f.stores.Stats.V.commentCount==1 and next(f.stores.ShortVideoCommentRepair.V)==nil)
	assert(f.social.RepairComments("V"))
	assert(f.stores.Stats.V.commentCount==1)
end)


local function useFixture()
	local f = fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.utils.SystemSave=f.save
	f.utils.HttpService=f.env.game:GetService("HttpService")
	f.utils.PlayerData.GetPlrDataByKey=f.save.GetStatByKey
	f.utils.PlayerData.GetPlrData=f.save.GetStat
	f.utils.PlayerData.ChangePlrData=f.save.ChangeStat
	f.utils.EnumMgr={ItemType={UseItem=1}}
	f.utils.SystemRecord={RecordDelBagItem=function(player,_,count)
		local current=f.save.GetStatByKey(player,{"Record","Removed"}) or 0
		return f.save.ChangeStat(player,{"Record","Removed"},current+count)
	end}
	f.utils.CfgFind={FindCfgByID=function(id) return {id=id,UseScript="Test",parms={}} end}
	f.useScript={Transactional=true,Use=function(player,_,count)
		assert(f.save.ChangeStat(player,{"Record","Used"},count))
		return true,"used"
	end}
	local itemModule={Name="Test",IsA=function() return true end}
	f.utils.ServerStorage={ServerSideCode={ItemScript={GetChildren=function() return {itemModule} end}}}
	local modules={
		shared={validatePlayer=function() return true end,getBagData=function(plr) return f.save.GetStatByKey(plr,"Bag") end,isItemLocked=function(row) return row.lock==true end},
		sync={update=function() end},pipeline={},equip={},remove=loadModule(sys .. "SystemBag/BagRemovePlan.luau")
	}
	local oldRequire=f.env.require
	f.env.require=function(name)
		if name==itemModule then return f.useScript end
		return modules[name] or oldRequire(name)
	end
	f.env.script={Parent={BagShared="shared",BagValueSync="sync",BagPipeline="pipeline",BagEquip="equip",BagRemovePlan="remove",BagInventory="inventory"}}
	f.inventory=loadModule(sys .. "SystemBag/BagInventory.luau",f.env)
	modules.inventory=f.inventory
	f.use=loadModule(sys .. "SystemBag/BagUseItem.luau",f.env)
	assert(f.save.ChangeStat(f.player,"Bag",{["2"]={id=1,count=5,onlyID=2},["3"]={id=1,count=3,onlyID=3}}))
	return f
end

test("actual UseItem consumes exact slot and persists reward plus consumption record together",function()
	local f=useFixture()
	local ok,payload=f.use.UseItem(f.player,3,2)
	assert(ok and payload=="used")
	assert(f.storage.Player123.Bag["3"].count==1 and f.storage.Player123.Bag["2"].count==5)
	assert(f.storage.Player123.Record.Used==2 and f.storage.Player123.Record.Removed==2)
end)

test("UseItem rejects legacy, failed and yielding scripts without consuming",function()
	local f=useFixture()
	f.useScript.Transactional=false
	assert(not f.use.UseItem(f.player,3,1))
	f.useScript.Transactional=true
	f.useScript.Use=function(plr) f.save.ChangeStat(plr,"onlyID",99); return false end
	assert(not f.use.UseItem(f.player,3,1))
	f.useScript.Use=function() coroutine.yield(); return true end
	assert(not f.use.UseItem(f.player,3,1))
	local data=f.save.GetStat(f.player)
	assert(data.Bag["3"].count==3 and data.onlyID==1 and not data.Record.Removed)
end)

test("waiting readers and autosave cannot unlock another pending transaction",function()
	local f=fixture()
	assert(f.save.InitialPlayerData(f.player))
	f.faults.pause=true
	local thread=coroutine.create(function()
		assert(f.save.Transact(f.player,"held",function(data) data.onlyID=8; return true end))
	end)
	assert(coroutine.resume(thread))
	local now=1000
	f.env.task.wait=function() now+=21; f.clock(now) end
	f.env.task.spawn=function(fn) fn() end
	f.save.AutoSave()
	assert(f.save.GetStat(f.player)==nil)
	assert(coroutine.resume(thread))
	assert(f.save.GetStat(f.player).onlyID==8)
end)

local function gatewayFixture()
	local clock, calls, noBudget = 0,0,false
	local values={}
	local raw={}
	local metadata={UserIds=nil,Metadata=nil}
	function raw:GetAsync(key,options) metadata.options=options; calls+=1; return values[key] end
	function raw:SetAsync(key,value) calls+=1; values[key]=value end
	function raw:UpdateAsync(key,transform)
		calls+=1
		local value,users,meta=transform(values[key],{GetUserIds=function() return {123} end,GetMetadata=function() return {source="old"} end})
		metadata.UserIds,metadata.Metadata=users,meta
		if value ~= nil then values[key]=value end
		return value
	end
	local service={GetDataStore=function() return raw end,GetGlobalDataStore=function() return raw end,GetOrderedDataStore=function() return raw end,
		GetRequestBudgetForRequestType=function() return if noBudget then 0 else 10 end}
	local utils={Log={warn=function() end},SystemGameConfig={GetValue=function(key) return if key=="DataStoreScope" then "test" else "PlayerData" end}}
	local env={
		game={ReplicatedFirst={AllSideCode={UtilsSystem="utils"}},GetService=function() return service end},
		script={StoreRegistry="registry",StoreKeys="keys",ValueGuard="guard"},
		require=function(name)
			if name=="utils" then return utils end
			if name=="guard" then return guard end
			return loadModule(sys .. "SystemDataStore/" .. (if name=="registry" then "StoreRegistry" else "StoreKeys") .. ".luau")
		end,
		Enum={DataStoreRequestType={StandardRead=1,StandardWrite=2,StandardRemove=3,OrderedRead=4,OrderedWrite=5,OrderedList=6,OrderedRemove=7}},
		os={clock=function() return clock end},task={wait=function(dt) clock+=dt end},Instance={new=function() return {} end}
	}
	return {store=loadModule(sys .. "SystemDataStore/init.luau",env),metadata=metadata,values=values,calls=function() return calls end,budget=function(v) noBudget=v end}
end

test("gateway preserves metadata, bypasses read cache and rejects oversized writes",function()
	local f=gatewayFixture()
	assert(f.store.Update("Player","K",function() return {value=1} end))
	assert(f.metadata.UserIds[1]==123 and f.metadata.Metadata.source=="old")
	assert(f.store.Get("Player","K",{fresh=true}))
	assert(f.metadata.options.UseCache==false)
	local before=f.calls()
	assert(not f.store.Set("Player","Big",string.rep("x",3800001)))
	assert(f.values.Big==nil and f.calls()==before)
end)

test("gateway budget waiting is bounded and resumes after budgets recover",function()
	local f=gatewayFixture()
	f.budget(true)
	local ok,_,err=f.store.Get("Player","K")
	assert(not ok and err=="STORE_BUDGET_TIMEOUT" and f.calls()==0)
	f.budget(false)
	assert(f.store.Set("Player","K",1))
end)


test("large configured gift rewards are not truncated by generic GM mail limits", function()
	local f=emailFixture()
	f.cfg.itemCount[1]=10000
	assert(f.save.ChangeStat(f.player,"GiftIntents",{["20"]={target=44}}))
	assert(f.buy.ProcessReceipt({PlayerId=123,ProductId=20,PurchaseId="Large"})=="granted")
	assert(f.storage["44"][1].Ex_Data.GrantSnapshot.itemCount[1]==10000)
	assert(not f.buy.CreateGrantSnapshot({OnlyTag="Bad",itemID={[1]=1,[3]=2},itemCount={1,2,3}}))
end)

test("comment deletion retries decrement once and tombstone blocks resurrection",function()
	local f=socialFixture()
	f.social.KickMigrateIfNeeded("V"); f.drain()
	local row={cid="C",videoId="V",text="hello",createdAt=100,likeCount=0}
	assert(f.social.AddComment("V",row))
	f.faults.after="Stats"
	assert(not f.social.DeleteComment("V","C",true))
	assert(f.stores.Body.C._deleted and f.stores.Stats.V.commentCount==0)
	assert(f.social.RepairComments("V"))
	assert(f.social.DeleteComment("V","C",true))
	assert(f.stores.Stats.V.commentCount==0)
	assert(f.social.AddComment("V",row))
	assert(f.stores.Body.C._deleted and f.social.GetCommentBody("C")==nil)
end)


test("archived transaction still deduplicates after leave and reacquisition; read errors fail closed",function()
	local f=fixture()
	assert(f.save.InitialPlayerData(f.player))
	assert(f.save.Transact(f.player,"seed",function(data)
		for index=1,600 do data._Transactions["mail:"..index]=1000 end
		return true
	end))
	f.env.task.spawn=function(fn) fn() end
	f.save.AutoSave()
	local moved
	for index=1,600 do if not f.storage.Player123._Transactions["mail:"..index] then moved="mail:"..index; break end end
	assert(moved and f.storage.Player123._ArchiveBuckets)
	assert(f.save.PlayerLeaveSave(f.player))
	assert(f.save.InitialPlayerData(f.player))
	local original=f.utils.SystemDataStore.Get
	f.utils.SystemDataStore.Get=function() return false,nil,"offline" end
	assert(not f.save.Transact(f.player,moved,function() error("must not grant") end))
	f.utils.SystemDataStore.Get=original
	local ok,reason=f.save.Transact(f.player,moved,function() error("must not replay") end)
	assert(ok and reason=="ALREADY_APPLIED")
end)

test("failed ChangeStat poisons outer draft even if callback ignores failure",function()
	local f=fixture()
	assert(f.save.InitialPlayerData(f.player))
	assert(not f.save.Transact(f.player,"bad-field",function(data)
		data.onlyID=2
		f.save.ChangeStat(f.player,"Unknown",123)
		return true
	end))
	assert(f.save.GetStat(f.player).onlyID==1)
end)

test("cached field size budget rejects aggregate overflow after whole-draft mutation",function()
	local f=fixture()
	assert(f.save.InitialPlayerData(f.player))
	assert(f.save.ChangeStat(f.player,"Record",{blob=string.rep("x",1800000)}))
	assert(f.save.Mutate(f.player,function(data) data.Code={blob=string.rep("x",1800000)}; return true end))
	assert(not f.save.ChangeStat(f.player,"Setting",{blob=string.rep("x",200000)}))
	assert(f.save.ChangeStat(f.player,"Record",{}))
	assert(f.save.ChangeStat(f.player,"Setting",{blob=string.rep("x",200000)}))
end)
print("All regression tests passed:",passed)
