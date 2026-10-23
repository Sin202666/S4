--[[
	Module: ArmWrestlePotion
	Description: 背包 / 快捷栏使用扳手腕药水的 UseScript（itemdataConf.UseScript = "ArmWrestlePotion"）
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	契约（BagUseItem）：
	- Transactional = true；Use 在 BagUseItem 的 SystemSave.Transact 内被调用，背包扣除已由 BagUseItem 完成
	- 无 yield；返回 true,payload / false,error；返回 false 时整笔事务回滚（药水不扣、计时不加）

	与相关模块：
	- 只延长计时，经 SystemArmWrestle.ApplyPotionItem → Potion.Apply（与商城按钮使用共用同一计时入口）
	- parms[1] 为药水键（StrengthPotion / TrainSpeedPotion / CashPotion），须与 ArmWrestleConfig._POTIONS 的 ItemId 对应

	加载：BagUseItem 预加载 ServerStorage.ServerSideCode.ItemScript 下全部 ModuleScript，按 UseScript 名索引
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)

local ArmWrestlePotion = {}

ArmWrestlePotion.Transactional = true

local ERR_INVALID_PARMS = "INVALID_POTION_PARMS"

--[[
	使用药水：按瓶数延长对应药水的在线计时
	@param plr Player - 使用玩家
	@param parms {string} - itemdataConf.parms，[1] 为药水键
	@param useCount number - 本次使用瓶数（BagUseItem 已校验为正整数）
	@return boolean - 计时已写入事务为 true
	@return string? - 失败码：INVALID_POTION_PARMS 配置缺药水键 / SystemArmWrestle.ApplyPotionItem 返回的失败码
]]
function ArmWrestlePotion.Use(plr: Player, parms: { string }, useCount: number): (boolean, string?)
	local key = type(parms) == "table" and parms[1] or nil
	if type(key) ~= "string" or key == "" then
		return false, ERR_INVALID_PARMS
	end
	-- 延迟取用：BagUseItem 在 SystemBag 加载期就 require 本脚本，而 SystemArmWrestle 依赖 SystemBag，顶部取会循环 require
	return Utils.SystemArmWrestle.ApplyPotionItem(plr, key, useCount)
end

return ArmWrestlePotion
