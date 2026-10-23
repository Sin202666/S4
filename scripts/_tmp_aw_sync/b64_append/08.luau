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
m.Source ..= b64decode("KDE4MCwgOTAsIDI1NSksIFdlaWdodCA9IDUsIFJhbmsgPSA0IH0sCglMZWdlbmRhcnkgPSB7IFpoTmFtZSA9ICLkvKDor7QiLCBDb2xvciA9IENvbG9yMy5mcm9tUkdCKDI1NSwgMTcwLCAzMCksIFdlaWdodCA9IDEuNSwgUmFuayA9IDUgfSwKCU15dGhpYyA9IHsgWmhOYW1lID0gIuelnuivnSIsIENvbG9yID0gQ29sb3IzLmZyb21SR0IoMjU1LCA2MCwgODApLCBXZWlnaHQgPSAwLjQsIFJhbmsgPSA2IH0sCglFeGNsdXNpdmUgPSB7IFpoTmFtZSA9ICLkuJPlsZ4iLCBDb2xvciA9IENvbG9yMy5mcm9tUkdCKDI1NSwgOTAsIDIyMCksIFdlaWdodCA9IDAsIFJhbmsgPSA3IH0sCn0KCmxvY2FsIF9NQVRFUklBTFMgPSBfbG9hZE1hdGVyaWFscygpCmxvY2FsIF9BUk1TID0gX2xvYWRBcm1zKCkKbG9jYWwgX0RVTUJCRUxMUyA9IF9sb2FkRHVtYmJlbGxzKCkKbG9jYWwgX1RSQUlOX1NQRUVEID0gX2xvYWRVcGdyYWRlS2luZCgiVHJhaW5TcGVlZCIpCmxvY2FsIF9XQUxLX1NQRUVEID0gX2xvYWRVcGdyYWRlS2luZCgiV2Fsa1NwZWVkIikKbG9jYWwgX0xFVkVMUyA9IF9sb2FkTGV2ZWxzKCkKCmxvY2FsIF9HQU1FX1BBU1NFUyA9IHsKCUF1dG9DbGlja2VyID0geyBJZCA9IDIwMzgzMjI1MjAsIFpoTmFtZSA9ICLoh6rliqjngrnlh7siLCBaaERlcyA9ICLorq3nu4PlkozmibPmiYvohZXoh6rliqjngrnlh7siLCBSb2J1eCA9IDk5IH0sCglEb3VibGVTdHJlbmd0aCA9IHsgSWQgPSAyMDM2OTk2NTM4LCBaaE5hbWUgPSAiMiDlgI3lipvph48iLCBaaERlcyA9ICLmsLjkuYXojrflvpflj4zlgI3lipvph48iLCBSb2J1eCA9IDE0OSB9LAoJRG91YmxlQ2FzaCA9IHsgSWQgPSAyMDQwMDU2MjcxLCBaaE5hbWUgPSAiMiDlgI3ph5HpkrEiLCBaaERlcyA9ICLmsLjkuYXojrflvpflj4zlgI3ph5HpkrEiLCBSb2J1eCA9IDEyOSB9LAp9Cgpsb2NhbCBfUFJPRFVDVFMgPSB7CglIb2x5QXJtID0geyBJZCA9IDAsIFpoTmFtZSA9ICLnpZ7lnKPkuYvoh4IiLCBaaERlcyA9ICI0MCDlgI3lipvph4/miYvoh4IiLCBSb2J1eCA9IDI0OSwgS2luZCA9ICJBcm0iLCBBcm1JZCA9IDExIH0sCglKdWRnZW1lbnRBcm0gPSB7IElkID0gMCwgWmhOYW1lID0gIuWuoeWIpOS5i+iHgiAo6ZmQ6YePKSIsIFpoRGVzID0gIjYwIOWAjeWKm+mHj++8jOWFqOacjemZkOmHjyAyNTAg5LiqIiwgUm9idXggPSAzOTksIEtpbmQgPSAiQXJtIiwgQXJtSWQgPSAxMiB9LAoJQXJjYW5lTWF0ZXJpYWwgPSB7IElkID0gMCwgWmhOYW1lID0gIuWlpeacr+adkOi0qCIsIFpoRGVzID0gIjEwMCDlgI3lipvph4/mnZDotKgiLCBSb2J1eCA9IDQ5OSwgS2luZCA9ICJNYXRlcmlhbCIsIE1hdElkID0gIkFyY2FuZSIgfSwKCS0tIOWKm+mHj+WAjeaVsOaho++8muabv+aNouW8j++8iOW9k+WJjeahoyBNdWx0IOWNs+aAu+WAjeaVsO+8ie+8jOmhu+aMiSBUaWVyIOmhuuW6j+Wxleekuu+8m+WtmOahoyBBcm1XcmVzdGxlLlN0cmVuZ3RoVGllcgoJU3RyZW5ndGhUaWVyMSA9IHsgSWQgPSAzNzE4Njc0Mzk4LCBaaE5hbWUgPSAi5Yqb6YeP5YCN5pWwIiwgUm9idXggPSAxOSwgS2luZCA9ICJTdHJlbmd0aFRpZXIiLCBUaWVyID0gMSwgTXVsdCA9IDIgfSwKCVN0cmVuZ3RoVGllcjIgPSB7IElkID0gMzcxODY3NDQwMywgWmhOYW1lID0gIuWKm+mHj+WAjeaVsCIsIFJvYnV4ID0gNDksIEtpbmQgPSAiU3RyZW5ndGhUaWVyIiwgVGllciA9IDIsIE11bHQgPSA0IH0sCglTdHJlbmd0aFRpZXIzID0geyBJZCA9IDM3MTg2NzQ0MDYsIFpoTmFtZSA9ICLlipvph4/lgI3mlbAiLCBSb2J1eCA9IDk5LCBLaW5kID0gIlN0cmVuZ3RoVGllciIs")
return #m.Source
