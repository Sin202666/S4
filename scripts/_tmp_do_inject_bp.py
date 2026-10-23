# -*- coding: utf-8 -*-
"""Print Luau snippet that sets StringValues 0..n-1 then decodes into BattlePose.Source."""
from pathlib import Path

parts_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts")
count = int((parts_dir / "count.txt").read_text(encoding="ascii").strip())
parts = [(parts_dir / f"{i}.txt").read_text(encoding="ascii").strip() for i in range(count)]

# Write one luau file per batch of 3 parts for execute_luau, plus a final apply script
out_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches")
out_dir.mkdir(exist_ok=True)
batch_size = 3
batches = []
for b in range(0, count, batch_size):
	chunk = parts[b : b + batch_size]
	lines = [
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpBpInject")',
		"if not folder then",
		'\tfolder = Instance.new("Folder")',
		'\tfolder.Name = "_TmpBpInject"',
		"\tfolder.Parent = game.ReplicatedStorage",
		"end",
		"local function set(i, s)",
		"\tlocal v = folder:FindFirstChild(tostring(i))",
		'\tif not v then v = Instance.new("StringValue") v.Name = tostring(i) v.Parent = folder end',
		"\tv.Value = s",
		"\treturn #s",
		"end",
		"local lens = {}",
	]
	for j, p in enumerate(chunk):
		i = b + j
		lines.append(f"lens[{i}] = set({i}, [[{p}]])")
	lines.append("return lens")
	path = out_dir / f"batch_{b // batch_size}.luau"
	path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
	batches.append(str(path))

apply = """local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
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
local folder = game.ReplicatedStorage._TmpBpInject
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
return { parts = #parts, len = #src, ok = string.find(src, "_meetPoint") ~= nil and string.find(src, "_setReach") ~= nil }
"""
(out_dir / "apply.luau").write_text(apply, encoding="utf-8", newline="\n")
print("batches", len(batches), "parts", count)
