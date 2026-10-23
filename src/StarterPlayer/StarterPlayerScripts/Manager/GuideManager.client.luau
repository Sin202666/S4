--[[
	Module: GuideManager
	Description: 客户端新手引导启动编排，只调 SystemGuide.Init
	Author: 程莘
	Created: 2026-10-15
	Last Modified: 2026-10-15

	本文件为 LocalScript，由引擎自动运行；禁止被 require。
]]

local Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)
local SystemGuide = Utils.SystemGuide

SystemGuide.Init()
