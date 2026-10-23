# -*- coding: utf-8 -*-
"""Print execute_luau code that sets LoadingUI.Source from base64 chunks."""
from pathlib import Path

chunks_dir = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_chunks")
count = int((chunks_dir / "count.txt").read_text(encoding="ascii").strip())
parts = [(chunks_dir / f"{i}.txt").read_text(encoding="ascii") for i in range(count)]

# Emit Luau with embedded chunks + pure Luau base64 decode
lines = [
	"local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'",
	"local function b64decode(data: string): string",
	"\tlocal t = {}",
	"\tdata = string.gsub(data, '[^'..alphabet..'=]', '')",
	"\tlocal i = 1",
	"\twhile i <= #data do",
	"\t\tlocal a = string.find(alphabet, string.sub(data, i, i)) or 1",
	"\t\tlocal b = string.find(alphabet, string.sub(data, i + 1, i + 1)) or 1",
	"\t\tlocal c = string.find(alphabet, string.sub(data, i + 2, i + 2)) or 1",
	"\t\tlocal d = string.find(alphabet, string.sub(data, i + 3, i + 3)) or 1",
	"\t\ta -= 1; b -= 1; c -= 1; d -= 1",
	"\t\tlocal n = a * 262144 + b * 4096 + c * 64 + d",
	"\t\tlocal x = math.floor(n / 65536) % 256",
	"\t\tlocal y = math.floor(n / 256) % 256",
	"\t\tlocal z = n % 256",
	"\t\ttable.insert(t, string.char(x))",
	"\t\tif string.sub(data, i + 2, i + 2) ~= '=' then table.insert(t, string.char(y)) end",
	"\t\tif string.sub(data, i + 3, i + 3) ~= '=' then table.insert(t, string.char(z)) end",
	"\t\ti += 4",
	"\tend",
	"\treturn table.concat(t)",
	"end",
	"local parts = {",
]
for p in parts:
	lines.append(f"\t[=[{p}]=],")
lines += [
	"}",
	"local src = b64decode(table.concat(parts))",
	"local m = game.ReplicatedFirst.AllSideCode.FirstPreload.LoadingUI",
	"m.Source = src",
	"return string.format('ok len=%d head=%s', #src, string.sub(src, 1, 40))",
]
out = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_apply.luau")
out.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"wrote {out} size={out.stat().st_size}")
