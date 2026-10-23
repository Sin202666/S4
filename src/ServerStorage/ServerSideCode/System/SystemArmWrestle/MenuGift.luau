--[[
	Module: MenuGift
	Description: 扳手腕菜单挽留礼物：玩家关闭 Roblox 菜单后弹窗挽留，免费领一次现金（每账号永久一次），服务端结算
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-16

	规则：
	- 金额 = ArmWrestleConfig.MENU_GIFT_CASH（固定现金），与关卡进度无关
	- 档案 MenuGiftClaimed 为 true 后永久不可再领；发现金与写标记经 commit（Profile.Commit）同一 Mutate 原子提交
	- 客户端何时弹窗（GuiService.MenuOpened / MenuClosed）只影响展示；领取请求不带参数，
	  不依赖客户端是否真的打开过菜单，次数只由本模块按档案把关

	客户端镜像（SyncAttributes，由 init 的 _afterChange 调用）：
	- MenuGiftClaimed：是否已领；false 时客户端在关闭 Roblox 菜单后弹挽留窗
	- MenuGiftCash：固定可领现金（仅展示，结算以 Claim 为准）

	与相关模块：
	- 只改档案字段 MenuGiftClaimed 与背包金币，写回经 Bind 注入的 commit（带金币增量的原子提交并同步镜像）
	- 领取请求经 ARM_WRESTLE_ACTION 的 "ClaimMenuGift" 动作，由 init._dispatchAction 分发
	- 客户端弹窗见 ArmWrestleHUD.MenuGift

	加载：
		local MenuGift = require(script.MenuGift)
		MenuGift.Bind({ commit = _commitProfile })
		MenuGift.SyncAttributes(plr, data)     -- _afterChange
		local ok, amount = MenuGift.Claim(plr)  -- Action "ClaimMenuGift"
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local ArmWrestleConfig = Utils.ArmWrestleConfig
local TipsModule = Utils.TipsModule

local Profile = require(script.Parent.Profile)

local MenuGift = {}

local ERR_CLAIMED = "claimed"
local ERR_NOT_READY = "notReady"
local ATTR_CLAIMED = "MenuGiftClaimed"
local ATTR_CASH = "MenuGiftCash"
local GIFT_CASH = ArmWrestleConfig.MENU_GIFT_CASH

-- 领取进行中的玩家：commit 若让出线程，同一玩家的并发请求不得重复读到未领状态
local _claiming: { [Player]: boolean } = {}
local _commit: ((Player, { [string]: any }, number?) -> boolean)?

--[[
	注入档案写回依赖（SystemArmWrestle.Init 调一次）
	@param deps table - { commit: (Player, table, number?) -> boolean 档案与金币增量原子写回并同步镜像 }
	@return nil
]]
function MenuGift.Bind(deps: { commit: (Player, { [string]: any }, number?) -> boolean })
	_commit = deps.commit
end

--[[
	可领现金（固定值，与档案进度无关）
	@param _data table - ArmWrestle 档案（保留参数以兼容 SyncAttributes）
	@return number - 可领现金
]]
function MenuGift.GetCash(_data: { [string]: any }): number
	return GIFT_CASH
end

--[[
	同步挽留礼物镜像 Attribute（MenuGiftClaimed 是否已领 / MenuGiftCash 预估现金），仅供界面展示
	@param plr Player - 玩家
	@param data table - ArmWrestle 档案
	@return nil
]]
function MenuGift.SyncAttributes(plr: Player, data: { [string]: any })
	plr:SetAttribute(ATTR_CLAIMED, data.MenuGiftClaimed == true)
	plr:SetAttribute(ATTR_CASH, MenuGift.GetCash(data))
end

--[[
	领取挽留礼物：按当下进度发现金并永久标记已领，经 commit 原子写回；写档失败不标记，可重试
	@param plr Player - 玩家（来自 Remote，客户端不传任何参数）
	@return boolean - 成功为 true
	@return any - 成功时为本次获得的现金 number；失败时为失败码 string：claimed 已领过 / notReady 会话未就绪、金额为 0 或写档失败
]]
function MenuGift.Claim(plr: Player): (boolean, any)
	local commit = _commit
	if not commit or _claiming[plr] then
		return false, ERR_NOT_READY
	end
	local data = Profile.Get(plr)
	if not data then
		return false, ERR_NOT_READY
	end
	if data.MenuGiftClaimed == true then
		return false, ERR_CLAIMED
	end
	local amount = MenuGift.GetCash(data)
	if amount <= 0 then
		return false, ERR_NOT_READY
	end
	data.MenuGiftClaimed = true
	_claiming[plr] = true
	local ok = commit(plr, data, amount)
	_claiming[plr] = nil
	if not ok then
		return false, ERR_NOT_READY
	end
	TipsModule.NormalTips(plr, "获得现金", { ArmWrestleConfig.Format(amount) })
	return true, amount
end

--[[
	离场释放会话标记
	@param plr Player - 玩家
	@return nil
]]
function MenuGift.Unload(plr: Player)
	_claiming[plr] = nil
end

return MenuGift
