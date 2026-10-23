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
m.Source ..= b64decode("IGV4aXRDZi5Qb3NpdGlvbiArIGV4aXRDZi5Mb29rVmVjdG9yICogQXJtV3Jlc3RsZUNvbmZpZy5FWElUX1BVU0hfU1RVRFMKCWxvY2FsIGNlbnRlciA9IHRhYmxlTW9kZWw6R2V0QXR0cmlidXRlKCJQaXZvdCIpCglpZiB0eXBlb2YoY2VudGVyKSB+PSAiVmVjdG9yMyIgdGhlbgoJCWNlbnRlciA9IHRhYmxlTW9kZWw6R2V0UGl2b3QoKS5Qb3NpdGlvbgoJZW5kCglsb2NhbCBsb29rID0gVmVjdG9yMy5uZXcoY2VudGVyLlgsIHBvcy5ZLCBjZW50ZXIuWikKCWlmIChsb29rIC0gcG9zKS5NYWduaXR1ZGUgPCAxZS0zIHRoZW4KCQlyZXR1cm4gQ0ZyYW1lLm5ldyhwb3MpICogZXhpdENmLlJvdGF0aW9uCgllbmQKCXJldHVybiBDRnJhbWUubG9va0F0KHBvcywgbG9vaykKZW5kCgotLVtbCgnln7rnoYDooYzotbDpgJ/luqbvvIhDTVMg6buY6K6k77yJCglAcmV0dXJuIG51bWJlciAtIDE2Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0QmFzZVdhbGtTcGVlZCgpOiBudW1iZXIKCXJldHVybiBfV0FMS19TUEVFRFsxXS5WYWx1ZQplbmQKCi0tW1sKCeafpeaJvuWTkemTgyBUb29sIOaooeadv++8iFJlcGxpY2F0ZWRTdG9yYWdlIC8gVE9PTF9BU1NFVF9QQVRIIC8gVE9PTF9OQU1F77yJCglAcmV0dXJuIFRvb2w/IC0g5qih5p2/5pys5L2T77yM6LCD55So5pa56aG7IENsb25lIOWQjuS9v+eUqOOAgeemgeatouebtOaOpeS/ruaUue+8m+i3r+W+hOe8uuWkseaIluexu+Wei+S4jeaYryBUb29sIOaXtuS4uiBuaWwKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5GaW5kVG9vbFRlbXBsYXRlKCk6IFRvb2w/Cglsb2NhbCBub2RlOiBJbnN0YW5jZT8gPSBSZXBsaWNhdGVkU3RvcmFnZQoJZm9yIF8sIG5hbWUgaW4gaXBhaXJzKEFybVdyZXN0bGVDb25maWcuVE9PTF9BU1NFVF9QQVRIKSBkbwoJCW5vZGUgPSBub2RlIGFuZCBub2RlOkZpbmRGaXJzdENoaWxkKG5hbWUpCgllbmQKCWxvY2FsIHRlbXBsYXRlID0gbm9kZSBhbmQgbm9kZTpGaW5kRmlyc3RDaGlsZChBcm1XcmVzdGxlQ29uZmlnLlRPT0xfTkFNRSkKCWlmIHRlbXBsYXRlIGFuZCB0ZW1wbGF0ZTpJc0EoIlRvb2wiKSB0aGVuCgkJcmV0dXJuIHRlbXBsYXRlCgllbmQKCXJldHVybiBuaWwKZW5kCgpyZXR1cm4gQXJtV3Jlc3RsZUNvbmZpZwo=")
return #m.Source
