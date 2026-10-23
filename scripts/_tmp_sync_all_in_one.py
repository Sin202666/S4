# -*- coding: utf-8 -*-
import base64
from pathlib import Path

src = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks/all_in_one.luau").read_bytes()
b64 = base64.b64encode(src).decode("ascii")
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_batches/json_chunks/aio_parts")
out.mkdir(parents=True, exist_ok=True)
chunk = 1800
parts = [b64[i : i + chunk] for i in range(0, len(b64), chunk)]
for i, p in enumerate(parts):
	code = (
		'local folder = game.ReplicatedStorage:FindFirstChild("_TmpAio")\n'
		"if not folder then\n"
		'\tfolder = Instance.new("Folder")\n'
		'\tfolder.Name = "_TmpAio"\n'
		"\tfolder.Parent = game.ReplicatedStorage\n"
		"end\n"
		f'local v = folder:FindFirstChild("{i}") or Instance.new("StringValue")\n'
		f'v.Name = "{i}"\n'
		"v.Parent = folder\n"
		f"v.Value = [[{p}]]\n"
		f"return {{ i = {i}, n = #v.Value }}\n"
	)
	(out / f"{i}.luau").write_text(code, encoding="utf-8", newline="\n")
(out / "count.txt").write_text(str(len(parts)), encoding="ascii")
apply = r"""
local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
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
local folder = game.ReplicatedStorage._TmpAio
local parts = {}
local i = 0
while folder:FindFirstChild(tostring(i)) do
	table.insert(parts, folder[tostring(i)].Value)
	i += 1
end
local code = b64decode(table.concat(parts))
local fn, err = loadstring(code)
if not fn then return { err = tostring(err) } end
local ok, res = pcall(fn)
folder:Destroy()
if not ok then return { err = tostring(res) } end
return res
"""
(out / "apply.luau").write_text(apply.strip() + "\n", encoding="utf-8", newline="\n")
print("parts", len(parts), "b64", len(b64))
for f in sorted(out.glob("*.luau")):
	print(f.name, f.stat().st_size)
