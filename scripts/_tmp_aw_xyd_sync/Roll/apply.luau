local parts = _G.__AW_XYD_PARTS
assert(type(parts) == "table" and #parts > 0, "no parts")
local b64 = table.concat(parts)
local src = game:GetService("HttpService"):Base64Decode(b64)
local m = game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Roll
m.Source = src
_G.__AW_XYD_PARTS = nil
return (#src) .. " bytes -> " .. m:GetFullName()
