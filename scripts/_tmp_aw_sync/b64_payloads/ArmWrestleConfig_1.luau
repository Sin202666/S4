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
local v = sub:FindFirstChild("1")
if not v then
	v = Instance.new("StringValue")
	v.Name = "1"
	v.Parent = sub
end
v.Value = "dWx0IOeUsSBQcm9maWxlLkdldE11bHRzIOWUr+S4gOa2iOi0uQoJLSDoja/msLQgR2V0UG90aW9u77ya5bqT5a2Y5piv6IOM5YyF54mp5ZOB77yISXRlbUlkIOWvueW6lCBpdGVtZGF0YUNvbmYgMjAxfjIwM++8ie+8jOS9v+eUqOWQjuaMieWcqOe6v+enkuaVsOiuoeaXtu+8iOacjeWKoeerryBTeXN0ZW1Bcm1XcmVzdGxlLlBvdGlvbu+8iQoJLSDllYbln47liIbljLrpobrluo/vvJpTaG9wUGFzc09yZGVyIC8gU2hvcFBhY2tPcmRlciAvIFBvdGlvbk9yZGVyCgktIEZvcm1hdEZpeGVk77ya5LiJ5L2N5pyJ5pWI5pWw5a2X5Lu3562+77yIMS4wMFQgLyAxMC4wQu+8ie+8m0Zvcm1hdCDkuLrpgJrnlKjnvKnlhpnvvIjljrvlsL7pm7bvvIkKCS0g56a757q/5aWW5Yqx5Y+C5pWwIE9GRkxJTkVfUkFURSAvIE9GRkxJTkVfTUlOX1NFQyAvIE9GRkxJTkVfTUFYX1NFQ++8muacjeWKoeerryBTeXN0ZW1Bcm1XcmVzdGxlLk9mZmxpbmUg57uT566XCgktIOiPnOWNleaMveeVmeekvOeJqeWAjeaVsCBNRU5VX0dJRlRfQ0FTSF9NVUxU77ya5pyN5Yqh56uvIFN5c3RlbUFybVdyZXN0bGUuTWVudUdpZnQg57uT566X77yI5q+P6LSm5Y+35LiA5qyh77yJCgktIOaVsOWAvOiuvuiuoeivtOaYjuingSBkb2NzL+aJs+aJi+iFleaVsOWAvOiuvuiuoeivtOaYji5tZAoKCeWKoOi9ve+8mgoJCWxvY2FsIFV0aWxzID0gcmVxdWlyZShnYW1lLlJlcGxpY2F0ZWRGaXJzdC5BbGxTaWRlQ29kZS5VdGlsc1N5c3RlbSkKCQlsb2NhbCBBcm1XcmVzdGxlQ29uZmlnID0gVXRpbHMuQXJtV3Jlc3RsZUNvbmZpZwoJCWxvY2FsIGFybSA9IEFybVdyZXN0bGVDb25maWcuR2V0QXJtKDEpCl1dCgpsb2NhbCBSZXBsaWNhdGVkU3RvcmFnZSA9IGdhbWU6R2V0U2VydmljZSgiUmVwbGljYXRlZFN0b3JhZ2UiKQpsb2NhbCBSdW5TZXJ2aWNlID0gZ2FtZTpHZXRTZXJ2aWNlKCJSdW5TZXJ2aWNlIikKCmxvY2FsIFV0aWxzID0gcmVxdWlyZShnYW1lLlJlcGxpY2F0ZWRGaXJzdC5BbGxTaWRlQ29kZS5VdGlsc1N5c3RlbSkKbG9jYWwgQ29weSA9IFV0aWxzLkNvcHkKbG9jYWwgQ29uZmlnSW5zdGFuY2UgPSBVdGlscy5Db25maWdJbnN0YW5jZQoKbG9jYWwgQXJtV3Jlc3RsZUNvbmZpZyA9IHt9Cgpsb2NhbCBmdW5jdGlvbiBfY2xvbmUodmFsdWU6IGFueSk6IGFueQoJaWYgdHlwZSh2YWx1ZSkgfj0gInRhYmxlIiB0aGVuCgkJcmV0dXJuIHZhbHVlCgllbmQKCXJldHVybiBDb3B5LmRlZXBDb3B5KHZhbHVlKQplbmQKCi0tW1sKCeivuyBBV0NvbnN0IOaVsOWAvO+8m+e8uuihjOaIlue8uiBWYWx1ZSDml7bnlKggZmFsbGJhY2sKCUBwYXJhbSBrZXkgc3RyaW5nIC0g5bi46YeP6ZSu77yI5LiOIEFXQ29uc3QueGxzeCBLZXkg5LiA6Ie077yJCglAcGFyYW0gZmFsbGJhY2sgbnVtYmVyIC0g57y655yB5YC8CglAcmV0dXJuIG51bWJlciAtIOihqOWAvOaIliBmYWxsYmFjawpdXQpsb2NhbCBmdW5jdGlvbiBfY29uc3Qoa2V5OiBzdHJpbmcsIGZhbGxiYWNrOiBudW1iZXIpOiBudW1iZXIKCWxvY2FsIHJvdyA9IENvbmZpZ0luc3RhbmNlLmF3Y29uc3RDb25mIGFuZCBDb25maWdJbnN0YW5jZS5hd2NvbnN0Q29uZltrZXldCglsb2NhbCB2YWx1ZSA9IHJvdyBhbmQgcm93LlZhbHVlCglpZiB0eXBlKHZhbHVlKSA9PSAibnVtYmVyIiB0aGVuCgkJcmV0dXJuIHZhbHVlCgllbmQKCXJldHVybiBmYWxsYmFjawplbmQKCi0tW1sKCVJHQiDkuInliJfmi7wgQ29sb3IzCglAcGFyYW0gciBudW1iZXI/IC0g57qiIDDigJMyNTUKCUBwYXJhbSBnIG51bWJlcj8gLSDnu78gMOKAkzI1NQoJQHBhcmFtIGIgbnVtYmVyPyAtIOiTnSAw4oCT"
return #v.Value
