# -*- coding: utf-8 -*-
"""Print chunk count and help inject BattlePose to Studio."""
from pathlib import Path

root = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_inject_BattlePose_chunks")
count = int((root / "count.txt").read_text().strip())
print("chunks", count)
for i in range(count):
    print(i, len((root / f"{i}.txt").read_text().strip()))
