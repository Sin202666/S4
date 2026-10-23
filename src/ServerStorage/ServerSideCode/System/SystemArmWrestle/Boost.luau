--[[
	Module: Boost
	Description: 扳手腕现金加成：同服好友加成与 Roblox 会员加成（仅会话，不落存档）
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-14

	功能：
	- 同服好友：进服时对服内其他玩家逐一 IsFriendsWith，好友关系双向记入双方会话；离服时从对方会话移除
	- 会员：读 Player.MembershipType；中途订阅经 Players.PlayerMembershipChanged 刷新
	- GetCashMult：(1 + 好友加成) × (1 + 会员加成)，由 Profile.GetMults 唯一消费
	- GetFriendPercent / GetPremiumPercent：整数百分比，供 Profile.Sync 写界面镜像

	约束：
	- 好友与会员身份只由服务端经 Roblox API 判定，客户端不上报任何加成数据
	- IsFriendsWith 会 yield 且可能失败：在独立线程 pcall，失败按非好友处理
	- 本模块不写 Attribute；加成变化后调 Bind 注入的 onChanged，由调用方重同步镜像
	- 数值见 ArmWrestleConfig.FRIEND_BOOST_PER / FRIEND_BOOST_MAX / PREMIUM_BOOST

	加载：
		local Boost = require(script.Boost)
		Boost.Bind({ onChanged = function(plr) ... end })   -- SystemArmWrestle.Init 调一次
		Boost.SetupPlayer(plr)                              -- 入服
		Boost.OnPlayerRemoving(plr)                         -- 离服
		local mult = Boost.GetCashMult(plr)                 -- 例：2 位好友 + 会员 = 1.2 × 1.25 = 1.5
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local Players = Utils.Players
local ArmWrestleConfig = Utils.ArmWrestleConfig
local Log = Utils.Log

local Boost = {}

local FRIEND_BOOST_PER = ArmWrestleConfig.FRIEND_BOOST_PER
local FRIEND_BOOST_MAX = ArmWrestleConfig.FRIEND_BOOST_MAX
local PREMIUM_BOOST = ArmWrestleConfig.PREMIUM_BOOST
local PERCENT = 100

local _friends: { [Player]: { [Player]: boolean } } = {}
local _premium: { [Player]: boolean } = {}
local _onChanged: ((Player) -> ())? = nil
local _membershipConn: RBXScriptConnection? = nil

--[[
	通知调用方加成已变化（玩家已离服则跳过）
	@param plr Player - 加成变化的玩家
	@return nil - 无返回值
]]
local function _notify(plr: Player)
	local onChanged = _onChanged
	if onChanged and plr.Parent and _friends[plr] then
		onChanged(plr)
	end
end

--[[
	查询两名玩家是否为 Roblox 好友（会 yield）
	@param plr Player - 发起查询的玩家
	@param other Player - 对方玩家
	@return boolean - 是好友为 true；查询失败按 false 处理
]]
local function _isFriend(plr: Player, other: Player): boolean
	local ok, result = pcall(plr.IsFriendsWith, plr, other.UserId)
	if not ok then
		Log.warn("SystemArmWrestle.Boost IsFriendsWith 失败", plr.UserId, other.UserId, result)
		return false
	end
	return result == true
end

--[[
	好友加成比例（未封顶前按人数线性累加）
	@param plr Player - 玩家
	@return number - 0 ~ FRIEND_BOOST_MAX 的小数，如 0.2 表示 +20%
]]
local function _friendBoost(plr: Player): number
	local set = _friends[plr]
	if not set then
		return 0
	end
	local count = 0
	for _ in pairs(set) do
		count += 1
	end
	return math.min(count * FRIEND_BOOST_PER, FRIEND_BOOST_MAX)
end

--[[
	会员加成比例
	@param plr Player - 玩家
	@return number - 会员为 PREMIUM_BOOST，否则 0
]]
local function _premiumBoost(plr: Player): number
	return if _premium[plr] then PREMIUM_BOOST else 0
end

--[[
	扫描服内已建会话的其他玩家，双向记录好友关系；yield 期间任一方离服则跳过该对
	@param plr Player - 刚入服的玩家
	@return nil - 无返回值
]]
local function _scanFriends(plr: Player)
	local changed = false
	for _, other in ipairs(Players:GetPlayers()) do
		if other == plr or not _friends[other] then
			continue
		end
		local isFriend = _isFriend(plr, other)
		local mine, theirs = _friends[plr], _friends[other]
		if isFriend and mine and theirs then
			mine[other] = true
			theirs[plr] = true
			changed = true
			_notify(other)
		end
	end
	if changed then
		_notify(plr)
	end
end

--[[
	按 MembershipType 刷新会员状态，变化时通知
	@param plr Player - 玩家
	@return nil - 会话未建立时跳过
]]
local function _refreshPremium(plr: Player)
	if not _friends[plr] then
		return
	end
	local isPremium = plr.MembershipType == Enum.MembershipType.Premium
	if _premium[plr] == isPremium then
		return
	end
	_premium[plr] = isPremium
	_notify(plr)
end

--[[
	注入依赖并监听会员变化（SystemArmWrestle.Init 调一次，重复调用只更新回调）
	@param deps table - { onChanged: (Player) -> () }；加成变化时回调，用于重同步 CashMult / FriendBoost / PremiumBoost 镜像
	@return nil - 无返回值
]]
function Boost.Bind(deps: { onChanged: (Player) -> () })
	_onChanged = deps.onChanged
	if _membershipConn then
		return
	end
	_membershipConn = Players.PlayerMembershipChanged:Connect(_refreshPremium)
end

--[[
	入服建会话：立即写会员状态，后台扫描同服好友（扫描完成后经 onChanged 通知）
	@param plr Player - 入服玩家
	@return nil - 无返回值
]]
function Boost.SetupPlayer(plr: Player)
	_friends[plr] = {}
	_premium[plr] = plr.MembershipType == Enum.MembershipType.Premium
	task.spawn(_scanFriends, plr)
end

--[[
	离服清理：从其好友的会话中移除并通知对方刷新加成
	@param plr Player - 离服玩家
	@return nil - 无返回值
]]
function Boost.OnPlayerRemoving(plr: Player)
	local set = _friends[plr]
	_friends[plr] = nil
	_premium[plr] = nil
	if not set then
		return
	end
	for other in pairs(set) do
		local theirs = _friends[other]
		if theirs then
			theirs[plr] = nil
			_notify(other)
		end
	end
end

--[[
	现金加成总倍率（好友与会员独立相乘）
	@param plr Player - 玩家
	@return number - ≥ 1 的倍率；无会话为 1
]]
function Boost.GetCashMult(plr: Player): number
	return (1 + _friendBoost(plr)) * (1 + _premiumBoost(plr))
end

--[[
	好友加成百分比（界面镜像用）
	@param plr Player - 玩家
	@return number - 整数百分比，如 20 表示 +20%
]]
function Boost.GetFriendPercent(plr: Player): number
	return math.floor(_friendBoost(plr) * PERCENT + 0.5)
end

--[[
	会员加成百分比（界面镜像用）
	@param plr Player - 玩家
	@return number - 会员为 25（按配置），否则 0
]]
function Boost.GetPremiumPercent(plr: Player): number
	return math.floor(_premiumBoost(plr) * PERCENT + 0.5)
end

return Boost
