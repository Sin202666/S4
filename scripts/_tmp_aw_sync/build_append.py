# -*- coding: utf-8 -*-
from pathlib import Path

text = (
	Path(r"d:/Git/Roblox/A4_Slap/src/ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau")
	.read_text(encoding="utf-8")
	.replace("\r\n", "\n")
)
assert "]=]" not in text
CHUNK = 3000
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/append_codes")
out.mkdir(parents=True, exist_ok=True)
for old in out.glob("*.luau"):
	old.unlink()

(out / "00_clear.luau").write_text(
	'local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig\nm.Source = ""\nreturn #m.Source\n',
	encoding="utf-8",
	newline="\n",
)
parts = [text[i : i + CHUNK] for i in range(0, len(text), CHUNK)]
for i, part in enumerate(parts):
	code = (
		"local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig\n"
		f"m.Source ..= [=[{part}]=]\n"
		"return #m.Source\n"
	)
	(out / f"{i + 1:02d}_append.luau").write_text(code, encoding="utf-8", newline="\n")
(out / "count.txt").write_text(str(len(parts)), encoding="utf-8")
print("parts", len(parts))
for f in sorted(out.glob("*.luau")):
	print(f.name, f.stat().st_size)
