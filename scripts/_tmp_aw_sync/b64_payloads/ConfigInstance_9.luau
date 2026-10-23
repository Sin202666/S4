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
local v = sub:FindFirstChild("9")
if not v then
	v = Instance.new("StringValue")
	v.Name = "9"
	v.Parent = sub
end
v.Value = "IiJ9LAoJWzE2XT17IumakOiXj+enjeaXj+WkluingiIsIkhpZGVSYWNlIiw1LDIsMCx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEsIiJ9LAoJWzE3XT17IuinhumHjuiMg+WbtCIsIkZpZWxkT2ZWaWV3Iiw1LDEsNzAsezUwLDkwfSwiIix7fSwwLCIifSwKCVsxOF09eyLmjonokL3nianmqKHlnosiLCJUaXBzSXRlbSIsNSwyLDEsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwxLCIifSwKCVsxOV09eyLmmL7npLrku5bkurrkv6Hmga8iLCJTaG93T3RoZXJQbHJJbmZvIiw1LDIsMSx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDEsIiJ9LAoJWzIwXT17IueUqOaIt+eVjOmdoiIsIkhpZGVVSSIsNSwyLDEsezAsMX0sIiIseyLlhbPpl60iLCLlvIDlkK8ifSwxLCIifSwKCVsyMV09eyLoh6rliqjliqDngrkiLCJBdXRvQXR0clBvaW50Iiw1LDIsMSx7MCwxfSwiIix7IuWFs+mXrSIsIuW8gOWQryJ9LDAsIiJ9LAoJWzIyXT17IuiusOW/huW/q+mAn+eCvOmHkSIsIkF1dG9HYW1lMyIsNSwyLDAsezAsMX0sIiIse30sMCwiIn0sCglbMjNdPXsi5aWU6LeR5qih5byPIiwiUnVuTW9kZSIsNCwzLDAsezAsMX0sIiIseyLkuIDplK7liIfmjaIiLCLplb/mjInlpZTot5EifSwxLCIifQp9CgpDb25maWdJbnN0YW5jZS5za2lsbENvbmY9ewoJWzEwMDAwMDAyXT17IuWGsuWIuiIsIk5ld1JvbGwiLCIiLCLnjqnlrrbln7rnoYDmioDog70iLCIiLDEsMCwxLDAsMCwwLCLlkJHliY3lhrLliLrkuIDmrrXot53nprsiLDAsMywyLHswfSwiIix7fSwi5Z+656GA5oqA6IO9IiwiIiwiIiwiIix7MX0sezEsMX0se319LAoJWzEwMDAwMDEwXT17Iua8lOekuuaWveazlSIsIlNraWxsRGVtb0Nhc3QiLCIiLCLmoYbmnrbmoLfkvosiLCIiLDEsMCwxLDAsMCwwLCLnn63mlr3ms5XplIHnp7vliqjmoLfkvosiLDAsMywyLHswfSwiIix7fSwi5Li75Yqo5oqA6IO9IiwiIiwiIiwiIix7MX0sezEsMX0se319LAoJWzEwMDAwMDExXT17IumZqOefs+acryIsIk1ldGVvciIsIiIsIuahhuaetuagt+S+iyIsIiIsMSw1MCwxLDAsMiwxMjAsIuWcqOebruagh+S9jee9ruWPrOWUpOS4gOaemumZqOefsyIsMiwzLDIsezF9LCIiLHt9LCLkuLvliqjmioDog70iLCIiLCIiLCIiLHswLjZ9LHsxLDJ9LHt9fSwKCVsxMDAwMDAxMl09eyLnqbrpl7TmioDog70iLCJTcGFjZVNraWxsIiwiIiwi5qGG5p625qC35L6LIiwiIiwxLDgwLDEsMCwyLDAsIuepuumXtOijgue8neWPjOeQg+ihqOeOsO+8iOe6r+ihqOeOsOmmlueJiO+8iSIsMCwzLDEyLHswfSwiIix7fSwi5Li75Yqo5oqA6IO9IiwiIiwiIiwiIix7MX0sezEsMX0se319Cn0KCkNvbmZpZ0luc3RhbmNlLnVwZGF0ZWxvZ0NvbmY9ewoJWzFdPXsxNzc4ODM5MjAwLCLmm7TmlrBf6aG1562+5qCH6aKYXzEiLHsi5pu05pawX+WGheWuueagh+mimF8xIiwi5pu05pawX+WGheWuuV8xXzEiLCLmm7TmlrBf5YaF5a65XzFfMiIsIuabtOaWsF/lhoXlrrlfMV8zIn19Cn0KcmV0dXJuIENvbmZpZ0luc3RhbmNlCg=="
return #v.Value
