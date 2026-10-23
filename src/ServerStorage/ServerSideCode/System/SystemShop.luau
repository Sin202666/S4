--[[
	Module: SystemShop
	Description: GamePass 发货与拥有标记同档原子提交；Init 查询平台拥有状态并补发。
	Author: 林奥宇
	Last Modified: 2026-10-12
	Created: 2026-10-12
]]

-- ========================================
-- 服务引用
-- ========================================
local MarketplaceService = game:GetService("MarketplaceService")

-- ========================================
-- 模块引用
-- ========================================
local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local PlayerData = Utils.PlayerData
local SystemBag = Utils.SystemBag
local SystemSave = Utils.SystemSave
local CfgFind = Utils.CfgFind
local InsMgr = Utils.InsMgr
local EnumMgr = Utils.EnumMgr
local Log = Utils.Log

-- ========================================
-- 模块定义
-- ========================================
local SystemShop = {}

-- ========================================
-- 常量定义
-- ========================================
local ITEMSHOP_CFG = CfgFind.GetCfgByName("itemshopdataConf")
local ROBUX_TYPE_GAMEPASS = EnumMgr.RobuxType.GamePass
local GAMEPASS_FOLDER_NAME = EnumMgr.PlayerInst.GamePassFolder
local GAMEPASS_OWNED = 1
local ShopErr = EnumMgr.ShopErr

-- ========================================
-- 私有函数
-- ========================================

--[[
	获取玩家商店购买记录表
	@param _plr Player - 目标玩家；须已加载存档
	@return table? - plrData.Shop；键为 goodsID 字符串，值为该商品购买记录表
]]
local function _getShopData(_plr: Player): { [string]: any }?
	local plrData = PlayerData.GetPlrData(_plr)
	if plrData then
		return plrData.Shop
	end
	return nil
end

--[[
	获取玩家 GamePass 存档表
	@param _plr Player - 目标玩家；须已加载存档
	@return table? - plrData.GamePass；键为 OnlyTag 字符串，值为 1 表示已拥有
]]
local function _getGamePassData(_plr: Player): { [string]: number }?
	local plrData = PlayerData.GetPlrData(_plr)
	if not plrData then
		return nil
	end
	return plrData.GamePass
end

--[[
	获取或创建玩家下的 GamePass 同步文件夹
	@param _plr Player - 目标玩家
	@return Folder - 名为 EnumMgr.PlayerInst.GamePassFolder 的 Folder，其下挂各 OnlyTag 对应 NumberValue
]]
local function _getGamePassFolder(_plr: Player): Folder
	local gamePassFolder: Folder? = _plr:FindFirstChild(GAMEPASS_FOLDER_NAME) :: Folder?
	if not gamePassFolder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = GAMEPASS_FOLDER_NAME
		newFolder.Parent = _plr
		return newFolder :: Folder
	end
	return gamePassFolder :: Folder
end

--[[
	把已拥有标记同步到 Player 镜像 Folder 下对应 NumberValue
	@param _plr Player - 目标玩家
	@param onlyTag string - 商品 OnlyTag，对应 NumberValue.Name
	@return nil
]]
local function _syncPassValue(_plr: Player, onlyTag: string)
	local gamePassFolder = _getGamePassFolder(_plr)
	local passValue: NumberValue? = gamePassFolder:FindFirstChild(onlyTag) :: NumberValue?
	if passValue then
		passValue.Value = GAMEPASS_OWNED
	end
end

--[[
	从商城配置收集待发放物品
	@param cfg table - itemshopdataConf 行；字段 itemID / itemCount 为平行数组
	@return {number}, {number} - 物品 ID 列表与对应数量列表（已跳过 itemId == 0）
]]
local function _collectGrantItems(cfg: any): ({ number }, { number })
	local ids: { number } = {}
	local counts: { number } = {}
	local itemIds = cfg and cfg.itemID
	if type(itemIds) ~= "table" then
		return ids, counts
	end
	local itemCounts = cfg.itemCount
	for k, itemId in pairs(itemIds) do
		if itemId ~= 0 then
			table.insert(ids, itemId)
			table.insert(counts, itemCounts and itemCounts[k])
		end
	end
	return ids, counts
end

--[[
	向 Roblox 查询玩家是否拥有指定 GamePass
	@param userId number - 玩家 UserId
	@param gamePassId number - Roblox GamePass 资产 ID
	@return boolean - 查询成功且已拥有为 true；查询失败或未拥有为 false
]]
local function _userOwnsGamePass(userId: number, gamePassId: number): boolean
	local success, hasPass = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, userId, gamePassId)
	if not success then
		Log.warn("UserOwnsGamePassAsync failed:", userId, gamePassId, hasPass)
		return false
	end
	return hasPass == true
end

-- ========================================
-- 公共函数
-- ========================================

--[[
	重置指定商品的购买记录。仓内无调用方，保留作运营重置写口。
	@param _plr Player - 目标玩家
	@param goodsID number - itemshopdataConf 商品 ID
	@return boolean, string? - 成功 true；失败 false 与 ShopErr.NoData / InvalidParam / NotFound / SaveFailed
]]
function SystemShop.ResetItemByID(_plr: Player, goodsID: number): (boolean, string?)
	local shopData = _getShopData(_plr)
	if not shopData then
		return false, ShopErr.NoData
	end

	local numGoodsID = tonumber(goodsID)
	if not numGoodsID then
		return false, ShopErr.InvalidParam
	end

	local goodsKey = tostring(numGoodsID)
	if not shopData[goodsKey] then
		return false, ShopErr.NotFound
	end

	local ok, err = PlayerData.ChangePlrData(_plr, { "Shop", goodsKey }, nil)
	if not ok then
		Log.warn("SystemShop: ResetItemByID 写存档失败", _plr.UserId, goodsKey, err)
		return false, ShopErr.SaveFailed
	end

	return true
end

--[[
	清空玩家全部商店购买记录。仓内无调用方，保留作运营重置写口。
	@param _plr Player - 目标玩家
	@return boolean, string? - 成功 true；失败 false 与 ShopErr.NoData / SaveFailed
]]
function SystemShop.ResetAll(_plr: Player): (boolean, string?)
	if not _getShopData(_plr) then
		return false, ShopErr.NoData
	end

	local ok, err = PlayerData.ChangePlrData(_plr, "Shop", {})
	if not ok then
		Log.warn("SystemShop: ResetAll 写存档失败", _plr.UserId, err)
		return false, ShopErr.SaveFailed
	end

	return true
end

--[[
	GamePass 发奖：奖励与拥有标记同档提交，再同步 NumberValue（幂等，已拥有不重复发奖）
	@param _plr Player - 目标玩家
	@param passID number - itemshopdataConf 中配置的 Roblox GamePass ID
	@return boolean, string? - 成功 true（含已拥有）；失败 false 与 ShopErr.InvalidParam / ConfigNotFound / NoData / GrantFailed / SaveFailed
]]
function SystemShop.BuyGamePassSuc(_plr: Player, passID: number, frozenConfig: any?): (boolean, string?)
	local numPassID = tonumber(passID)
	if not numPassID then
		Log.warn("无效的通行证ID:", passID)
		return false, ShopErr.InvalidParam
	end

	local cfg = frozenConfig or CfgFind.FindCfgByPassID(numPassID)
	if not cfg then
		Log.warn("没有这个通行证配置:", numPassID)
		return false, ShopErr.ConfigNotFound
	end

	return SystemSave.Transact(_plr, "gamepass:" .. tostring(numPassID), function(data)
		if not data.GamePass[cfg.OnlyTag] then
			local ids, counts = _collectGrantItems(cfg)
			if #ids > 0 then
				local ok, err = SystemBag.AddItems(_plr, ids, counts)
				if not ok then return false, err end
			end
			data.GamePass[cfg.OnlyTag] = GAMEPASS_OWNED
		end
		SystemSave.AfterCommit(_plr, function() _syncPassValue(_plr, cfg.OnlyTag) end)
		return true
	end)
end

--[[
	入服时创建 GamePass NumberValue 并按存档恢复已购状态
	@param _plr Player - 目标玩家；由 PlayerManager 在 InitialPlayerData 之后同步调用
	@return nil
]]
function SystemShop.InitValue(_plr: Player)
	local gamePassFolder = _getGamePassFolder(_plr)
	local gamePassData = _getGamePassData(_plr)
	if not ITEMSHOP_CFG then
		return
	end

	for _, cfg in pairs(ITEMSHOP_CFG) do
		if cfg.OnlyTag and cfg.OnlyTag ~= "" then
			InsMgr.GetIns(cfg.OnlyTag, "NumberValue", gamePassFolder)
			if gamePassData and gamePassData[cfg.OnlyTag] == GAMEPASS_OWNED then
				_syncPassValue(_plr, cfg.OnlyTag)
			end
		end
	end
end

--[[
	异步向 Roblox 查询 GamePass 拥有情况并补发（含 passID_old 旧版 ID 兼容）
	@param _plr Player - 目标玩家；由 PlayerManager 在 task.spawn 中调用，不阻塞入服主链
	@return nil
]]
function SystemShop.Init(_plr: Player)
	if not ITEMSHOP_CFG then
		return
	end

	for _, cfg in pairs(ITEMSHOP_CFG) do
		if cfg.passID ~= 0 and cfg.cost == ROBUX_TYPE_GAMEPASS then
			local gamePassID = cfg.passID
			local owned = _userOwnsGamePass(_plr.UserId, gamePassID)
				or (cfg.passID_old and _userOwnsGamePass(_plr.UserId, cfg.passID_old))
			if owned then
				local ok, err = SystemShop.BuyGamePassSuc(_plr, gamePassID)
				if not ok then
					Log.warn("SystemShop: Init 补发失败", _plr.UserId, gamePassID, err)
				end
			end
		end
	end
end

return SystemShop
