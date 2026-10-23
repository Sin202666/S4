# -*- coding: utf-8 -*-
import base64
import pathlib

src_path = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\init.luau"
)
src = src_path.read_bytes().replace(b"\r\n", b"\n")
b64 = base64.b64encode(src).decode("ascii")
chunks = [b64[i : i + 8000] for i in range(0, len(b64), 8000)]

parts = [
    "local s = game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper",
    "local b64 = " + " .. ".join(repr(c) for c in chunks),
    "local ok, buf = pcall(function() return buffer.frombase64(b64) end)",
    'if not ok then return "no buffer: " .. tostring(buf) end',
    "s.Source = buffer.tostring(buf)",
    'return string.format("len=%d bind=%s objKey=%s", #s.Source, tostring(s.Source:find("BindProximityPrompt",1,true)~=nil), tostring(s.Source:find("_objectKey",1,true)~=nil))',
]
out = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_th_inject.luau")
out.write_text("\n".join(parts), encoding="utf-8")
print("chunks", len(chunks), "code_len", out.stat().st_size)
