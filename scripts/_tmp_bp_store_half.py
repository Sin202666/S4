# -*- coding: utf-8 -*-
import json
from pathlib import Path

out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks")
for name in ("half_a.txt", "half_b.txt"):
	raw = (out / name).read_text(encoding="utf-8")
	# Store as JSON string so Luau JSONDecode recovers exact text
	j = json.dumps(raw, ensure_ascii=True)
	code = (
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpSync")\n'
		"if not folder then\n"
		'\tfolder = Instance.new("Folder")\n'
		'\tfolder.Name = "_TmpBpSync"\n'
		"\tfolder.Parent = game.ReplicatedStorage\n"
		"end\n"
		f'local v = folder:FindFirstChild("{name}")\n'
		"if not v then\n"
		'\tv = Instance.new("StringValue")\n'
		f'\tv.Name = "{name}"\n'
		"\tv.Parent = folder\n"
		"end\n"
		'local Hs = game:GetService("HttpService")\n'
		f"v.Value = Hs:JSONDecode([==[{j}]==])\n"
		"return #v.Value\n"
	)
	(out / f"store_{name}.luau").write_text(code, encoding="utf-8", newline="\n")
	print(name, "store script", len(code))

run = """local folder = game.ReplicatedStorage._TmpBpSync
local code = folder:FindFirstChild("half_a.txt").Value .. folder:FindFirstChild("half_b.txt").Value
local fn, err = loadstring(code)
if not fn then return { err = err } end
local ok, res = pcall(fn)
folder:Destroy()
if not ok then return { err = res } end
return res
"""
(out / "run_halves.luau").write_text(run, encoding="utf-8", newline="\n")
print("run ok")
