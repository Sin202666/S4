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
local sub = folder:FindFirstChild("ArmWrestleConfig")
if not sub then
	sub = Instance.new("Folder")
	sub.Name = "ArmWrestleConfig"
	sub.Parent = folder
end
local v = sub:FindFirstChild("10")
if not v then
	v = Instance.new("StringValue")
	v.Name = "10"
	v.Parent = sub
end
v.Value = "ZSwKCX0KZW5kCgotLVtbCgnnqIDmnInluqbooajmt7Hmi7fotJ0KCUBwYXJhbSBpZCBzdHJpbmcgLSBDb21tb24gLyBVbmNvbW1vbiAvIFJhcmUgLyBFcGljIC8gTGVnZW5kYXJ5IC8gTXl0aGljIC8gRXhjbHVzaXZlCglAcmV0dXJuIHRhYmxlPyAtIOeogOacieW6puadoeebrgpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFJhcml0eShpZDogc3RyaW5nKTogeyBbc3RyaW5nXTogYW55IH0/Cglsb2NhbCByb3cgPSBfUkFSSVRJRVNbaWRdCglpZiBub3Qgcm93IHRoZW4KCQlyZXR1cm4gbmlsCgllbmQKCXJldHVybiBfY2xvbmUocm93KQplbmQKCi0tW1sKCeadkOi0qOihqO+8iOa3seaLt+i0neaVsOe7hO+8iQoJQHJldHVybiB7dGFibGV9IC0g5p2Q6LSo5YiX6KGoCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0TWF0ZXJpYWxzKCk6IHsgeyBbc3RyaW5nXTogYW55IH0gfQoJcmV0dXJuIF9jbG9uZShfTUFURVJJQUxTKQplbmQKCi0tW1sKCeaMiSBJZCDlj5bmnZDotKgKCUBwYXJhbSBpZCBzdHJpbmcgLSDmnZDotKggSWQKCUByZXR1cm4gdGFibGU/IC0g5p2Q6LSo5p2h55uuCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0TWF0ZXJpYWwoaWQ6IHN0cmluZyk6IHsgW3N0cmluZ106IGFueSB9PwoJaWYgdHlwZShpZCkgfj0gInN0cmluZyIgb3IgaWQgPT0gIiIgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJZm9yIF8sIHJvdyBpbiBpcGFpcnMoX01BVEVSSUFMUykgZG8KCQlpZiByb3cuSWQgPT0gaWQgdGhlbgoJCQlyZXR1cm4gX2Nsb25lKHJvdykKCQllbmQKCWVuZAoJcmV0dXJuIG5pbAplbmQKCi0tW1sKCeaJi+iHguihqO+8iOa3seaLt+i0neaVsOe7hO+8iQoJQHJldHVybiB7dGFibGV9IC0g5omL6IeC5YiX6KGoCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0QXJtcygpOiB7IHsgW3N0cmluZ106IGFueSB9IH0KCXJldHVybiBfY2xvbmUoX0FSTVMpCmVuZAoKLS1bWwoJ5oyJIElkIOWPluaJi+iHggoJQHBhcmFtIGlkIG51bWJlciAtIOaJi+iHgiBJZO+8iDEtMTLvvIkKCUByZXR1cm4gdGFibGU/IC0g5omL6IeC5p2h55uuCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0QXJtKGlkOiBudW1iZXIpOiB7IFtzdHJpbmddOiBhbnkgfT8KCWxvY2FsIHJvdyA9IF9BUk1TW2lkXQoJaWYgbm90IHJvdyB0aGVuCgkJcmV0dXJuIG5pbAoJZW5kCglyZXR1cm4gX2Nsb25lKHJvdykKZW5kCgotLVtbCgnlk5Hpk4PooajvvIjmt7Hmi7fotJ3mlbDnu4TvvIkKCUByZXR1cm4ge3RhYmxlfSAtIOWTkemTg+WIl+ihqCB7IElkLCBaaE5hbWUsIE11bHQsIFByaWNlLCBQbGF0ZUNvbG9yLCBQbGF0ZU1hdCwgUGxhdGVTY2FsZSwgSGFuZGxlQ29sb3IgfQpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldER1bWJiZWxscygpOiB7IHsgW3N0cmluZ106IGFueSB9IH0KCXJldHVybiBfY2xvbmUoX0RVTUJCRUxMUykKZW5kCgotLVtbCgnmjIkgSWQg5Y+W5ZOR6ZODCglAcGFyYW0gaWQgbnVtYmVyIC0g5ZOR6ZODIElk77yIMS0xMO+8ie+8m+mdnuaVsOWtl+aIlui2iueVjOi/lOWbniBuaWwKCUByZXR1cm4gdGFibGU/IC0g5ZOR6ZOD5p2h55uuCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0RHVtYmJlbGwoaWQ6IG51bWJlcik6IHsgW3N0cmluZ106IGFueSB9PwoJaWYgdHlwZShpZCkgfj0gIm51bWJlciIgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJbG9jYWwgcm93ID0gX0RVTUJCRUxMU1tpZF0KCWlmIG5vdCByb3cgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJcmV0dXJuIF9jbG9uZShyb3cpCmVuZAoKLS1bWwoJ5oyJ"
return #v.Value
