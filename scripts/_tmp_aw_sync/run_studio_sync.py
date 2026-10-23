# -*- coding: utf-8 -*-
"""Emit each wrapped append as a single JSON line for external runners; also verify rebuild."""
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
WRAPPED = ROOT / "wrapped"
OUT = ROOT / "mcp_codes"
OUT.mkdir(exist_ok=True)

# Rebuild append + wrap from current ArmWrestleConfig to be safe
src = (
	Path(r"d:/Git/Roblox/A4_Slap/src/ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau")
	.read_text(encoding="utf-8")
	.replace("\r\n", "\n")
)
assert "]=]" not in src
CHUNK = 3000
parts = [src[i : i + CHUNK] for i in range(0, len(src), CHUNK)]

DEC = '''local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
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
'''

# Clear script
(OUT / "00_clear.luau").write_text(
	'local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig\nm.Source = ""\nreturn #m.Source\n',
	encoding="utf-8",
	newline="\n",
)

for i, part in enumerate(parts):
	# Append script as UTF-8 bytes, then b64-wrap for ASCII-only execute_luau
	append = (
		"local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig\n"
		f"m.Source ..= [=[{part}]=]\n"
		"return #m.Source\n"
	).encode("utf-8")
	b64 = base64.b64encode(append).decode("ascii")
	code = DEC + f'local src = b64decode("{b64}")\nlocal fn, err = load(src)\nassert(fn, err)\nreturn fn()\n'
	(OUT / f"{i + 1:02d}.luau").write_text(code, encoding="utf-8", newline="\n")
	print(f"{i + 1:02d}.luau", len(code))

# Verify roundtrip
acc = []
for i, part in enumerate(parts):
	acc.append(part)
joined = "".join(acc)
assert joined == src
print("parts", len(parts), "chars", len(src), "roundtrip_ok")
