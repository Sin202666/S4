# -*- coding: utf-8 -*-
from pathlib import Path

ROOT = Path(__file__).resolve().parent
OUT = ROOT / "codes"
OUT.mkdir(parents=True, exist_ok=True)

TARGETS = {
	"ConfigInstance": "game.ReplicatedFirst.AllSideCode.ToolBasic.ConfigInstance",
	"ArmWrestleConfig": "game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig",
}

for name, studio_path in TARGETS.items():
	d = ROOT / name
	count = int((d / "count.txt").read_text(encoding="utf-8"))
	for i in range(count):
		part = (d / f"{i}.txt").read_text(encoding="utf-8")
		assert "]=]" not in part
		# Keep part bytes exact: no extra newlines inside long-string delimiters.
		code = "\n".join(
			[
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
				f"v.Value = [=[{part}]=]",
				"return #v.Value",
			]
		)
		p = OUT / f"{name}_{i}.luau"
		p.write_text(code + "\n", encoding="utf-8", newline="\n")
		print("wrote", p.name, p.stat().st_size)

	apply = "\n".join(
		[
			f'local sub = game.ReplicatedStorage:FindFirstChild("_TmpAwSync") and game.ReplicatedStorage._TmpAwSync:FindFirstChild("{name}")',
			'assert(sub, "missing chunks")',
			f"local parts = table.create({count})",
			f"for i = 0, {count - 1} do",
			'\tlocal v = sub:FindFirstChild(tostring(i))',
			'\tassert(v and v:IsA("StringValue"), "missing " .. i)',
			"\tparts[i + 1] = v.Value",
			"end",
			"local src = table.concat(parts)",
			f"local mod = {studio_path}",
			"mod.Source = src",
			"return #src",
		]
	)
	(OUT / f"apply_{name}.luau").write_text(apply + "\n", encoding="utf-8", newline="\n")
	print("apply", name)

cleanup = "\n".join(
	[
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpAwSync")',
		"if folder then folder:Destroy() end",
		'return "ok"',
	]
)
(OUT / "cleanup.luau").write_text(cleanup + "\n", encoding="utf-8", newline="\n")
print("done")
