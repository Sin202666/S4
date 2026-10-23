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
m.Source ..= b64decode("V0lOX1JFTEVBU0VfREVMQVlfU0VDIiwgNS4yKQpBcm1XcmVzdGxlQ29uZmlnLkxPU0VfUkVMRUFTRV9ERUxBWV9TRUMgPSBfY29uc3QoIkxPU0VfUkVMRUFTRV9ERUxBWV9TRUMiLCAyLjYpCkFybVdyZXN0bGVDb25maWcuTElNSVRFRF9BUk1fSUQgPSBfY29uc3QoIkxJTUlURURfQVJNX0lEIiwgMTIpCkFybVdyZXN0bGVDb25maWcuTElNSVRFRF9TT0xEX0RFRkFVTFQgPSBfY29uc3QoIkxJTUlURURfU09MRF9ERUZBVUxUIiwgOTYpCkFybVdyZXN0bGVDb25maWcuTkVBUl9NQUNISU5FX1NUVURTID0gX2NvbnN0KCJORUFSX01BQ0hJTkVfU1RVRFMiLCAyNSkKQXJtV3Jlc3RsZUNvbmZpZy5UQUJMRV9QUk9NUFRfRElTVEFOQ0UgPSBfY29uc3QoIlRBQkxFX1BST01QVF9ESVNUQU5DRSIsIDE4KQpBcm1XcmVzdGxlQ29uZmlnLlJPTExfQU5JTV9TRUMgPSBfY29uc3QoIlJPTExfQU5JTV9TRUMiLCAzLjIpCkFybVdyZXN0bGVDb25maWcuUk9MTF9DT09MRE9XTl9TRUMgPSBBcm1XcmVzdGxlQ29uZmlnLlJPTExfQU5JTV9TRUMKQXJtV3Jlc3RsZUNvbmZpZy5GUklFTkRfQk9PU1RfUEVSID0gX2NvbnN0KCJGUklFTkRfQk9PU1RfUEVSIiwgMC4xKQpBcm1XcmVzdGxlQ29uZmlnLkZSSUVORF9CT09TVF9NQVggPSBfY29uc3QoIkZSSUVORF9CT09TVF9NQVgiLCAwLjUpCkFybVdyZXN0bGVDb25maWcuUFJFTUlVTV9CT09TVCA9IF9jb25zdCgiUFJFTUlVTV9CT09TVCIsIDAuMjUpCkFybVdyZXN0bGVDb25maWcuT0ZGTElORV9SQVRFID0gX2NvbnN0KCJPRkZMSU5FX1JBVEUiLCAwLjEpCkFybVdyZXN0bGVDb25maWcuT0ZGTElORV9NSU5fU0VDID0gaWYgUnVuU2VydmljZTpJc1N0dWRpbygpIHRoZW4gMTAgZWxzZSBfY29uc3QoIk9GRkxJTkVfTUlOX1NFQyIsIDMwMCkKQXJtV3Jlc3RsZUNvbmZpZy5PRkZMSU5FX01BWF9TRUMgPSBfY29uc3QoIk9GRkxJTkVfTUFYX1NFQyIsIDI4ODAwKQpBcm1XcmVzdGxlQ29uZmlnLk1FTlVfR0lGVF9DQVNIX01VTFQgPSBfY29uc3QoIk1FTlVfR0lGVF9DQVNIX01VTFQiLCAxMCkKQXJtV3Jlc3RsZUNvbmZpZy5ab25lTGVuZ3RoID0gX2NvbnN0KCJab25lTGVuZ3RoIiwgMTcwKQpBcm1XcmVzdGxlQ29uZmlnLlpvbmVXaWR0aCA9IF9jb25zdCgiWm9uZVdpZHRoIiwgMTMwKQpBcm1XcmVzdGxlQ29uZmlnLkJhdHRsZVRpbWUgPSBfY29uc3QoIkJhdHRsZVRpbWUiLCAxNSkKQXJtV3Jlc3RsZUNvbmZpZy5UYXBQb3dlciA9IF9jb25zdCgiVGFwUG93ZXIiLCAwLjAzNSkKQXJtV3Jlc3RsZUNvbmZpZy5PcHBvbmVudERyaWZ0ID0gX2NvbnN0KCJPcHBvbmVudERyaWZ0IiwgMC4xMykKQXJtV3Jlc3RsZUNvbmZpZy5NYXhUYXBzUGVyU2Vjb25kID0gX2NvbnN0KCJNYXhUYXBzUGVyU2Vjb25kIiwgMTQpCkFybVdyZXN0bGVDb25maWcuQXV0b1RhcHNQZXJTZWNvbmQgPSBfY29uc3QoIkF1dG9UYXBzUGVyU2Vjb25kIiwgOCkKCmxvY2FsIF9SQVJJVElFUyA9IHsKCUNvbW1vbiA9IHsgWmhOYW1lID0gIuaZrumAmiIsIENvbG9yID0gQ29sb3IzLmZyb21SR0IoMTcwLCAxNzAsIDE3MCksIFdlaWdodCA9IDYwLCBSYW5rID0gMSB9LAoJVW5jb21tb24gPSB7IFpoTmFtZSA9ICLkvJjnp4AiLCBDb2xvciA9IENvbG9yMy5mcm9tUkdCKDg1LCAyMjAsIDkwKSwgV2VpZ2h0ID0gMzAsIFJhbmsgPSAyIH0sCglSYXJlID0geyBaaE5hbWUgPSAi56iA5pyJIiwgQ29sb3IgPSBDb2xvcjMuZnJvbVJHQig3MCwgMTYwLCAyNTUpLCBXZWlnaHQgPSAxMiwgUmFuayA9IDMgfSwKCUVwaWMgPSB7IFpoTmFtZSA9ICLlj7Lor5ciLCBDb2xvciA9IENvbG9yMy5mcm9tUkdC")
return #m.Source
