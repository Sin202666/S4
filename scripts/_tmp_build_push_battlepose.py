# -*- coding: utf-8 -*-
import pathlib

b64 = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_battlepose_b64.txt").read_text(encoding="ascii").strip()

luau = f"""local b64 = [[{b64}]]
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function decode(data)
	local out = table.create(math.floor(#data * 0.75))
	local nOut = 0
	data = string.gsub(data, "[^" .. alphabet .. "=]", "")
	for i = 1, #data, 4 do
		local a = (string.find(alphabet, string.sub(data, i, i), 1, true) or 1) - 1
		local b = (string.find(alphabet, string.sub(data, i + 1, i + 1), 1, true) or 1) - 1
		local cCh = string.sub(data, i + 2, i + 2)
		local dCh = string.sub(data, i + 3, i + 3)
		local c = if cCh ~= "=" then (string.find(alphabet, cCh, 1, true) or 1) - 1 else 0
		local d = if dCh ~= "=" then (string.find(alphabet, dCh, 1, true) or 1) - 1 else 0
		local n = a * 262144 + b * 4096 + c * 64 + d
		nOut += 1
		out[nOut] = string.char(math.floor(n / 65536) % 256)
		if cCh ~= "=" then
			nOut += 1
			out[nOut] = string.char(math.floor(n / 256) % 256)
		end
		if dCh ~= "=" then
			nOut += 1
			out[nOut] = string.char(n % 256)
		end
	end
	return table.concat(out)
end
local src = decode(b64)
local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose
m.Source = src
local ses = game:GetService("ScriptEditorService")
pcall(function()
	ses:UpdateSourceAsync(m, function()
		return src
	end)
end)
return string.format(
	"ok len=%d hasForward=%s hasInset=%s leftReach=%s",
	#src,
	tostring(string.find(src, "RIGHT_MEET_FORWARD", 1, true) ~= nil),
	tostring(string.find(src, "LEFT_TABLE_INSET", 1, true) ~= nil),
	tostring(string.find(src, "LEFT_REACH_MAX_SCALE", 1, true) ~= nil)
)
"""

out = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_push_battlepose.luau")
out.write_text(luau, encoding="utf-8", newline="\n")
print("wrote", out, "bytes", out.stat().st_size)
