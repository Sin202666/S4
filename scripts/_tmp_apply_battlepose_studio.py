# -*- coding: utf-8 -*-
"""Emit Studio execute_luau code that sets BattlePose.Source from base64 chunks."""
from pathlib import Path

root = Path(r"d:/Git/Roblox/A4_Slap/scripts")
chunks_dir = root / "_tmp_inject_BattlePose_chunks"
count = int((chunks_dir / "count.txt").read_text(encoding="ascii").strip())
parts = []
for i in range(count):
    c = (chunks_dir / f"{i}.txt").read_text(encoding="ascii").strip()
    parts.append('"' + c + '"')

code = f"""local HttpService = game:GetService("HttpService")
local b64 = table.concat({{
\t{(",\\n\\t").join(parts)}
}})
local src = HttpService:Base64Decode(b64)
local parent = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle
local m = parent:FindFirstChild("BattlePose")
if not m then
\tm = Instance.new("ModuleScript")
\tm.Name = "BattlePose"
\tm.Parent = parent
end
m.Source = src
return #src
"""
out = root / "_tmp_apply_BattlePose.luau"
out.write_text(code, encoding="utf-8")
print("wrote", out, "bytes", out.stat().st_size)
