# -*- coding: utf-8 -*-
from pathlib import Path

out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks")
count = int((out / "count.txt").read_text().strip())
# 00 alone, then groups of 4 appends
files = ["00_clear_set.luau"] + [f"{i:02d}_append.luau" for i in range(1, count)]
# Build batched runners: recreate + groups
batches = []
# first is clear
batches.append([files[0]])
rest = files[1:]
for i in range(0, len(rest), 4):
	batches.append(rest[i : i + 4])

for bi, batch in enumerate(batches):
	parts = []
	for name in batch:
		body = (out / name).read_text(encoding="utf-8")
		# strip return line; keep statements
		lines = [ln for ln in body.splitlines() if not ln.startswith("return ")]
		parts.append("\n".join(lines))
	code = "\n".join(parts) + "\nreturn { batch = " + str(bi) + ", n = #game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose.Source }\n"
	p = out / f"batch_{bi}.luau"
	p.write_text(code, encoding="utf-8", newline="\n")
	print(p.name, p.stat().st_size, "files", batch)
