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
m.Source ..= b64decode("s5XkuLrmnKrotK3kubAKCUByZXR1cm4gbnVtYmVyIC0g5YCN5pWw77yb5pyq6LSt5Lmw5Li6IDEKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5HZXRTdHJlbmd0aFRpZXJNdWx0KHRpZXI6IG51bWJlcj8pOiBudW1iZXIKCWxvY2FsIGtleSA9IGlmIHR5cGUodGllcikgPT0gIm51bWJlciIgdGhlbiBfU1RSRU5HVEhfVElFUl9LRVlTW21hdGgubWluKHRpZXIsICNfU1RSRU5HVEhfVElFUl9LRVlTKV0gZWxzZSBuaWwKCWxvY2FsIHJvdyA9IGtleSBhbmQgX1BST0RVQ1RTW2tleV0KCXJldHVybiBpZiByb3cgdGhlbiByb3cuTXVsdCBlbHNlIDEKZW5kCgotLVtbCgnlpZbmsaDmpoLnjofvvIjmjInmnaHnm64gV2VpZ2h077yb5Yqg5oiQ6LaK6auYIFdlaWdodCDotorkvY4g4oaSIENoYW5jZSDotorkvY7vvIkKCUBwYXJhbSBwb29sIHtzdHJpbmd9IC0g5p2Q6LSoIElkIOWIl+ihqAoJQHJldHVybiB7dGFibGV9IC0geyBJZCwgQ2hhbmNlIH3vvJtDaGFuY2Ug5LmL5ZKM5Li6IDEKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5Qb29sT2Rkcyhwb29sOiB7IHN0cmluZyB9KTogeyB7IElkOiBzdHJpbmcsIENoYW5jZTogbnVtYmVyIH0gfQoJbG9jYWwgd2VpZ2h0cyA9IHRhYmxlLmNyZWF0ZSgjcG9vbCkKCWxvY2FsIHRvdGFsID0gMAoJZm9yIGksIGlkIGluIGlwYWlycyhwb29sKSBkbwoJCWxvY2FsIG1hdCA9IEFybVdyZXN0bGVDb25maWcuR2V0TWF0ZXJpYWwoaWQpCgkJbG9jYWwgcmFyaXR5ID0gbWF0IGFuZCBfUkFSSVRJRVNbbWF0LlJhcml0eV0KCQlsb2NhbCBiYXNlID0gKG1hdCBhbmQgbWF0LldlaWdodCkgb3IgKHJhcml0eSBhbmQgcmFyaXR5LldlaWdodCkgb3IgMQoJCWxvY2FsIHdlaWdodCA9IGlmIHR5cGUoYmFzZSkgPT0gIm51bWJlciIgYW5kIGJhc2UgPiAwIHRoZW4gYmFzZSBlbHNlIDAKCQl3ZWlnaHRzW2ldID0gd2VpZ2h0CgkJdG90YWwgKz0gd2VpZ2h0CgllbmQKCWxvY2FsIG9kZHMgPSB0YWJsZS5jcmVhdGUoI3Bvb2wpCglmb3IgaSwgaWQgaW4gaXBhaXJzKHBvb2wpIGRvCgkJb2Rkc1tpXSA9IHsgSWQgPSBpZCwgQ2hhbmNlID0gaWYgdG90YWwgPiAwIHRoZW4gd2VpZ2h0c1tpXSAvIHRvdGFsIGVsc2UgMCB9CgllbmQKCXJldHVybiBvZGRzCmVuZAoKLS1bWwoJ5LuO5aWW5rGg5oq95LiA5Liq5p2Q6LSoIElkCglAcGFyYW0gcG9vbCB7c3RyaW5nfSAtIOadkOi0qCBJZAoJQHJldHVybiBzdHJpbmc/IC0g5oq95Lit55qEIElkCl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuUGlja0Zyb21Qb29sKHBvb2w6IHsgc3RyaW5nIH0pOiBzdHJpbmc/Cglsb2NhbCBvZGRzID0gQXJtV3Jlc3RsZUNvbmZpZy5Qb29sT2Rkcyhwb29sKQoJaWYgI29kZHMgPT0gMCB0aGVuCgkJcmV0dXJuIG5pbAoJZW5kCglsb2NhbCByb2xsID0gbWF0aC5yYW5kb20oKQoJbG9jYWwgYWNjID0gMAoJZm9yIF8sIHJvdyBpbiBpcGFpcnMob2RkcykgZG8KCQlhY2MgKz0gcm93LkNoYW5jZQoJCWlmIHJvbGwgPD0gYWNjIHRoZW4KCQkJcmV0dXJuIHJvdy5JZAoJCWVuZAoJZW5kCglyZXR1cm4gb2Rkc1sjb2Rkc10uSWQKZW5kCgotLVtbCgnmlbDlrZfnvKnlhpkKCUBwYXJhbSBuIG51bWJlciAtIOWOn+WAvAoJQHJldHVybiBzdHJpbmcgLSDlsZXnpLrkuLIKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5Gb3JtYXQobjogbnVtYmVyKTogc3RyaW5nCgluID0gdG9udW1iZXIobikgb3IgMAoJbG9jYWwgc3VmZml4ZXMgPSB7ICIiLCAiSyIsICJNIiwgIkIiLCAiVCIsICJRYSIsICJRaSIgfQoJbG9jYWwgaSA9IDEKCXdoaWxlIG1hdGguYWJzKG4pID49IDEwMDAgYW5k")
return #m.Source
