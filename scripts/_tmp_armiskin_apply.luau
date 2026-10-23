local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (b:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end
local folder = game.ServerStorage._ArmSkinInject
local parts = {}
for i = 0, 6 do
	local v = folder:FindFirstChild(tostring(i))
	if not v then
		return "missing chunk " .. i
	end
	table.insert(parts, v.Value)
end
local src = b64decode(table.concat(parts))
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin
local ses = game:GetService("ScriptEditorService")
local ok, err = pcall(function()
	ses:UpdateSourceAsync(m, function()
		return src
	end)
end)
m.Source = src
local verify = string.format(
	"len=%d|CLASSIC=%s|LIMB=%s|CN=%s|update=%s",
	#src,
	tostring(src:find("CLASSIC_ARM_MESH") ~= nil),
	tostring(src:find("_ensureLimbMesh") ~= nil),
	tostring(src:find("才有圆润边") ~= nil),
	tostring(ok)
)
folder:Destroy()
return verify
