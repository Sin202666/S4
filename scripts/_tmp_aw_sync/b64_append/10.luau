local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data: string): string
	data = string.gsub(data, "[^A-Za-z0-9+/=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = lookup[string.byte(data, i)] or 0
		local b = lookup[string.byte(data, i + 1)] or 0
		local c = lookup[string.byte(data, i + 2)] or 0
		local d = lookup[string.byte(data, i + 3)] or 0
		n += 1
		out[n] = string.char(bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		if string.sub(data, i + 2, i + 2) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255))
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255))
		end
	end
	return table.concat(out)
end
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source ..= b64decode("dGVtSWQgPSAyMDEgfSwKCVRyYWluU3BlZWRQb3Rpb24gPSB7IFpoTmFtZSA9ICLorq3nu4PpgJ/luqboja/msLQiLCBaaERlcyA9ICLorq3nu4PpgJ/luqboja/msLTmj4/ov7AiLCBFZmZlY3QgPSAiVHJhaW5TcGVlZCIsIE11bHQgPSAyLCBEdXJhdGlvbiA9IDkwMCwgUHJvZHVjdEtleSA9ICJUcmFpblNwZWVkUG90aW9uIiwgSWNvbiA9ICJwb3Rpb25UcmFpblNwZWVkIiwgSXRlbUlkID0gMjAyIH0sCglDYXNoUG90aW9uID0geyBaaE5hbWUgPSAi6YeR5biB6I2v5rC0IiwgWmhEZXMgPSAi6YeR5biB6I2v5rC05o+P6L+wIiwgRWZmZWN0ID0gIkNhc2giLCBNdWx0ID0gMiwgRHVyYXRpb24gPSA5MDAsIFByb2R1Y3RLZXkgPSAiQ2FzaFBvdGlvbiIsIEljb24gPSAicG90aW9uQ2FzaCIsIEl0ZW1JZCA9IDIwMyB9LAp9CgotLSDlj6/otbDnnJ/lrp7mlLbmja7lj5HotKfnmoTllYblk4Hnp43nsbvvvJtBcm0vTWF0ZXJpYWwg5ZCr6ZmQ6YeP5bqT5a2Y5LiO6KOF5aSH6YC76L6R77yM5pS25o2u6Lev5b6E5pyq6KaG55uW77yM5LiN5b6X5Yqg5YWlCmxvY2FsIF9SRUNFSVBUX0tJTkRTID0geyBTdHJlbmd0aCA9IHRydWUsIFN0cmVuZ3RoVGllciA9IHRydWUsIENhc2ggPSB0cnVlLCBQb3Rpb24gPSB0cnVlIH0KCmxvY2FsIF9TVFJFTkdUSF9USUVSX0tFWVMgPSB7ICJTdHJlbmd0aFRpZXIxIiwgIlN0cmVuZ3RoVGllcjIiLCAiU3RyZW5ndGhUaWVyMyIsICJTdHJlbmd0aFRpZXI0IiwgIlN0cmVuZ3RoVGllcjUiLCAiU3RyZW5ndGhUaWVyNiIgfQoKQXJtV3Jlc3RsZUNvbmZpZy5HYW1lUGFzc09yZGVyID0geyAiQXV0b0NsaWNrZXIiLCAiRG91YmxlU3RyZW5ndGgiLCAiRG91YmxlQ2FzaCIgfQotLSDkuLvnlYzpnaLlj7Pkvqflipvph4/ljIXvvIzoh6rkuIrogIzkuIsKQXJtV3Jlc3RsZUNvbmZpZy5TdHJlbmd0aFBhY2tPcmRlciA9IHsgIlN0cmVuZ3RoUGFjazMiLCAiU3RyZW5ndGhQYWNrMiIsICJTdHJlbmd0aFBhY2sxIiB9Ci0tIOWVhuWfju+8mumAmuihjOivgeWMuuOAgeWKm+mHj+WMuu+8iOS7juWwj+WIsOWkp++8ieOAgeiNr+awtOWMugpBcm1XcmVzdGxlQ29uZmlnLlNob3BQYXNzT3JkZXIgPSB7ICJEb3VibGVTdHJlbmd0aCIsICJEb3VibGVDYXNoIiwgIkF1dG9DbGlja2VyIiB9CkFybVdyZXN0bGVDb25maWcuU2hvcFBhY2tPcmRlciA9IHsgIlN0cmVuZ3RoUGFjazEiLCAiU3RyZW5ndGhQYWNrMiIsICJTdHJlbmd0aFBhY2szIiB9CkFybVdyZXN0bGVDb25maWcuUG90aW9uT3JkZXIgPSB7ICJTdHJlbmd0aFBvdGlvbiIsICJUcmFpblNwZWVkUG90aW9uIiwgIkNhc2hQb3Rpb24iIH0KCi0tW1sKCem7mOiupOWtmOaho+WtkOagke+8iOa3seaLt+i0neWQjuWGmeWFpSBTYXZlTWV0YURhdGEgLyDkvJror53vvIkKCUByZXR1cm4gdGFibGUgLSBBcm1XcmVzdGxlIOWPr+WPmOWJr+acrApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldERlZmF1bHRQcm9maWxlKCk6IHsgW3N0cmluZ106IGFueSB9CglyZXR1cm4gewoJCVN0cmVuZ3RoID0gMCwKCQlDYXNoID0gMCwKCQlXaW5zID0gMCwKCQlVbmxvY2tlZCA9IDEsCgkJVHJhaW5UaWVyID0gMSwKCQlTcGVlZFRpZXIgPSAxLAoJCUFybXMgPSB7IFsiMSJdID0gdHJ1ZSB9LAoJCUFybSA9IDEsCgkJTWF0cyA9IHt9LAoJCU1hdCA9ICIiLAoJCUR1bWJiZWxscyA9IHsgWyIxIl0gPSB0cnVlIH0sCgkJRHVtYmJlbGwgPSAxLAoJCVN0cmVuZ3RoVGllciA9IDAsCgkJUG90aW9uTGVmdCA9IHt9LAoJCUxhc3RPbmxpbmUgPSAwLAoJCU9mZmxpbmVQZW5kaW5nID0gMCwKCQlNZW51R2lmdENsYWltZWQgPSBmYWxz")
return #m.Source
