--[[
	Module: studio_preflight
	Description: 在目标模板 Studio 编辑模式的命令栏运行；只读资源与工程身份，不启动游戏、不访问存档
	Author: 林奥宇
	Created: 2026-10-12
	Last Modified: 2026-10-12
]]
local expectedPlaceId = 135608499142380
local required = {
	{ "ReplicatedFirst.PreloadGui", "ScreenGui" },
	{ "ReplicatedFirst.PreloadGui_Teleport", "ScreenGui" },
	{ "ReplicatedFirst.AllSideCode.UtilsSystem", "ModuleScript" },
	{ "ReplicatedStorage.Assets", "Folder" },
	{ "ReplicatedStorage.Msg.RemoteEvent.NetWorkRemoteEvent", "RemoteEvent" },
	{ "ReplicatedStorage.Msg.RemoteEvent.NetWorkRemoteEvent_Skill", "RemoteEvent" },
	{ "ReplicatedStorage.Msg.RemoteFunction.NetWorkRemoteFunction", "RemoteFunction" },
	{ "ReplicatedStorage.Msg.Event.NetWorkEvent", "BindableEvent" },
	{ "ReplicatedStorage.Msg.Function.NetWorkBindableFunction", "BindableFunction" },
	{ "ServerStorage.ServerSideCode.System.SystemSave", "ModuleScript" },
	{ "SoundService.UI", nil },
}
local missing = {}
for _, requirement in ipairs(required) do
	local current = game
	for part in string.gmatch(requirement[1], "[^.]+") do
		current = current and current:FindFirstChild(part)
	end
	if not current or (requirement[2] and not current:IsA(requirement[2])) then table.insert(missing, requirement[1]) end
end
local result = { placeId = game.PlaceId, expectedPlaceId = expectedPlaceId, matchesPlace = game.PlaceId == expectedPlaceId, missing = missing }
print(game:GetService("HttpService"):JSONEncode(result))
return result
