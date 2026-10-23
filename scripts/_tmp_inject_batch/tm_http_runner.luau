local HttpService = game:GetService("HttpService")
local was = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local ok, body = pcall(function() return HttpService:GetAsync("http://127.0.0.1:8777/tm_payload.json") end)
HttpService.HttpEnabled = was
if not ok then return "http: " .. tostring(body) end
local decoded = HttpService:JSONDecode(body)
local s = game.StarterPlayer.StarterPlayerScripts.Manager.TranslationManager
s.Source = decoded.src
return string.format("tm len=%d marker=%s", #s.Source, tostring(s.Source:find('_watchProximityPrompts',1,true)~=nil))