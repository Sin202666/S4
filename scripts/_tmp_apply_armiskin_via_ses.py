# -*- coding: utf-8 -*-
"""Build a single Luau that embeds all base64 chunks and applies via ScriptEditorService."""
import base64
import pathlib

text = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\ArmSkin.luau"
).read_text(encoding="utf-8").replace("\r\n", "\n")
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
chunks = [b64[i : i + 3000] for i in range(0, len(b64), 3000)]
assert all("]]" not in c for c in chunks)

lines = [
    "local function b64decode(data)",
    '\tlocal b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"',
    '\tdata = string.gsub(data, "[^" .. b .. "=]", "")',
    '\treturn (data:gsub(".", function(x)',
    '\t\tif x == "=" then return "" end',
    '\t\tlocal r, f = "", (b:find(x) - 1)',
    "\t\tfor i = 6, 1, -1 do",
    '\t\t\tr = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")',
    "\t\tend",
    "\t\treturn r",
    '\tend):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)',
    "\t\tif #x ~= 8 then return \"\" end",
    "\t\tlocal c = 0",
    "\t\tfor i = 1, 8 do",
    '\t\t\tc = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)',
    "\t\tend",
    "\t\treturn string.char(c)",
    "\tend))",
    "end",
]
for i, c in enumerate(chunks):
    lines.append(f"local t{i} = [[{c}]]")
concat = " .. ".join(f"t{i}" for i in range(len(chunks)))
lines += [
    f"local src = b64decode({concat})",
    "local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin",
    'local ses = game:GetService("ScriptEditorService")',
    "ses:UpdateSourceAsync(m, function(_old)",
    "\treturn src",
    "end)",
    "m.Source = src",
    'local folder = game.ServerStorage:FindFirstChild("_ArmSkinInject")',
    "if folder then folder:Destroy() end",
    'return string.format("ok len=%d classic=%s ensure=%s fonts=%s", #src, tostring(src:find("CLASSIC_ARM_MESH",1,true)~=nil), tostring(src:find("_ensureLimbMesh",1,true)~=nil), tostring(src:find("fonts/rightarm.mesh",1,true)~=nil))',
]
out = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_setsource.luau")
out.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print(len(chunks), out.stat().st_size, len(text))
