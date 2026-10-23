# -*- coding: utf-8 -*-
"""Print each mod part as a single JSON string for manual MCP; also write apply.luau."""
import json
from pathlib import Path

d = Path(__file__).resolve().parent / "mod_parts"
out = Path(__file__).resolve().parent / "push"
out.mkdir(exist_ok=True)
count = int((d / "count.txt").read_text(encoding="utf-8"))
for i in range(count):
	src = (d / f"{i}.luau").read_text(encoding="utf-8").strip() + "\n"
	(out / f"P{i}.source.txt").write_text(src, encoding="utf-8", newline="\n")
	print(f"P{i}", len(src))

apply = r'''
local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data: string): string
	data = string.gsub(data, "[^A-Za-z0-9+/=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = lookup[string.byte(data, i)] or 0
		local b = lookup[string.byte(data, i + 1)] or 0
		local c = lookup[string.byte(data, i + 2)] or 0
		local d = lookup[string.byte(data, i + 3)] or 0
		n += 1
		out[n] = string.char(bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		if string.sub(data, i + 2, i + 2) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255))
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255))
		end
	end
	return table.concat(out)
end
local folder = game.ReplicatedStorage:FindFirstChild("_AwB64Parts")
assert(folder)
local acc = table.create(%d)
for i = 0, %d - 1 do
	local mod = folder:FindFirstChild("P" .. i)
	assert(mod and mod:IsA("ModuleScript"), "missing P" .. i)
	acc[i + 1] = require(mod)
end
local src = b64decode(table.concat(acc))
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig
m.Source = src
return #src
''' % (count, count)
(out / "apply.luau").write_text(apply.strip() + "\n", encoding="utf-8", newline="\n")
(out / "cleanup.luau").write_text(
	'local f=game.ReplicatedStorage:FindFirstChild("_AwB64Parts"); if f then f:Destroy() end; return "ok"\n',
	encoding="utf-8",
	newline="\n",
)
print("wrote apply")
