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
local v = sub:FindFirstChild("6")
if not v then
	v = Instance.new("StringValue")
	v.Name = "6"
	v.Parent = sub
end
v.Value = "V0lOX1JFTEVBU0VfREVMQVlfU0VDIiwgNS4yKQpBcm1XcmVzdGxlQ29uZmlnLkxPU0VfUkVMRUFTRV9ERUxBWV9TRUMgPSBfY29uc3QoIkxPU0VfUkVMRUFTRV9ERUxBWV9TRUMiLCAyLjYpCkFybVdyZXN0bGVDb25maWcuTElNSVRFRF9BUk1fSUQgPSBfY29uc3QoIkxJTUlURURfQVJNX0lEIiwgMTIpCkFybVdyZXN0bGVDb25maWcuTElNSVRFRF9TT0xEX0RFRkFVTFQgPSBfY29uc3QoIkxJTUlURURfU09MRF9ERUZBVUxUIiwgOTYpCkFybVdyZXN0bGVDb25maWcuTkVBUl9NQUNISU5FX1NUVURTID0gX2NvbnN0KCJORUFSX01BQ0hJTkVfU1RVRFMiLCAyNSkKQXJtV3Jlc3RsZUNvbmZpZy5UQUJMRV9QUk9NUFRfRElTVEFOQ0UgPSBfY29uc3QoIlRBQkxFX1BST01QVF9ESVNUQU5DRSIsIDE4KQpBcm1XcmVzdGxlQ29uZmlnLlJPTExfQU5JTV9TRUMgPSBfY29uc3QoIlJPTExfQU5JTV9TRUMiLCAzLjIpCkFybVdyZXN0bGVDb25maWcuUk9MTF9DT09MRE9XTl9TRUMgPSBBcm1XcmVzdGxlQ29uZmlnLlJPTExfQU5JTV9TRUMKQXJtV3Jlc3RsZUNvbmZpZy5GUklFTkRfQk9PU1RfUEVSID0gX2NvbnN0KCJGUklFTkRfQk9PU1RfUEVSIiwgMC4xKQpBcm1XcmVzdGxlQ29uZmlnLkZSSUVORF9CT09TVF9NQVggPSBfY29uc3QoIkZSSUVORF9CT09TVF9NQVgiLCAwLjUpCkFybVdyZXN0bGVDb25maWcuUFJFTUlVTV9CT09TVCA9IF9jb25zdCgiUFJFTUlVTV9CT09TVCIsIDAuMjUpCkFybVdyZXN0bGVDb25maWcuT0ZGTElORV9SQVRFID0gX2NvbnN0KCJPRkZMSU5FX1JBVEUiLCAwLjEpCkFybVdyZXN0bGVDb25maWcuT0ZGTElORV9NSU5fU0VDID0gaWYgUnVuU2VydmljZTpJc1N0dWRpbygpIHRoZW4gMTAgZWxzZSBfY29uc3QoIk9GRkxJTkVfTUlOX1NFQyIsIDMwMCkKQXJtV3Jlc3RsZUNvbmZpZy5PRkZMSU5FX01BWF9TRUMgPSBfY29uc3QoIk9GRkxJTkVfTUFYX1NFQyIsIDI4ODAwKQpBcm1XcmVzdGxlQ29uZmlnLk1FTlVfR0lGVF9DQVNIX01VTFQgPSBfY29uc3QoIk1FTlVfR0lGVF9DQVNIX01VTFQiLCAxMCkKQXJtV3Jlc3RsZUNvbmZpZy5ab25lTGVuZ3RoID0gX2NvbnN0KCJab25lTGVuZ3RoIiwgMTcwKQpBcm1XcmVzdGxlQ29uZmlnLlpvbmVXaWR0aCA9IF9jb25zdCgiWm9uZVdpZHRoIiwgMTMwKQpBcm1XcmVzdGxlQ29uZmlnLkJhdHRsZVRpbWUgPSBfY29uc3QoIkJhdHRsZVRpbWUiLCAxNSkKQXJtV3Jlc3RsZUNvbmZpZy5UYXBQb3dlciA9IF9jb25zdCgiVGFwUG93ZXIiLCAwLjAzNSkKQXJtV3Jlc3RsZUNvbmZpZy5PcHBvbmVudERyaWZ0ID0gX2NvbnN0KCJPcHBvbmVudERyaWZ0IiwgMC4xMykKQXJtV3Jlc3RsZUNvbmZpZy5NYXhUYXBzUGVyU2Vjb25kID0gX2NvbnN0KCJNYXhUYXBzUGVyU2Vjb25kIiwgMTQpCkFybVdyZXN0bGVDb25maWcuQXV0b1RhcHNQZXJTZWNvbmQgPSBfY29uc3QoIkF1dG9UYXBzUGVyU2Vjb25kIiwgOCkKCmxvY2FsIF9SQVJJVElFUyA9IHsKCUNvbW1vbiA9IHsgWmhOYW1lID0gIuaZrumAmiIsIENvbG9yID0gQ29sb3IzLmZyb21SR0IoMTcwLCAxNzAsIDE3MCksIFdlaWdodCA9IDYwLCBSYW5rID0gMSB9LAoJVW5jb21tb24gPSB7IFpoTmFtZSA9ICLkvJjnp4AiLCBDb2xvciA9IENvbG9yMy5mcm9tUkdCKDg1LCAyMjAsIDkwKSwgV2VpZ2h0ID0gMzAsIFJhbmsgPSAyIH0sCglSYXJlID0geyBaaE5hbWUgPSAi56iA5pyJIiwgQ29sb3IgPSBDb2xvcjMuZnJvbVJHQig3MCwgMTYwLCAyNTUpLCBXZWlnaHQgPSAxMiwgUmFuayA9IDMgfSwKCUVwaWMgPSB7IFpoTmFtZSA9ICLlj7Lor5ciLCBDb2xvciA9IENvbG9yMy5mcm9tUkdC"
return #v.Value
