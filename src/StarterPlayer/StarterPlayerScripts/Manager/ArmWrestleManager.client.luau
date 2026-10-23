--[[
	Module: ArmWrestleManager
	Description: 客户端扳手腕启动编排，只调 SystemArmWrestle.Init
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-14

	本文件为 LocalScript，由引擎自动运行；禁止被 require。
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemArmWrestle = Utils.SystemArmWrestle

SystemArmWrestle.Init()
