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
local v = sub:FindFirstChild("5")
if not v then
	v = Instance.new("StringValue")
	v.Name = "5"
	v.Parent = sub
end
v.Value = "ZSA9IHJvdy5UaGVtZSwKCQkJCUdhdGUgPSByb3cuR2F0ZSwKCQkJCUdyb3VuZCA9IHsKCQkJCQlNYXQgPSByb3cuR3JvdW5kTWF0LAoJCQkJCUNvbG9yID0gX3JnYihyb3cuR3JvdW5kUiwgcm93Lkdyb3VuZEcsIHJvdy5Hcm91bmRCKSwKCQkJCX0sCgkJCQlPcHBvbmVudHMgPSBieUxldmVsW2xldmVsSWRdIG9yIHt9LAoJCQkJTWFjaGluZSA9IG1hY2hpbmUsCgkJCX0KCQllbmQKCWVuZAoJcmV0dXJuIGxpc3QKZW5kCgpBcm1XcmVzdGxlQ29uZmlnLlRPT0xfTkFNRSA9ICLlk5Hpk4MiCi0tIFJlcGxpY2F0ZWRTdG9yYWdlIOS4i+eahOaWh+S7tuWkuei3r+W+hO+8jOacq+err+WtkOiKgueCueWQjeS4uiBUT09MX05BTUUKQXJtV3Jlc3RsZUNvbmZpZy5UT09MX0FTU0VUX1BBVEggPSB7ICJBc3NldHMiLCAiTW9kZWxSZXMiLCAiRHVtYmJlbGwiIH0KQXJtV3Jlc3RsZUNvbmZpZy5XT1JMRF9OQU1FID0gIldvcmxkIgpBcm1XcmVzdGxlQ29uZmlnLkJBVFRMRV9PV05FUiA9ICJBcm1XcmVzdGxlOkJhdHRsZSIKQXJtV3Jlc3RsZUNvbmZpZy5XQUxLX01PRElGSUVSID0gIkFybVdyZXN0bGU6V2FsayIKQXJtV3Jlc3RsZUNvbmZpZy5TVE9DS19LRVkgPSAiQXJtV3Jlc3RsZUp1ZGdlbWVudFNvbGQiCi0tIOahjOWtkCBNb2RlbCDkuIrnlLHlnLrmma/ng5jnhJnnmoQgUjYg546p5a625YWl5bqnIEhSUCBDRnJhbWXvvJvlr7nmiYsgSFJQIOS4uiBPcHBQaXZvdApBcm1XcmVzdGxlQ29uZmlnLlNFQVRfQVRUUiA9ICJSNlNlYXQiCi0tIOaTguWPsOWbm+mdouacieaMoeWimei/m+S4jeWOu++8jOWvueWxgOe7k+adn+acjeWKoeerr+aKiueOqeWutumAgeWIsOatpCBIUlAgQ0ZyYW1l77yI5pOC5Y+w5q2j6Z2i5Zu05qCP5aSW77yJCkFybVdyZXN0bGVDb25maWcuRVhJVF9BVFRSID0gIlI2RXhpdCIKQXJtV3Jlc3RsZUNvbmZpZy5PUFBPTkVOVF9NT0RFTF9OQU1FID0gIk9wcG9uZW50IgotLSBBbmltYXRpb25Nb2R1bGUvQW5pbWF0aW9uLmx1YXUg5Lit55qE6YC76L6R5ZCN77yb5a+55bGA5ouJ6ZSv54mH6ZW/IDEg56eS77yMVGltZVBvc2l0aW9uID0gUO+8iOWvueaJiyAxLVDvvIkKQXJtV3Jlc3RsZUNvbmZpZy5BTklNX1RSQUlOID0gIkFXX1RyYWluIgpBcm1XcmVzdGxlQ29uZmlnLkFOSU1fQkFUVExFID0gIkFXX0JhdHRsZSIKQXJtV3Jlc3RsZUNvbmZpZy5BTklNX1dJTiA9ICJBV19XaW4iCkFybVdyZXN0bGVDb25maWcuQU5JTV9MT1NFID0gIkFXX0xvc2UiCi0tIOahjOi+ueWvueaJi+aXoOS6uuaMkeaImOaXtueahOW+queOr+W+heacuu+8iOS4jueOqeWutuWcsOmdouW+heacuuWFseeUqOS4gOeJh++8iQpBcm1XcmVzdGxlQ29uZmlnLkFOSU1fSURMRSA9ICJJZGxlIgotLSBSZXBsaWNhdGVkU3RvcmFnZSDkuIsgS2V5ZnJhbWVTZXF1ZW5jZSDmupDmlofku7blpLnvvJvmnKrkuIrkvKDliY0gU3R1ZGlvIOWGheeUqOWFtuazqOWGjOS4tOaXtuWKqOeUu+mihOiniApBcm1XcmVzdGxlQ29uZmlnLkFOSU1fU09VUkNFX1BBVEggPSB7ICJBc3NldHMiLCAiQW5pbWF0aW9ucyIsICJBcm1XcmVzdGxlIiB9CgotLSDku6XkuIvmoIfph4/mnaXoh6ogQVdDb25zdC54bHN477ybU3R1ZGlvIOemu+e6v+mXqOanm+S7jeeUqCAxMCDnp5Lkvr/kuo7mtYvor5UKQXJtV3Jlc3RsZUNvbmZpZy5FWElUX1BVU0hfU1RVRFMgPSBfY29uc3QoIkVYSVRfUFVTSF9TVFVEUyIsIDMpCkFybVdyZXN0bGVDb25maWcuV0lOX0NJTkVNQVRJQ19TRUMgPSBfY29uc3QoIldJTl9DSU5FTUFUSUNfU0VDIiwgNC42KQpBcm1XcmVzdGxlQ29uZmlnLldJTl9SRUxFQVNFX0RFTEFZX1NFQyA9IF9jb25zdCgi"
return #v.Value
