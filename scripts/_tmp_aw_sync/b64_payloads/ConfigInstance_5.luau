local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function b64decode(data: string): string
	data = string.gsub(data, "[^" .. alphabet .. "=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = string.find(alphabet, string.sub(data, i, i), 1, true) or 1
		local b = string.find(alphabet, string.sub(data, i + 1, i + 1), 1, true) or 1
		local c = string.find(alphabet, string.sub(data, i + 2, i + 2), 1, true) or 1
		local d = string.find(alphabet, string.sub(data, i + 3, i + 3), 1, true) or 1
		a, b, c, d = a - 1, b - 1, c - 1, d - 1
		local n1 = bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4))
		n += 1
		out[n] = string.char(n1)
		if string.sub(data, i + 2, i + 2) ~= "=" then
			local n2 = bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255)
			n += 1
			out[n] = string.char(n2)
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			local n3 = bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255)
			n += 1
			out[n] = string.char(n3)
		end
	end
	return table.concat(out)
end
local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "_TmpAwSync"
	folder.Parent = game.ReplicatedStorage
end
local sub = folder:FindFirstChild("ConfigInstance")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ConfigInstance"
	sub.Parent = folder
end
local v = sub:FindFirstChild("5")
if not v then
	v = Instance.new("StringValue")
	v.Name = "5"
	v.Parent = sub
end
v.Value = "LDEsMCwwLHsyMDJ9LHsxfX0KfQoKQ29uZmlnSW5zdGFuY2UuZGFpbHlhd2FyZENvbmY9ewoJWzFdPXsxLDEsMiwxMCwiMiIsIjg2NTg5MTk1OTQ1NjI5In0sCglbMl09ezIsMSwyLDEwLCIzIiwiODY1ODkxOTU5NDU2MjkifSwKCVszXT17MywxLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzRdPXs0LDEsMiwxMCwiNCIsIjg2NTg5MTk1OTQ1NjI5In0sCglbNV09ezUsMSwyLDEwLCI0IiwiODY1ODkxOTU5NDU2MjkifSwKCVs2XT17NiwxLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzddPXs3LDEsMiwxMCwiNCIsIjg2NTg5MTk1OTQ1NjI5In0sCglbOF09ezEsMiwyLDEwLCIzIiwiODY1ODkxOTU5NDU2MjkifSwKCVs5XT17MiwyLDIsMTAsIjMiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzEwXT17MywyLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzExXT17NCwyLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzEyXT17NSwyLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzEzXT17NiwyLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE0XT17NywyLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE1XT17MSwzLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE2XT17MiwzLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE3XT17MywzLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE4XT17NCwzLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzE5XT17NSwzLDIsMTAsIjQiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzIwXT17NiwzLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9LAoJWzIxXT17NywzLDIsMTAsIjUiLCI4NjU4OTE5NTk0NTYyOSJ9Cn0KCkNvbmZpZ0luc3RhbmNlLmVuZW15Q29uZj17CglbNTAxMTAwMV09eyLov5HmiJjlk6XluIPmnpciLCIxIiw1LCLnn67kurrmj4/ov7AiLCLov5HmiJjlk6XluIPmnpciLCLlj5flh7st5ZOl5biD5p6XMSIsIuS6uuWei+W+heaculI2LTIiLCLkurrlnovooYzotbBSNi0zIiwi5Lq65Z6L5aWU6LeRUjYtMiIsIuS6uuWei+WPl+WHu1I2LTEiLCLkurrlnovmrbvkuqFSNiIsIuS6uuWei+ecqeaZlVI2IiwiUmFuZ2VyIiwiMCIsMSwxLCIiLCIiLCIiLCIiLHsxMDMwMDAwMX0se30sezF9LHszfSx7MH0sezZ9LDQsMCwzLDAsezEsNSw5fSx7MTAsMjEsMTJ9LHt9LDEsIiIsMjAwLDIwMCwwLHt9LHt9LDIse30sMCwiMCIsIjEiLDMsMywwLDE2LDI0LDEsMSwiIiwwLCIiLCIiLCIiLCIiLHt9LHt9LCIifQp9CgpDb25maWdJbnN0YW5jZS5nYW1lcGFzc2l0ZW1Db25mPXsKCVszMDAwMDAxXT17IuW5uOi/kCIsIkx1Y2siLDEsMSwzLDEwODc0Nzk3NTkwNjExNywzLCLnu78ifSwKCVszMDAwMDAyXT17Iui2hee6p+W5uOi/kCIsIlN1cGVyTHVjayIsMSwxLDMsOTQ0NTYzMzgyMTk3NzYsMywi5qmZIn0KfQoKQ29uZmlnSW5zdGFuY2UuaXRlbWRhdGFDb25mPXsKCVsxXT17IumHkemSsSIsNSwxLDEsMCwxLDAsMCwwLCJHZW0iLDAsIjAiLHsiMCJ9LDkwNTIxMjU4NjM5MjkwLCIiLCIwIiwiMTAiLHt9LHt9LCIiLDB9LAoJWzJdPXsi5a6d55+zIiw1LDEsMSwwLDEsMCwwLDAsInp1YW5zaGkiLDAsIjAiLHsiMCJ9LDEwMzgxMjgwODUyMjcxNywiR2VtIiwiMCIsIjAiLHt9LHt9LCIiLDB9LAoJWzIwMV09eyLlipvph4/oja/msLQiLDQsMSwxLDAsMSwwLDEsMSwi5Yqb6YeP6I2v5rC05o+P6L+wIiwwLCJBcm1XcmVzdGxlUG90aW9uIix7IlN0cmVuZ3RoUG90aW9uIn0sMTI2OTc3NjE0MjUwMjkyLCIiLCIwIiwiMCIse30se30sIiIsMX0sCglbMjAyXT17Iuiuree7g+mA"
return #v.Value
