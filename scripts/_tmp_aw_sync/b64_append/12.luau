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
m.Source ..= b64decode("5ZOR6ZOD6YWN572u57uZ5qih5p2/5YWL6ZqG5L2T5pS55aSW6KeC77ya5ZCN5Li6IEhhbmRsZSDnmoTpg6jku7bmlLnmj6HmioroibLvvIzlhbbkvZkgQmFzZVBhcnQg6KeG5Li65p2g6ZOD54mH77yI5pS56ImyL+adkOi0qC/miKrpnaLmlL7lpKfvvIkKCeWPquiDveS9nOeUqOS6jiBGaW5kVG9vbFRlbXBsYXRlKCkg55qE5YWL6ZqG5L2T77yM56aB5q2i55u05o6l5pS55qih5p2/CglAcGFyYW0gcm9vdCBJbnN0YW5jZSAtIFRvb2wg5YWL6ZqG5L2T5oiW55Sx5YW25ou85Ye655qE5bGV56S6IE1vZGVsCglAcGFyYW0gaWQgbnVtYmVyIC0g5ZOR6ZODIElk77yb5peg5pWI5pe25LiN5YGa5L+u5pS5Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuQXBwbHlEdW1iYmVsbExvb2socm9vdDogSW5zdGFuY2UsIGlkOiBudW1iZXIpCglsb2NhbCByb3cgPSBfRFVNQkJFTExTW2lkXQoJaWYgbm90IHJvdyB0aGVuCgkJcmV0dXJuCgllbmQKCWxvY2FsIG1hdGVyaWFsID0gKEVudW0uTWF0ZXJpYWwgOjogYW55KVtyb3cuUGxhdGVNYXRdIG9yIEVudW0uTWF0ZXJpYWwuTWV0YWwKCWZvciBfLCBwYXJ0IGluIGlwYWlycyhyb290OkdldERlc2NlbmRhbnRzKCkpIGRvCgkJaWYgbm90IHBhcnQ6SXNBKCJCYXNlUGFydCIpIHRoZW4KCQkJY29udGludWUKCQllbmQKCQlpZiBwYXJ0Lk5hbWUgPT0gIkhhbmRsZSIgdGhlbgoJCQlwYXJ0LkNvbG9yID0gcm93LkhhbmRsZUNvbG9yCgkJZWxzZQoJCQlwYXJ0LkNvbG9yID0gcm93LlBsYXRlQ29sb3IKCQkJcGFydC5NYXRlcmlhbCA9IG1hdGVyaWFsCgkJCWxvY2FsIHNpemUgPSBwYXJ0LlNpemUKCQkJcGFydC5TaXplID0gVmVjdG9yMy5uZXcoc2l6ZS5YLCBzaXplLlkgKiByb3cuUGxhdGVTY2FsZSwgc2l6ZS5aICogcm93LlBsYXRlU2NhbGUpCgkJZW5kCgllbmQKZW5kCgotLVtbCgnorq3nu4PpgJ/luqbpmLYKCUByZXR1cm4ge3RhYmxlfSAtIOmYtuWIl+ihqApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFRyYWluU3BlZWQoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9CglyZXR1cm4gX2Nsb25lKF9UUkFJTl9TUEVFRCkKZW5kCgotLVtbCgnooYzotbDpgJ/luqbpmLYKCUByZXR1cm4ge3RhYmxlfSAtIOmYtuWIl+ihqApdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldFdhbGtTcGVlZCgpOiB7IHsgW3N0cmluZ106IGFueSB9IH0KCXJldHVybiBfY2xvbmUoX1dBTEtfU1BFRUQpCmVuZAoKLS1bWwoJ5YWz5Y2h6KGoCglAcmV0dXJuIHt0YWJsZX0gLSDlhbPljaHliJfooagKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRMZXZlbHMoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9CglyZXR1cm4gX2Nsb25lKF9MRVZFTFMpCmVuZAoKLS1bWwoJ5Y2V5YWz6YWN572uCglAcGFyYW0gaW5kZXggbnVtYmVyIC0gMS1iYXNlZCDlhbPljaHkuIvmoIcKCUByZXR1cm4gdGFibGU/IC0g5YWz5Y2h5p2h55uuCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0TGV2ZWwoaW5kZXg6IG51bWJlcik6IHsgW3N0cmluZ106IGFueSB9PwoJbG9jYWwgcm93ID0gX0xFVkVMU1tpbmRleF0KCWlmIG5vdCByb3cgdGhlbgoJCXJldHVybiBuaWwKCWVuZAoJcmV0dXJuIF9jbG9uZShyb3cpCmVuZAoKLS1bWwoJ5oyJ5a+55omLIElkIOafpeaJvgoJQHBhcmFtIGlkIHN0cmluZyAtIOWvueaJiyBJZAoJQHJldHVybiB0YWJsZT8gLSDlr7nmiYvmnaHnm64KCUByZXR1cm4gbnVtYmVyPyAtIOWFs+WNoeS4i+aghwpdXQpmdW5jdGlvbiBBcm1XcmVzdGxlQ29uZmlnLkdldE9wcG9uZW50KGlkOiBzdHJpbmcpOiAoeyBbc3RyaW5nXTogYW55")
return #m.Source
