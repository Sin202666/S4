# -*- coding: utf-8 -*-
import base64
from pathlib import Path

text = (
	Path(r"d:/Git/Roblox/A4_Slap/src/ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau")
	.read_text(encoding="utf-8")
	.replace("\r\n", "\n")
)
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/full.b64").write_text(b64, encoding="ascii", newline="\n")
print("b64", len(b64))
CHUNK = 8000
parts = [b64[i : i + CHUNK] for i in range(0, len(b64), CHUNK)]
d = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/mod_parts")
d.mkdir(exist_ok=True)
for old in d.glob("*.luau"):
	old.unlink()
for i, p in enumerate(parts):
	(d / f"{i}.luau").write_text(f'return "{p}"\n', encoding="utf-8", newline="\n")
	print(i, len(p))
(d / "count.txt").write_text(str(len(parts)), encoding="utf-8")
print("count", len(parts))
