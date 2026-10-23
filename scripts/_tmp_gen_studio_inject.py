# -*- coding: utf-8 -*-
"""Generate a Studio execute_luau script that injects BattlePose from base64 parts."""
from pathlib import Path

parts_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts")
count = int((parts_dir / "count.txt").read_text(encoding="ascii").strip())
parts = [(parts_dir / f"{i}.txt").read_text(encoding="ascii").strip() for i in range(count)]

lines = [
	"local alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'",
	"local function b64decode(data)",
	"\tdata = string.gsub(data, '[^'..alphabet..'=]', '')",
	"\treturn (data:gsub('.', function(x)",
	"\t\tif x == '=' then return '' end",
	"\t\tlocal r, f = '', (alphabet:find(x) - 1)",
	"\t\tfor i = 6, 1, -1 do r = r .. (f % 2^i - f % 2^(i-1) > 0 and '1' or '0') end",
	"\t\treturn r",
	"\tend):gsub('%d%d%d?%d?%d?%d?%d?%d?', function(x)",
	"\t\tif #x ~= 8 then return '' end",
	"\t\tlocal c = 0",
	"\t\tfor i = 1, 8 do c = c + (x:sub(i,i) == '1' and 2^(8-i) or 0) end",
	"\t\treturn string.char(c)",
	"\tend))",
	"end",
	"local b64 = table.concat({",
]
for p in parts:
	lines.append("[[" + p + "]],")
lines.extend(
	[
		"})",
		"local src = b64decode(b64)",
		"local parent = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle",
		'local m = parent:FindFirstChild("BattlePose")',
		"if not m then",
		'\tm = Instance.new("ModuleScript")',
		'\tm.Name = "BattlePose"',
		"\tm.Parent = parent",
		"end",
		"m.Source = src",
		'return { len = #src, ok = string.find(src, "BindToRenderStep") ~= nil }',
	]
)
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_inject_bp.luau")
out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print("wrote", out, "bytes", out.stat().st_size)
