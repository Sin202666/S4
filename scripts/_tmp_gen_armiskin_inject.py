# -*- coding: utf-8 -*-
import base64
import pathlib

text = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\ArmSkin.luau"
).read_text(encoding="utf-8").replace("\r\n", "\n")
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
chunks = [b64[i : i + 3500] for i in range(0, len(b64), 3500)]
assert all("]]" not in c for c in chunks)

decoder = r"""local function b64decode(data)
	local b = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	data = string.gsub(data, "[^" .. b .. "=]", "")
	return (data:gsub(".", function(x)
		if x == "=" then
			return ""
		end
		local r, f = "", (b:find(x) - 1)
		for i = 6, 1, -1 do
			r = r .. (f % 2 ^ i - f % 2 ^ (i - 1) > 0 and "1" or "0")
		end
		return r
	end):gsub("%d%d%d?%d?%d?%d?%d?%d?", function(x)
		if #x ~= 8 then
			return ""
		end
		local c = 0
		for i = 1, 8 do
			c = c + (x:sub(i, i) == "1" and 2 ^ (8 - i) or 0)
		end
		return string.char(c)
	end))
end
"""

parts = [f"local t{i} = [[{c}]]" for i, c in enumerate(chunks)]
concat = " .. ".join(f"t{i}" for i in range(len(chunks)))
code = (
    decoder
    + "\n".join(parts)
    + f"""
local src = b64decode({concat})
local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin
m.Source = src
return string.format("ok len=%d ensure=%s classic=%s", #src, tostring(src:find("_ensureLimbMesh", 1, true) ~= nil), tostring(src:find("CLASSIC_ARM_MESH", 1, true) ~= nil))
"""
)
out = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_setsource.luau")
out.write_text(code, encoding="utf-8", newline="\n")
print("chunks", len(chunks), "codebytes", out.stat().st_size)
