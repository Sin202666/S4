--[[
	Module: Economy
	Description: 扳手腕力量倍数/力量包/药水发货、通行证镜像与 Studio 发货
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-16

	不设置 ProcessReceipt。线上商品 passID=0 时仅 Studio DevGrant；
	真实 Id 由 SystemBuyRoblox.ProcessReceipt 按 ItemShopData 快照调 GrantProduct（经 SystemArmWrestle.GrantReceiptProduct），
	因此 GrantProduct 内的提示、镜像同步一律经 SystemSave.AfterCommit，事务失败时不执行。
	价格/奖励货币为背包金币；涉及金币的写档一律经 _commit（Profile.Commit 原子提交）。
	药水购买走商城 Items 发货（itemID 201~203）；使用与计时在 Potion 子模块。
	通行证落档：SystemShop.BuyGamePassSuc 写 data.GamePass[OnlyTag]；拥有判定读 GamePass NumberValue（GetData.IsHasPass）。
	手臂、材质、哑铃、升级垫、材质机、关卡传送已下线，对应 Action 不再受理。
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local RunService = Utils.RunService
local ArmWrestleConfig = Utils.ArmWrestleConfig
local CfgFind = Utils.CfgFind
local EnumMgr = Utils.EnumMgr
local GetData = Utils.GetData
local TipsModule = Utils.TipsModule
local SystemSave = Utils.SystemSave
local SystemBag = Utils.SystemBag
local SystemShop = Utils.SystemShop
local Log = Utils.Log

local Profile = require(script.Parent.Profile)

local Economy = {}

local IS_STUDIO = RunService:IsStudio()

local _afterChange: ((Player, { [string]: any }, boolean) -> ())?
local _passWatch: { [Player]: { RBXScriptConnection } } = {}

--[[
	是否拥有通行证（GamePass 文件夹 NumberValue，与 SystemShop 落档一致）
	@param plr Player - 玩家
	@param key string - AutoClicker 等（ItemShopData.OnlyTag）
	@return boolean
]]
function Economy.HasPass(plr: Player, key: string): boolean
	return GetData.IsHasPass(plr, key)
end

--[[
	已拥有通行证表（按 GamePassOrder 现查 NumberValue；调用方勿长期持有）
	@param plr Player - 玩家
	@return table
]]
function Economy.GetPasses(plr: Player): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, key in ipairs(ArmWrestleConfig.GamePassOrder) do
		if GetData.IsHasPass(plr, key) then
			owned[key] = true
		end
	end
	return owned
end

--[[
	注入依赖
	@param deps table - { afterChange: 写档后同步回调 }
]]
function Economy.Bind(deps: {
	afterChange: (Player, { [string]: any }, boolean) -> (),
})
	_afterChange = deps.afterChange
end

--[[
	金币变动 + 写档原子提交；成功同步镜像，失败用存档真值回滚镜像
	@param plr Player - 玩家
	@param data table - 已原地修改的档案
	@param coinDelta number - 金币增减（负数为扣除）
	@return boolean - 是否成功
]]
local function _commit(plr: Player, data: { [string]: any }, coinDelta: number): boolean
	local afterChange = _afterChange
	if not afterChange then
		return false
	end
	if Profile.Commit(plr, data, coinDelta) then
		SystemSave.AfterCommit(plr, function()
			afterChange(plr, data, false)
		end)
		return true
	end
	local fresh = Profile.Get(plr)
	if fresh then
		SystemSave.AfterCommit(plr, function()
			afterChange(plr, fresh, false)
		end)
	end
	return false
end

--[[
	发货（Studio DevGrant 或收据事务内调用）；已拥有的力量倍数档按空操作成功处理，保证收据可被确认
	@param plr Player - 玩家
	@param key string - 商品键（ArmWrestleConfig._PRODUCTS 的键）
	@return boolean - 成功（含重复档空操作）为 true；档案未就绪/配置缺失/写档失败/已下线种类为 false
]]
function Economy.GrantProduct(plr: Player, key: string): boolean
	local data = Profile.Get(plr)
	local product = ArmWrestleConfig.GetProduct(key)
	if not data or not product or not _afterChange then
		return false
	end
	local coinDelta = 0
	local notify: () -> ()
	if product.Kind == "StrengthTier" then
		if (data.StrengthTier or 0) >= product.Tier then
			Log.warn("SystemArmWrestle.Economy 重复购买已拥有力量倍数档", plr.UserId, key, data.StrengthTier)
			return true
		end
		-- 跳档购买直接升到该档，不回退、不叠乘
		data.StrengthTier = product.Tier
		notify = function()
			TipsModule.NormalTips(plr, "力量倍数提升", { tostring(product.Mult) })
		end
	elseif product.Kind == "Cash" then
		coinDelta = math.floor(product.Amount or 0)
		if coinDelta <= 0 then
			return false
		end
		notify = function()
			TipsModule.NormalTips(plr, "获得现金", { ArmWrestleConfig.Format(coinDelta) })
		end
	elseif product.Kind == "Strength" then
		local perClick = select(1, Profile.GetMults(plr, data, Economy.GetPasses(plr)))
		local amt = perClick * (product.Amount or 0)
		Profile.AddStrength(plr, data, amt, Economy.GetPasses(plr))
		notify = function()
			TipsModule.NormalTips(plr, "获得力量", { ArmWrestleConfig.Format(amt) })
		end
	elseif product.Kind == "Potion" then
		local potion = ArmWrestleConfig.GetPotion(product.PotionKey)
		local count = product.Count or 0
		if not potion or count <= 0 then
			return false
		end
		-- 药水库存只在背包；档案不变，不走 _commit
		local added = SystemBag.AddItems(plr, { potion.ItemId }, { count })
		if not added then
			return false
		end
		SystemSave.AfterCommit(plr, function()
			TipsModule.NormalTips(plr, "获得药水", { { potion.ZhName }, tostring(count) })
		end)
		return true
	else
		return false
	end
	if not _commit(plr, data, coinDelta) then
		return false
	end
	SystemSave.AfterCommit(plr, notify)
	return true
end

--[[
	授予通行证并落档（Studio DevGrant / 补发）；线上购买由 SystemBuyRoblox → SystemShop
	@param plr Player - 玩家
	@param key string - 通行证 OnlyTag（AutoClicker / DoubleStrength / DoubleCash）
	@param silent boolean? - true 时不弹「解锁通行证」提示，默认 false
]]
function Economy.GrantPass(plr: Player, key: string, silent: boolean?)
	local cfg = CfgFind.FindCfgByOnlyTag(key)
	if not cfg or cfg.cost ~= EnumMgr.RobuxType.GamePass then
		return
	end
	local passID = tonumber(cfg.passID)
	if not passID or passID <= 0 then
		return
	end
	local ok = select(1, SystemShop.BuyGamePassSuc(plr, passID))
	if not ok then
		return
	end
	local pass = ArmWrestleConfig.GetGamePass(key)
	if pass and not silent then
		TipsModule.NormalTips(plr, "解锁通行证", { pass.ZhName })
	end
	local data = Profile.Get(plr)
	if data and _afterChange then
		_afterChange(plr, data, false)
	end
end

--[[
	通行证 NumberValue / 落档变化后刷新 OwnedPasses 等镜像（供 SystemBuyRoblox 购买成功回调）
	@param plr Player - 玩家
]]
function Economy.RefreshPassMirror(plr: Player)
	local data = Profile.Get(plr)
	if data and _afterChange then
		_afterChange(plr, data, false)
	end
end

--[[
	客户端 Action。已下线的购买/装备/传送不再受理，只保留 Studio DevGrant
	@param plr Player - 玩家
	@param action string - 动作名：DevGrant
	@param ... any - DevGrant 的 kind 与 key
	@return any - 结果：成功 true；失败 false 与可选失败码 studio
]]
function Economy.OnAction(plr: Player, action: string, ...: any): any
	if action ~= "DevGrant" then
		return false
	end
	if not IS_STUDIO then
		return false, "studio"
	end
	local kind, key = ...
	if kind == "Pass" and ArmWrestleConfig.GetGamePass(key) then
		Economy.GrantPass(plr, key)
		return Economy.HasPass(plr, key)
	elseif kind == "Product" then
		local product = ArmWrestleConfig.GetProduct(key)
		if not product then
			return false
		end
		-- 有 Kind 走扳手腕发货；药水等无 Kind 走商城 Items 快照
		if type(product.Kind) == "string" and product.Kind ~= "" then
			return Economy.GrantProduct(plr, key)
		end
		-- 延迟取用：SystemBuyRoblox 与本模块经收据发货互相引用
		local SystemBuyRoblox = Utils.SystemBuyRoblox
		local ok = select(1, SystemBuyRoblox.BuyItemEnd(plr, key))
		return ok == true
	end
	return false
end

--[[
	监听通行证 NumberValue，变化后刷新镜像
	@param plr Player - 玩家
]]
local function _watchPassValues(plr: Player)
	local folder = plr:FindFirstChild(EnumMgr.PlayerInst.GamePassFolder)
	if not folder then
		return
	end
	local conns: { RBXScriptConnection } = {}
	for _, key in ipairs(ArmWrestleConfig.GamePassOrder) do
		local nv = folder:FindFirstChild(key)
		if nv and nv:IsA("NumberValue") then
			table.insert(conns, nv.Changed:Connect(function()
				Economy.RefreshPassMirror(plr)
			end))
		end
	end
	_passWatch[plr] = conns
end

--[[
	入服会话：绑定通行证镜像；落档补发由 SystemShop.Init（UserOwnsGamePassAsync）负责
	@param plr Player - 玩家
]]
function Economy.SetupPlayer(plr: Player)
	plr:SetAttribute("AutoOn", false)
	_watchPassValues(plr)
	task.defer(function()
		Economy.RefreshPassMirror(plr)
	end)
end

--[[
	离场清理
	@param plr Player - 玩家
]]
function Economy.OnPlayerRemoving(plr: Player)
	local conns = _passWatch[plr]
	if conns then
		for _, conn in ipairs(conns) do
			conn:Disconnect()
		end
		_passWatch[plr] = nil
	end
end

return Economy
