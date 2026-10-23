# -*- coding: utf-8 -*-
from pathlib import Path

parts = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts")
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/single")
out.mkdir(parents=True, exist_ok=True)
count = int((parts / "count.txt").read_text(encoding="ascii").strip())
for i in range(count):
	b64 = (parts / f"{i}.txt").read_text(encoding="ascii").strip()
	code = (
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")\n'
		"if not folder then\n"
		'\tfolder = Instance.new("Folder")\n'
		'\tfolder.Name = "_TmpBpInject"\n'
		"\tfolder.Parent = game.ReplicatedStorage\n"
		"end\n"
		f'local v = folder:FindFirstChild("{i}")\n'
		"if not v then\n"
		'\tv = Instance.new("StringValue")\n'
		f'\tv.Name = "{i}"\n'
		"\tv.Parent = folder\n"
		"end\n"
		f"v.Value = [[{b64}]]\n"
		f"return {{ i = {i}, n = #v.Value }}\n"
	)
	(out / f"{i}.luau").write_text(code, encoding="utf-8", newline="\n")
	print(i, len(code))
print("count", count)
