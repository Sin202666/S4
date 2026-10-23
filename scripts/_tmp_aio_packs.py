# -*- coding: utf-8 -*-
from pathlib import Path

out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks/aio_parts")
for start in range(0, 12, 3):
	idxs = list(range(start, min(start + 3, 12)))
	lines = [
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpAio")',
		"if not folder then",
		'\tfolder = Instance.new("Folder")',
		'\tfolder.Name = "_TmpAio"',
		"\tfolder.Parent = game.ReplicatedStorage",
		"end",
		'local function set(i, s)',
		"\tlocal v = folder:FindFirstChild(tostring(i)) or Instance.new(\"StringValue\")",
		"\tv.Name = tostring(i)",
		"\tv.Parent = folder",
		"\tv.Value = s",
		"\treturn #s",
		"end",
		"local lens = {}",
	]
	for i in idxs:
		b64 = (out / f"{i}.b64").read_text(encoding="ascii").strip()
		lines.append(f"lens[{i}] = set({i}, [[{b64}]])")
	lines.append("return lens")
	p = out / f"pack_{start}.luau"
	p.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
	print(p.name, p.stat().st_size)
