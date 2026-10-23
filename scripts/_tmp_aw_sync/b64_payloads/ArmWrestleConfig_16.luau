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
local v = sub:FindFirstChild("16")
if not v then
	v = Instance.new("StringValue")
	v.Name = "16"
	v.Parent = sub
end
v.Value = "IGV4aXRDZi5Qb3NpdGlvbiArIGV4aXRDZi5Mb29rVmVjdG9yICogQXJtV3Jlc3RsZUNvbmZpZy5FWElUX1BVU0hfU1RVRFMKCWxvY2FsIGNlbnRlciA9IHRhYmxlTW9kZWw6R2V0QXR0cmlidXRlKCJQaXZvdCIpCglpZiB0eXBlb2YoY2VudGVyKSB+PSAiVmVjdG9yMyIgdGhlbgoJCWNlbnRlciA9IHRhYmxlTW9kZWw6R2V0UGl2b3QoKS5Qb3NpdGlvbgoJZW5kCglsb2NhbCBsb29rID0gVmVjdG9yMy5uZXcoY2VudGVyLlgsIHBvcy5ZLCBjZW50ZXIuWikKCWlmIChsb29rIC0gcG9zKS5NYWduaXR1ZGUgPCAxZS0zIHRoZW4KCQlyZXR1cm4gQ0ZyYW1lLm5ldyhwb3MpICogZXhpdENmLlJvdGF0aW9uCgllbmQKCXJldHVybiBDRnJhbWUubG9va0F0KHBvcywgbG9vaykKZW5kCgotLVtbCgnln7rnoYDooYzotbDpgJ/luqbvvIhDTVMg6buY6K6k77yJCglAcmV0dXJuIG51bWJlciAtIDE2Cl1dCmZ1bmN0aW9uIEFybVdyZXN0bGVDb25maWcuR2V0QmFzZVdhbGtTcGVlZCgpOiBudW1iZXIKCXJldHVybiBfV0FMS19TUEVFRFsxXS5WYWx1ZQplbmQKCi0tW1sKCeafpeaJvuWTkemTgyBUb29sIOaooeadv++8iFJlcGxpY2F0ZWRTdG9yYWdlIC8gVE9PTF9BU1NFVF9QQVRIIC8gVE9PTF9OQU1F77yJCglAcmV0dXJuIFRvb2w/IC0g5qih5p2/5pys5L2T77yM6LCD55So5pa56aG7IENsb25lIOWQjuS9v+eUqOOAgeemgeatouebtOaOpeS/ruaUue+8m+i3r+W+hOe8uuWkseaIluexu+Wei+S4jeaYryBUb29sIOaXtuS4uiBuaWwKXV0KZnVuY3Rpb24gQXJtV3Jlc3RsZUNvbmZpZy5GaW5kVG9vbFRlbXBsYXRlKCk6IFRvb2w/Cglsb2NhbCBub2RlOiBJbnN0YW5jZT8gPSBSZXBsaWNhdGVkU3RvcmFnZQoJZm9yIF8sIG5hbWUgaW4gaXBhaXJzKEFybVdyZXN0bGVDb25maWcuVE9PTF9BU1NFVF9QQVRIKSBkbwoJCW5vZGUgPSBub2RlIGFuZCBub2RlOkZpbmRGaXJzdENoaWxkKG5hbWUpCgllbmQKCWxvY2FsIHRlbXBsYXRlID0gbm9kZSBhbmQgbm9kZTpGaW5kRmlyc3RDaGlsZChBcm1XcmVzdGxlQ29uZmlnLlRPT0xfTkFNRSkKCWlmIHRlbXBsYXRlIGFuZCB0ZW1wbGF0ZTpJc0EoIlRvb2wiKSB0aGVuCgkJcmV0dXJuIHRlbXBsYXRlCgllbmQKCXJldHVybiBuaWwKZW5kCgpyZXR1cm4gQXJtV3Jlc3RsZUNvbmZpZwo="
return #v.Value
