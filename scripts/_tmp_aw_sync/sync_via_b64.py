# -*- coding: utf-8 -*-
"""Print execute_luau payloads (base64) for Studio Source sync."""
from __future__ import annotations

import base64
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "b64_payloads"
OUT.mkdir(parents=True, exist_ok=True)

B64_DEC = r'''
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
'''

TARGETS = {
	"ConfigInstance": "game.ReplicatedFirst.AllSideCode.ToolBasic.ConfigInstance",
	"ArmWrestleConfig": "game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig",
}

# Smaller b64 pieces so MCP JSON stays comfortable
PIECE = 2400

for name, studio_path in TARGETS.items():
	text = (
		Path(
			r"d:/Git/Roblox/A4_Slap/src/ReplicatedFirst/AllSideCode"
			+ ("/ToolBasic/ConfigInstance.luau" if name == "ConfigInstance" else "/ToolSystem/ArmWrestleConfig.luau")
		)
		.read_text(encoding="utf-8")
		.replace("\r\n", "\n")
	)
	raw = text.encode("utf-8")
	b64 = base64.b64encode(raw).decode("ascii")
	pieces = [b64[i : i + PIECE] for i in range(0, len(b64), PIECE)]
	(OUT / f"{name}_count.txt").write_text(str(len(pieces)), encoding="utf-8")
	for i, piece in enumerate(pieces):
		code = "\n".join(
			[
				B64_DEC.strip(),
				'local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")',
				"if not folder then",
				'\tfolder = Instance.new("Folder")',
				'\tfolder.Name = "_TmpAwSync"',
				"\tfolder.Parent = game.ReplicatedStorage",
				"end",
				f'local sub = folder:FindFirstChild("{name}")',
				"if not sub then",
				'\tsub = Instance.new("Folder")',
				f'\tsub.Name = "{name}"',
				"\tsub.Parent = folder",
				"end",
				f'local v = sub:FindFirstChild("{i}")',
				"if not v then",
				'\tv = Instance.new("StringValue")',
				f'\tv.Name = "{i}"',
				"\tv.Parent = sub",
				"end",
				f'v.Value = "{piece}"',
				"return #v.Value",
			]
		)
		(OUT / f"{name}_{i}.luau").write_text(code + "\n", encoding="utf-8", newline="\n")
	apply = "\n".join(
		[
			B64_DEC.strip(),
			f'local sub = game.ReplicatedStorage:FindFirstChild("_TmpAwSync") and game.ReplicatedStorage._TmpAwSync:FindFirstChild("{name}")',
			'assert(sub, "missing")',
			f"local n = {len(pieces)}",
			"local acc = table.create(n)",
			"for i = 0, n - 1 do",
			'\tlocal v = sub:FindFirstChild(tostring(i))',
			"\tassert(v, i)",
			"\tacc[i + 1] = v.Value",
			"end",
			"local src = b64decode(table.concat(acc))",
			f"local mod = {studio_path}",
			"mod.Source = src",
			"return #src",
		]
	)
	(OUT / f"apply_{name}.luau").write_text(apply + "\n", encoding="utf-8", newline="\n")
	print(name, "utf8", len(raw), "b64pieces", len(pieces))

(OUT / "cleanup.luau").write_text(
	'local f=game.ReplicatedStorage:FindFirstChild("_TmpAwSync"); if f then f:Destroy() end; return "ok"\n',
	encoding="utf-8",
	newline="\n",
)
print("ok", OUT)
