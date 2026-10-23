local parent = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle
local m = parent:FindFirstChild("BattlePose")
if not m then
	m = Instance.new("ModuleScript")
	m.Name = "BattlePose"
	m.Parent = parent
end
local Hs = game:GetService("HttpService")
m.Source = Hs:JSONDecode([==["--[[\n\tModule: BattlePose\n\tDescription: \u6273\u624b\u8155\u5bf9\u5c40 R6 \u81c2\u59ff\uff1a\u53f3\u624b\u7528\u53c2\u8003 Rig \u7684 C0/C1 \u5f62\u6001\uff1b\u5de6\u624b\u6276\u684c\uff1b\u968f P \u5fae\u503e\uff08\u4e0d\u9759\u97f3\u5168\u8eab\u52a8\u753b\uff0c\u907f\u514d\u95ea\u70c1\uff09\n\tAuthor: \u7a0b\u8398\n\tCreated: 2026-10-16\n\tLast Modified: 2026-10-16\n\n\t\u529f\u80fd\uff1a\n\t- Begin / Stop\uff1a\u5bf9\u5c40\u5f00\u59cb\u63a5\u7ba1\u3001\u7ed3\u675f\u91ca\u653e\n\t- \u53f3\u624b\uff1a\u53c2\u8003 Rig Right Shoulder C0/C1\uff1bP \u53ea\u6539 Transform \u5fae\u503e\n\t- \u5de6\u624b\uff1a\u5728\u9ed8\u8ba4 C0/C1 \u4e0a\u5199 Transform\uff0c\u5c16\u7aef\u671d\u684c\u9762\u6276\u70b9\n\t- BindToRenderStep(Last) \u76d6\u6389 Animator \u5bf9\u624b\u81c2\u7684\u5199\u5165\uff1b\u4e0d AdjustWeight\uff0c\u4ee5\u514d\u8eaf\u5e72/\u817f\u95ea\u70c1\n\n\t\u53c2\u8003\uff1a\n\t- Workspace[\"\u4e34\u65f6\u6587\u4ef6\u5939\"].Rig\uff08\u5df2\u6446\u59ff\u6001\uff09Right Shoulder C0/C1\n\n\t\u7ea6\u675f\uff1a\n\t- \u7eaf\u672c\u5730\u8868\u73b0\uff1b\u4e0d\u5199 HRP / \u5b58\u6863\uff1b\u955c\u5934\u4ecd\u7531 SystemArmWrestle\n\n\t\u52a0\u8f7d\uff08\u4ec5 SystemArmWrestle \u5185\u90e8\uff09\uff1a\n\t\tlocal BattlePose = require(script.BattlePose)\n\t\tBattlePose.Begin(tableModel, LocalPlayer.Character)\n\t\tBattlePose.Stop()\n]]\n\nlocal Utils = require(game.ReplicatedFirst.AllSideCode.UtilsSystem)\nlocal RunService = U"]==])
return { n = #m.Source, i = 0 }
