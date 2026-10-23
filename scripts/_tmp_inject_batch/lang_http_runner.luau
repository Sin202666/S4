local HttpService = game:GetService("HttpService")
local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(function() return HttpService:GetAsync("http://127.0.0.1:8777/lang_payload.json") end)
HttpService.HttpEnabled = was
if not ok then return "http: " .. tostring(body) end
local decoded = HttpService:JSONDecode(body)
local s = game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper.Language
s.Source = decoded.src
return string.format("lang len=%d marker=%s", #s.Source, tostring(s.Source:find('Scarecrow',1,true)~=nil))