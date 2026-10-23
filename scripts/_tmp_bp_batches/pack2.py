# -*- coding: utf-8 -*-
"""Emit Luau that sets two consecutive StringValue parts."""
from pathlib import Path
import sys

parts_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts")
out_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/packs")
out_dir.mkdir(parents=True, exist_ok=True)
count = int((parts_dir / "count.txt").read_text(encoding="ascii").strip())
for start in range(0, count, 2):
	idxs = list(range(start, min(start + 2, count)))
	lines = [
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")',
		"if not folder then",
		'\tfolder = Instance.new("Folder")',
		'\tfolder.Name = "_TmpBpInject"',
		"\tfolder.Parent = game.ReplicatedStorage",
		"end",
		"local function set(i, s)",
		"\tlocal v = folder:FindFirstChild(tostring(i))",
		'\tif not v then v = Instance.new("StringValue") v.Name = tostring(i) v.Parent = folder end',
		"\tv.Value = s",
		"\treturn #s",
		"end",
		"local lens = {}",
	]
	for i in idxs:
		b64 = (parts_dir / f"{i}.txt").read_text(encoding="ascii").strip()
		lines.append(f"lens[{i}] = set({i}, [[{b64}]])")
	lines.append("return lens")
	path = out_dir / f"pack_{start}.luau"
	path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
	print(path.name, path.stat().st_size)
