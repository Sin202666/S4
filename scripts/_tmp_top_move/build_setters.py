# -*- coding: utf-8 -*-
import pathlib

OUT = pathlib.Path(__file__).resolve().parent
ROOT = OUT

DECODE = r'''
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local function decode(data)
	data = string.gsub(data, "[^" .. alphabet .. "=]", "")
	local out = table.create(math.floor(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = string.find(alphabet, string.sub(data, i, i), 1, true) or 1
		local b = string.find(alphabet, string.sub(data, i + 1, i + 1), 1, true) or 1
		local c = string.find(alphabet, string.sub(data, i + 2, i + 2), 1, true) or 65
		local d = string.find(alphabet, string.sub(data, i + 3, i + 3), 1, true) or 65
		a, b, c, d = a - 1, b - 1, c - 1, d - 1
		n += 1
		out[n] = string.char(bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		if c < 64 then
			n += 1
			out[n] = string.char(bit32.bor(bit32.lshift(bit32.band(b, 15), 4), bit32.rshift(c, 2)))
		end
		if d < 64 then
			n += 1
			out[n] = string.char(bit32.bor(bit32.lshift(bit32.band(c, 3), 6), d))
		end
	end
	return table.concat(out)
end
'''

TARGETS = {
	"Common": "game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Common",
	"EdgeSlide": "game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.EdgeSlide",
	"TipsAnchor": "game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.TipsAnchor",
	"init": "game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD",
}


def make_setter(name: str, path: str, b64: str) -> str:
	chunks = [b64[i : i + 4000] for i in range(0, len(b64), 4000)]
	lines = ["local parts = {"]
	for c in chunks:
		lines.append("\t[[" + c + "]],")
	lines.append("}")
	lines.append("local b64 = table.concat(parts)")
	lines.append(DECODE)
	lines.append("local src = decode(b64)")
	lines.append(f"local m = {path}")
	lines.append("m.Source = src")
	lines.append(
		'return { ok = true, name = "'
		+ name
		+ '", len = #src, head = string.sub(src, 1, 40), tail = string.sub(src, math.max(1, #src - 40)) }'
	)
	return "\n".join(lines)


def main() -> None:
	for name, path in TARGETS.items():
		b64 = (OUT / f"{name}.luau.b64").read_text(encoding="ascii")
		text = make_setter(name, path, b64)
		out = OUT / f"set_{name}.luau"
		out.write_text(text, encoding="utf-8")
		print(name, out.stat().st_size)


if __name__ == "__main__":
	main()
