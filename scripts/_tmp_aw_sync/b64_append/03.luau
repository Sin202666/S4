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
m.Source ..= b64decode("MjU1CglAcmV0dXJuIENvbG9yMyAtIOminOiJsgpdXQpsb2NhbCBmdW5jdGlvbiBfcmdiKHI6IG51bWJlcj8sIGc6IG51bWJlcj8sIGI6IG51bWJlcj8pOiBDb2xvcjMKCXJldHVybiBDb2xvcjMuZnJvbVJHQihyIG9yIDAsIGcgb3IgMCwgYiBvciAwKQplbmQKCi0tW1sKCeWvvOihqOihjOacgOWkp+aVsOWtl+S4u+mUrgoJQHBhcmFtIGNvbmYgdGFibGUgLSBDb25maWdJbnN0YW5jZSDlrZDooagKCUByZXR1cm4gbnVtYmVyIC0g5pyA5aSnIElk77yb56m66KGo5Li6IDAKXV0KbG9jYWwgZnVuY3Rpb24gX21heE51bWVyaWNLZXkoY29uZjogeyBbYW55XTogYW55IH0pOiBudW1iZXIKCWxvY2FsIG1heElkID0gMAoJZm9yIGlkIGluIHBhaXJzKGNvbmYpIGRvCgkJaWYgdHlwZShpZCkgPT0gIm51bWJlciIgYW5kIGlkID4gbWF4SWQgdGhlbgoJCQltYXhJZCA9IGlkCgkJZW5kCgllbmQKCXJldHVybiBtYXhJZAplbmQKCi0tW1sKCeS7jiBhd21hdGVyaWFsQ29uZiDnu4Too4XmnZDotKjmlbDnu4TvvIjmjIkgTXVsdCDljYfluo/vvJtPZmZlclByaWNlL1Byb2R1Y3RLZXkg5Li6IDAv56m65YiZ55yB55Wl5a2X5q6177yJCglAcmV0dXJuIHt0YWJsZX0gLSDmnZDotKjliJfooagKXV0KbG9jYWwgZnVuY3Rpb24gX2xvYWRNYXRlcmlhbHMoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9Cglsb2NhbCBjb25mID0gQ29uZmlnSW5zdGFuY2UuYXdtYXRlcmlhbENvbmYgb3Ige30KCWxvY2FsIGxpc3QgPSB7fQoJZm9yIGlkLCByb3cgaW4gcGFpcnMoY29uZikgZG8KCQlpZiB0eXBlKHJvdykgPT0gInRhYmxlIiBhbmQgdHlwZShpZCkgPT0gInN0cmluZyIgdGhlbgoJCQlsb2NhbCBlbnRyeTogeyBbc3RyaW5nXTogYW55IH0gPSB7CgkJCQlJZCA9IGlkLAoJCQkJWmhOYW1lID0gcm93LlpoTmFtZSwKCQkJCU11bHQgPSByb3cuTXVsdCwKCQkJCVJhcml0eSA9IHJvdy5SYXJpdHksCgkJCQlXZWlnaHQgPSByb3cuV2VpZ2h0LAoJCQkJTWF0ID0gcm93Lk1hdCwKCQkJCUNvbG9yID0gX3JnYihyb3cuQ29sb3JSLCByb3cuQ29sb3JHLCByb3cuQ29sb3JCKSwKCQkJCUljb24gPSByb3cuSWNvbiwKCQkJfQoJCQlpZiB0eXBlKHJvdy5PZmZlclByaWNlKSA9PSAibnVtYmVyIiBhbmQgcm93Lk9mZmVyUHJpY2UgPiAwIHRoZW4KCQkJCWVudHJ5Lk9mZmVyUHJpY2UgPSByb3cuT2ZmZXJQcmljZQoJCQllbmQKCQkJaWYgdHlwZShyb3cuUHJvZHVjdEtleSkgPT0gInN0cmluZyIgYW5kIHJvdy5Qcm9kdWN0S2V5IH49ICIiIHRoZW4KCQkJCWVudHJ5LlByb2R1Y3RLZXkgPSByb3cuUHJvZHVjdEtleQoJCQllbmQKCQkJdGFibGUuaW5zZXJ0KGxpc3QsIGVudHJ5KQoJCWVuZAoJZW5kCgl0YWJsZS5zb3J0KGxpc3QsIGZ1bmN0aW9uKGEsIGIpCgkJcmV0dXJuIChhLk11bHQgb3IgMCkgPCAoYi5NdWx0IG9yIDApCgllbmQpCglyZXR1cm4gbGlzdAplbmQKCi0tW1sKCeS7jiBhd2FybUNvbmYg57uE6KOF5omL6IeC56ig5a+G5pWw57uE77ybUm9idXgvTGltaXRlZC9Qcm9kdWN0S2V5IOS7heWcqCA+MCAvIOmdnuepuuaXtuWGmeWFpe+8iOWFvOWuuSBpZiBhcm0uUm9idXjvvIkKCUByZXR1cm4ge3RhYmxlfSAtIOaJi+iHguWIl+ihqO+8iOS4i+aghz1JZO+8iQpdXQpsb2NhbCBmdW5jdGlvbiBfbG9hZEFybXMoKTogeyB7IFtzdHJpbmddOiBhbnkgfSB9Cglsb2NhbCBjb25mID0gQ29uZmlnSW5zdGFuY2UuYXdhcm1Db25mIG9yIHt9Cglsb2NhbCBtYXhJZCA9IF9tYXhOdW1lcmljS2V5KGNvbmYpCglsb2NhbCBsaXN0ID0gdGFibGUuY3JlYXRlKG1heElkKQoJZm9yIGlkID0gMSwgbWF4SWQgZG8KCQlsb2NhbCBy")
return #m.Source
