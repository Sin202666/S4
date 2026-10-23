# -*- coding: utf-8 -*-
import base64
import pathlib

root = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_chunks")
root.mkdir(exist_ok=True)
text = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\ArmSkin.luau"
).read_text(encoding="utf-8").replace("\r\n", "\n")
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
chunks = [b64[i : i + 3500] for i in range(0, len(b64), 3500)]
for i, c in enumerate(chunks):
    (root / f"{i}.txt").write_text(c, encoding="ascii")
    code = (
        f'local f=game.ServerStorage._ArmSkinInject '
        f'local v=Instance.new("StringValue") '
        f'v.Name="{i}" v.Value=[[{c}]] v.Parent=f return #v.Value'
    )
    (root / f"inject_{i}.luau").write_text(code, encoding="utf-8", newline="\n")
(root / "count.txt").write_text(str(len(chunks)), encoding="ascii")

asm = f'''local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then return "" end
		local r, f = "", (b:find(x) - 1)
		for i = 6, 1, -1 do r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0") end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then return "" end
		local c = 0
		for i = 1, 8 do c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0) end
		return string.char(c)
	end))
end
local f = game.ServerStorage._ArmSkinInject
local parts = {{}}
for i = 0, {len(chunks) - 1} do
	local v = f:FindFirstChild(tostring(i))
	if not v then return "missing " .. i end
	table.insert(parts, v.Value)
end
local src = b64decode(table.concat(parts))
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin
local ses = game:GetService("ScriptEditorService")
ses:UpdateSourceAsync(m, function()
	return src
end)
m.Source = src
f:Destroy()
return string.format("ok len=%d classic=%s ensure=%s", #src, tostring(src:find("CLASSIC_ARM_MESH",1,true)~=nil), tostring(src:find("_ensureLimbMesh",1,true)~=nil))
'''
(root / "assemble.luau").write_text(asm, encoding="utf-8", newline="\n")
print(len(chunks), (root / "assemble.luau").stat().st_size)
