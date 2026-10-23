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
local folder = game.ReplicatedStorage._TmpAio
local parts = {}
local i = 0
while folder:FindFirstChild(tostring(i)) do
	table.insert(parts, folder[tostring(i)].Value)
	i += 1
end
local code = b64decode(table.concat(parts))
local fn, err = loadstring(code)
if not fn then return { err = tostring(err) } end
local ok, res = pcall(fn)
folder:Destroy()
if not ok then return { err = tostring(res) } end
return res
