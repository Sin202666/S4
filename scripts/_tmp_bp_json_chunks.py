# -*- coding: utf-8 -*-
"""BattlePose -> Studio: JSON chunks (all_in_one + per-chunk append scripts)."""
import json
from pathlib import Path

src = Path(
	r"d:/Git/Roblox/A4_Slap/src/ReplicatedStorage/ClientSideCode/SystemModule/SystemArmWrestle/BattlePose.luau"
).read_text(encoding="utf-8")
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks")
out.mkdir(parents=True, exist_ok=True)
for old in out.glob("*.luau"):
	if old.name.startswith(("store_", "run_", "half_", "all_")):
		continue
	if old.name.endswith("_append.luau") or old.name == "00_clear_set.luau" or old.name == "zz_verify.luau":
		old.unlink()

chunk_size = 700
chunks = [src[i : i + chunk_size] for i in range(0, len(src), chunk_size)]

# all_in_one
lines = [
	"local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose",
	'local Hs = game:GetService("HttpService")',
	"local parts = {",
]
for chunk in chunks:
	j = json.dumps(chunk, ensure_ascii=True)
	lines.append(f"\t[==[{j}]==],")
lines += [
	"}",
	"local buf = table.create(#parts)",
	"for i, j in ipairs(parts) do",
	"\tbuf[i] = Hs:JSONDecode(j)",
	"end",
	"m.Source = table.concat(buf)",
	"local s = m.Source",
	"return {",
	"\tparts = #parts,",
	"\tlen = #s,",
	'\tok = string.find(s, "MEET_DROP") ~= nil',
	'\t\tand string.find(s, "_leftRestPoint") ~= nil',
	'\t\tand string.find(s, "full - full.Position") ~= nil,',
	"}",
]
(out / "all_in_one.luau").write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")

# per-chunk
first_json = json.dumps(chunks[0], ensure_ascii=True)
(out / "00_clear_set.luau").write_text(
	"local parent = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle\n"
	"local m = parent:FindFirstChild(\"BattlePose\")\n"
	"if not m then\n"
	'\tm = Instance.new("ModuleScript")\n'
	'\tm.Name = "BattlePose"\n'
	"\tm.Parent = parent\n"
	"end\n"
	'local Hs = game:GetService("HttpService")\n'
	f"m.Source = Hs:JSONDecode([==[{first_json}]==])\n"
	"return { n = #m.Source, i = 0 }\n",
	encoding="utf-8",
	newline="\n",
)
for i, chunk in enumerate(chunks[1:], start=1):
	j = json.dumps(chunk, ensure_ascii=True)
	(out / f"{i:02d}_append.luau").write_text(
		"local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose\n"
		'local Hs = game:GetService("HttpService")\n'
		f"m.Source ..= Hs:JSONDecode([==[{j}]==])\n"
		f"return {{ n = #m.Source, i = {i} }}\n",
		encoding="utf-8",
		newline="\n",
	)

(out / "count.txt").write_text(str(len(chunks)), encoding="ascii")
print("chunks", len(chunks), "all_in_one", (out / "all_in_one.luau").stat().st_size)
