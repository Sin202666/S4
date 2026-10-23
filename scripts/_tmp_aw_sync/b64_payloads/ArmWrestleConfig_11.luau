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
local v = sub:FindFirstChild("11")
if not v then
	v = Instance.new("StringValue")
	v.Name = "11"
	v.Parent = sub
end
v.Value = "5ZOR6ZOD6YWN572u57uZ5qih5p2/5YWL6ZqG5L2T5pS55aSW6KeC77ya5ZCN5Li6IEhhbmRsZSDnmoTpg6jku7bmlLnmj6HmioroibLvvIzlhbbkvZkgQmFzZVBhcnQg6KeG5Li65p2g6ZOD54mH77yI5pS56ImyL+adkOi0qC/miKrpnaLmlL7lpKfvvIkKCeWPquiDveS9nOeUqOS6jiBGaW5kVG9vbFRlbXBsYXRlKCkg55qE5YWL6ZqG5L2T77yM56aB5q2i55u05o6l5pS55qih5p2/CglAcGFyYW0gcm9vdCBJbnN0YW5jZSAtIFRvb2wg5YWL6ZqG5L2T5oiW55Sx5YW25ou85Ye655qE5bGV56S6IE1vZGVsCglAcGFyYW0gaWQgbnVtYmVyIC0g5ZOR6ZODIElk77yb5peg5pWI5pe25LiN5YGa5L+u5pS5Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuQXBwbHlEdW1iYmVsbExvb2socm9vdDogSW5zdGFuY2UsIGlkOiBudW1iZXIpCglsb2NhbCByb3cgPSBfRFVNQkJFTExTW2lkXQoJaWYgbm90IHJvdyB0aGVuCgkJcmV0dXJuCgllbmQKCWxvY2FsIG1hdGVyaWFsID0gKEVudW0uTWF0ZXJpYWwgOjogYW55KVtyb3cuUGxhdGVNYXRdIG9yIEVudW0uTWF0ZXJpYWwuTWV0YWwKCWZvciBfLCBwYXJ0IGluIGlwYWlycyhyb290OkdldERlc2NlbmRhbnRzKCkpIGRvCgkJaWYgbm90IHBhcnQ6SXNBKCJCYXNlUGFydCIpIHRoZW4KCQkJY29udGludWUKCQllbmQKCQlpZiBwYXJ0Lk5hbWUgPT0gIkhhbmRsZSIgdGhlbgoJCQlwYXJ0LkNvbG9yID0gcm93LkhhbmRsZUNvbG9yCgkJZWxzZQoJCQlwYXJ0LkNvbG9yID0gcm93LlBsYXRlQ29sb3IKCQkJcGFydC5NYXRlcmlhbCA9IG1hdGVyaWFsCgkJCWxvY2FsIHNpemUgPSBwYXJ0LlNpemUKCQkJcGFydC5TaXplID0gVmVjdG9yMy5uZXcoc2l6ZS5YLCBzaXplLlkgKiByb3cuUGxhdGVTY2FsZSwgc2l6ZS5aICogcm93LlBsYXRlU2NhbGUpCgkJZW5kCgllbmQKZW5kCgotLVtbCgnorq3nu4PpgJ/luqbpmLYKCUByZXR1cm4ge3RhYmxlfSAtIOmYtuWIl+ihqApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFRyYWluU3BlZWQoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9CglyZXR1cm4gX2Nsb25lKF9UUkFJTl9TUEVFRCkKZW5kCgotLVtbCgnooYzotbDpgJ/luqbpmLYKCUByZXR1cm4ge3RhYmxlfSAtIOmYtuWIl+ihqApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFdhbGtTcGVlZCgpOiB7IHsgW3N0cmluZ106IGFueSB9IH0KCXJldHVybiBfY2xvbmUoX1dBTEtfU1BFRUQpCmVuZAoKLS1bWwoJ5YWz5Y2h6KGoCglAcmV0dXJuIHt0YWJsZX0gLSDlhbPljaHliJfooagKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRMZXZlbHMoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9CglyZXR1cm4gX2Nsb25lKF9MRVZFTFMpCmVuZAoKLS1bWwoJ5Y2V5YWz6YWN572uCglAcGFyYW0gaW5kZXggbnVtYmVyIC0gMS1iYXNlZCDlhbPljaHkuIvmoIcKCUByZXR1cm4gdGFibGU/IC0g5YWz5Y2h5p2h55uuCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0TGV2ZWwoaW5kZXg6IG51bWJlcik6IHsgW3N0cmluZ106IGFueSB9PwoJbG9jYWwgcm93ID0gX0xFVkVMU1tpbmRleF0KCWlmIG5vdCByb3cgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJcmV0dXJuIF9jbG9uZShyb3cpCmVuZAoKLS1bWwoJ5oyJ5a+55omLIElkIOafpeaJvgoJQHBhcmFtIGlkIHN0cmluZyAtIOWvueaJiyBJZAoJQHJldHVybiB0YWJsZT8gLSDlr7nmiYvmnaHnm64KCUByZXR1cm4gbnVtYmVyPyAtIOWFs+WNoeS4i+aghwpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldE9wcG9uZW50KGlkOiBzdHJpbmcpOiAoeyBbc3RyaW5nXTogYW55"
return #v.Value
