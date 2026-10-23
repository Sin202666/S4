local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64decode(data)
	data = string.gsub(data, '[^'..alphabet..'=]', '')
	return (data:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (alphabet:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end
local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")
if not folder then return { err = "no folder" } end
local parts = {}
local i = 0
while folder:FindFirstChild(tostring(i)) do
	table.insert(parts, folder[tostring(i)].Value)
	i += 1
end
local src = b64decode(table.concat(parts))
local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose
m.Source = src
folder:Destroy()
return {
	parts = #parts,
	len = #src,
	ok = string.find(src, "_leftRestPoint") ~= nil
		and string.find(src, "_meetPoint") ~= nil
		and string.find(src, "Left Arm") ~= nil,
}
