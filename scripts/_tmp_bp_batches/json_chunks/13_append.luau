local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose
local Hs = game:GetService("HttpService")
m.Source ..= Hs:JSONDecode([==["en\n\t\treturn\n\tend\n\t_session = nil\n\tif s.Bound then\n\t\tpcall(function()\n\t\t\tRunService:UnbindFromRenderStep(BIND_NAME)\n\t\tend)\n\tend\n\t_restoreArm(s.PlayerRight)\n\t_restoreArm(s.OpponentRight)\n\t_restoreArm(s.PlayerLeft)\n\t_restoreArm(s.OpponentLeft)\nend\n\n--[[\n\t\u662f\u5426\u6b63\u5728\u6446\u5bf9\u5c40\u81c2\u59ff\n\t@return boolean - true \u8868\u793a\u63a5\u7ba1\u4e2d\n]]\nfunction BattlePose.IsActive(): boolean\n\treturn _session ~= nil\nend\n\nreturn BattlePose\n"]==])
return { n = #m.Source, i = 13 }
