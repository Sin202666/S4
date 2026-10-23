--[[
	Module: ArmWrestleTutorial
	Description: 扳手腕引导条入口，转发 ArmWrestleHUD
	Author: 程莘
	Created: 2026-10-14
	Last Modified: 2026-10-14
]]

local HUD = require(script.Parent.ArmWrestleHUD)
local ArmWrestleTutorial = {}

function ArmWrestleTutorial:openUi()
	HUD:openUi()
	HUD.RefreshHud()
end

function ArmWrestleTutorial:closeUi()
	HUD:closeUi()
end

function ArmWrestleTutorial:updateUi()
	HUD.RefreshHud()
end

return ArmWrestleTutorial
