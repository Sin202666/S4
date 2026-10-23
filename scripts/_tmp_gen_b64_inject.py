# -*- coding: utf-8 -*-
import base64
import pathlib

src = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\CustomEUI.client.luau"
).read_bytes()
b64 = base64.b64encode(src).decode("ascii")
chunks = [b64[i : i + 12000] for i in range(0, len(b64), 12000)]
lines = ["local s = game.StarterPlayer.StarterPlayerScripts.Manager.CustomEUI"]
lines.append("local b64 = " + " .. ".join(repr(c) for c in chunks))
lines.append("local ok, buf = pcall(function() return buffer.frombase64(b64) end)")
lines.append('if not ok then return "no buffer.frombase64: " .. tostring(buf) end')
lines.append("s.Source = buffer.tostring(buf)")
lines.append(
    "return { len = #s.Source, hasGetIns = s.Source:find('InsMgr.GetIns', 1, true) ~= nil, "
    "hasCheck = s.Source:find('CheckTranslateByKey', 1, true) ~= nil }"
)
code = "\n".join(lines)
out = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_customeui_b64_inject.luau")
out.write_text(code, encoding="utf-8")
print("b64", len(b64), "code", len(code), "chunks", len(chunks))
