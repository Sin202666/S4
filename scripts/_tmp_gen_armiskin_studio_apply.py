# -*- coding: utf-8 -*-
"""Generate one execute_luau script: upload chunks 0-6 from *.txt and apply to ArmSkin."""
import pathlib

root = pathlib.Path(__file__).resolve().parent
chunk_dir = root / "_tmp_armiskin_chunks"
out = root / "_tmp_armiskin_studio_apply_all.luau"

lines = [
    "local f = game.ServerStorage:FindFirstChild('_ArmSkinInject')",
    "if not f then",
    "\tf = Instance.new('Folder')",
    "\tf.Name = '_ArmSkinInject'",
    "\tf.Parent = game.ServerStorage",
    "end",
    "f:ClearAllChildren()",
    "local function put(n, s)",
    "\tlocal v = Instance.new('StringValue')",
    "\tv.Name = tostring(n)",
    "\tv.Value = s",
    "\tv.Parent = f",
    "end",
]
for i in range(7):
    s = (chunk_dir / f"{i}.txt").read_text(encoding="utf-8").strip()
    lines.append(f"put({i}, [[{s}]])")

lines.extend(
    [
        "local function b64decode(data)",
        '\tlocal b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"',
        '\tdata = string.gsub(data, "[^" .. b .. "=]", "")',
        '\treturn (data:gsub(".", function(x)',
        '\t\tif x == "=" then return "" end',
        '\t\tlocal r, f = "", (b:find(x) - 1)',
        '\t\tfor i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end',
        '\t\treturn r',
        '\tend):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)',
        '\t\tif #x ~= 8 then return "" end',
        '\t\tlocal c = 0',
        '\t\tfor i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end',
        '\t\treturn string.char(c)',
        '\tend))',
        "end",
        "local parts = {}",
        "for i = 0, 6 do",
        '\ttable.insert(parts, f:FindFirstChild(tostring(i)).Value)',
        "end",
        "local src = b64decode(table.concat(parts))",
        "local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin",
        "local ses = game:GetService('ScriptEditorService')",
        "local ok = pcall(function()",
        "\tses:UpdateSourceAsync(m, function()",
        "\t\treturn src",
        "\tend)",
        "end)",
        "m.Source = src",
        "f:Destroy()",
        'return string.format("len=%d|CLASSIC=%s|LIMB=%s|CN=%s|update=%s", #src, tostring(src:find("CLASSIC_ARM_MESH") ~= nil), tostring(src:find("_ensureLimbMesh") ~= nil), tostring(src:find("才有圆润边") ~= nil), tostring(ok))',
    ]
)

text = "\n".join(lines) + "\n"
out.write_text(text, encoding="utf-8")
print(len(text))
