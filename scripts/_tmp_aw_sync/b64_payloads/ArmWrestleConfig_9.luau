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
local v = sub:FindFirstChild("9")
if not v then
	v = Instance.new("StringValue")
	v.Name = "9"
	v.Parent = sub
end
v.Value = "dGVtSWQgPSAyMDEgfSwKCVRyYWluU3BlZWRQb3Rpb24gPSB7IFpoTmFtZSA9ICLorq3nu4PpgJ/luqboja/msLQiLCBaaERlcyA9ICLorq3nu4PpgJ/luqboja/msLTmj4/ov7AiLCBFZmZlY3QgPSAiVHJhaW5TcGVlZCIsIE11bHQgPSAyLCBEdXJhdGlvbiA9IDkwMCwgUHJvZHVjdEtleSA9ICJUcmFpblNwZWVkUG90aW9uIiwgSWNvbiA9ICJwb3Rpb25UcmFpblNwZWVkIiwgSXRlbUlkID0gMjAyIH0sCglDYXNoUG90aW9uID0geyBaaE5hbWUgPSAi6YeR5biB6I2v5rC0IiwgWmhEZXMgPSAi6YeR5biB6I2v5rC05o+P6L+wIiwgRWZmZWN0ID0gIkNhc2giLCBNdWx0ID0gMiwgRHVyYXRpb24gPSA5MDAsIFByb2R1Y3RLZXkgPSAiQ2FzaFBvdGlvbiIsIEljb24gPSAicG90aW9uQ2FzaCIsIEl0ZW1JZCA9IDIwMyB9LAp9CgotLSDlj6/otbDnnJ/lrp7mlLbmja7lj5HotKfnmoTllYblk4Hnp43nsbvvvJtBcm0vTWF0ZXJpYWwg5ZCr6ZmQ6YeP5bqT5a2Y5LiO6KOF5aSH6YC76L6R77yM5pS25o2u6Lev5b6E5pyq6KaG55uW77yM5LiN5b6X5Yqg5YWlCmxvY2FsIF9SRUNFSVBUX0tJTkRTID0geyBTdHJlbmd0aCA9IHRydWUsIFN0cmVuZ3RoVGllciA9IHRydWUsIENhc2ggPSB0cnVlLCBQb3Rpb24gPSB0cnVlIH0KCmxvY2FsIF9TVFJFTkdUSF9USUVSX0tFWVMgPSB7ICJTdHJlbmd0aFRpZXIxIiwgIlN0cmVuZ3RoVGllcjIiLCAiU3RyZW5ndGhUaWVyMyIsICJTdHJlbmd0aFRpZXI0IiwgIlN0cmVuZ3RoVGllcjUiLCAiU3RyZW5ndGhUaWVyNiIgfQoKQXJtV3Jlc3RsZUNvbmZpZy5HYW1lUGFzc09yZGVyID0geyAiQXV0b0NsaWNrZXIiLCAiRG91YmxlU3RyZW5ndGgiLCAiRG91YmxlQ2FzaCIgfQotLSDkuLvnlYzpnaLlj7Pkvqflipvph4/ljIXvvIzoh6rkuIrogIzkuIsKQXJtV3Jlc3RsZUNvbmZpZy5TdHJlbmd0aFBhY2tPcmRlciA9IHsgIlN0cmVuZ3RoUGFjazMiLCAiU3RyZW5ndGhQYWNrMiIsICJTdHJlbmd0aFBhY2sxIiB9Ci0tIOWVhuWfju+8mumAmuihjOivgeWMuuOAgeWKm+mHj+WMuu+8iOS7juWwj+WIsOWkp++8ieOAgeiNr+awtOWMugpBcm1XcmVzdGxlQ29uZmlnLlNob3BQYXNzT3JkZXIgPSB7ICJEb3VibGVTdHJlbmd0aCIsICJEb3VibGVDYXNoIiwgIkF1dG9DbGlja2VyIiB9CkFybVdyZXN0bGVDb25maWcuU2hvcFBhY2tPcmRlciA9IHsgIlN0cmVuZ3RoUGFjazEiLCAiU3RyZW5ndGhQYWNrMiIsICJTdHJlbmd0aFBhY2szIiB9CkFybVdyZXN0bGVDb25maWcuUG90aW9uT3JkZXIgPSB7ICJTdHJlbmd0aFBvdGlvbiIsICJUcmFpblNwZWVkUG90aW9uIiwgIkNhc2hQb3Rpb24iIH0KCi0tW1sKCem7mOiupOWtmOaho+WtkOagke+8iOa3seaLt+i0neWQjuWGmeWFpSBTYXZlTWV0YURhdGEgLyDkvJror53vvIkKCUByZXR1cm4gdGFibGUgLSBBcm1XcmVzdGxlIOWPr+WPmOWJr+acrApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldERlZmF1bHRQcm9maWxlKCk6IHsgW3N0cmluZ106IGFueSB9CglyZXR1cm4gewoJCVN0cmVuZ3RoID0gMCwKCQlDYXNoID0gMCwKCQlXaW5zID0gMCwKCQlVbmxvY2tlZCA9IDEsCgkJVHJhaW5UaWVyID0gMSwKCQlTcGVlZFRpZXIgPSAxLAoJCUFybXMgPSB7IFsiMSJdID0gdHJ1ZSB9LAoJCUFybSA9IDEsCgkJTWF0cyA9IHt9LAoJCU1hdCA9ICIiLAoJCUR1bWJiZWxscyA9IHsgWyIxIl0gPSB0cnVlIH0sCgkJRHVtYmJlbGwgPSAxLAoJCVN0cmVuZ3RoVGllciA9IDAsCgkJUG90aW9uTGVmdCA9IHt9LAoJCUxhc3RPbmxpbmUgPSAwLAoJCU9mZmxpbmVQZW5kaW5nID0gMCwKCQlNZW51R2lmdENsYWltZWQgPSBmYWxz"
return #v.Value
