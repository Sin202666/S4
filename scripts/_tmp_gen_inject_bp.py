# -*- coding: utf-8 -*-
"""Rebuild base64 parts + per-part Luau inject scripts for BattlePose."""
import base64
from pathlib import Path

src = Path(
	r"d:/Git/Roblox/A4_Slap/src/ReplicatedStorage/ClientSideCode/SystemModule/SystemArmWrestle/BattlePose.luau"
).read_bytes()
b64 = base64.b64encode(src).decode("ascii")
parts_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts")
parts_dir.mkdir(exist_ok=True)
chunk = 2000
parts = [b64[i : i + chunk] for i in range(0, len(b64), chunk)]
for old in parts_dir.glob("*.txt"):
	old.unlink()
for i, p in enumerate(parts):
	(parts_dir / f"{i}.txt").write_text(p, encoding="ascii", newline="\n")
(parts_dir / "count.txt").write_text(str(len(parts)), encoding="ascii", newline="\n")

single = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/single")
single.mkdir(parents=True, exist_ok=True)
for i, p in enumerate(parts):
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
		f"v.Value = [[{p}]]\n"
		f"return {{ i = {i}, n = #v.Value }}\n"
	)
	(single / f"{i}.luau").write_text(code, encoding="utf-8", newline="\n")

apply = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/apply.luau")
apply.write_text(
	"""local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64decode(data)
	data = string.gsub(data, '[^'..alphabet..'=]', '')
	return (data:gsub('.', function(x)
		if x == '=' then return '' end
		local r, f = '', (alphabet:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end
		return r
	end):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)
		if #x ~= 8 then return '' end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end
		return string.char(c)
	end))
end
local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")
if not folder then return { err = "no folder" } end
local parts = {}
local i = 0
while folder:FindFirstChild(tostring(i)) do
	table.insert(parts, folder[tostring(i)].Value)
	i += 1
end
local src = b64decode(table.concat(parts))
local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose
m.Source = src
folder:Destroy()
return {
	parts = #parts,
	len = #src,
	ok = string.find(src, "_leftRestPoint") ~= nil
		and string.find(src, "_meetPoint") ~= nil
		and string.find(src, "Left Arm") ~= nil,
}
""",
	encoding="utf-8",
	newline="\n",
)
print("parts", len(parts), "b64", len(b64), "src", len(src))
