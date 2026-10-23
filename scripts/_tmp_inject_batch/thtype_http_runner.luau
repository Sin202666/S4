local HttpService = game:GetService("HttpService")
local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(function() return HttpService:GetAsync("http://127.0.0.1:8777/thtype_payload.json") end)
HttpService.HttpEnabled = was
if not ok then return "http: " .. tostring(body) end
local decoded = HttpService:JSONDecode(body)
local s = game.ReplicatedFirst.AllSideCode.Interface.TranslationHelper-Type
s.Source = decoded.src
return string.format("thtype len=%d marker=%s", #s.Source, tostring(s.Source:find('BindProximityPrompt',1,true)~=nil))