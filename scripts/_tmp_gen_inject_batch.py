# -*- coding: utf-8 -*-
"""Generate buffer.frombase64 inject scripts for Studio Source force-write."""
import base64
import pathlib

OUT = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_inject_batch")
OUT.mkdir(parents=True, exist_ok=True)

FILES = [
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper",
        "th",
        "BindProximityPrompt",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\TranslationManager.client.luau",
        "game.StarterPlayer.StarterPlayerScripts.Manager.TranslationManager",
        "tm",
        "_watchProximityPrompts",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\Language.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper.Language",
        "lang",
        "Arm Wrestle",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\Interface\TranslationHelper-Type.luau",
        "game.ReplicatedFirst.AllSideCode.Interface.TranslationHelper-Type",
        "thtype",
        "BindProximityPrompt",
    ),
]


def make_inject(local_path: str, studio_path: str, tag: str, marker: str) -> pathlib.Path:
    src = pathlib.Path(local_path).read_bytes().replace(b"\r\n", b"\n")
    b64 = base64.b64encode(src).decode("ascii")
    chunks = [b64[i : i + 6000] for i in range(0, len(b64), 6000)]
    parts = [
        f"local s = {studio_path}",
        "local b64 = " + " .. ".join(repr(c) for c in chunks),
        "local ok, buf = pcall(function() return buffer.frombase64(b64) end)",
        'if not ok then return "no buffer: " .. tostring(buf) end',
        "s.Source = buffer.tostring(buf)",
        f'return string.format("{tag} len=%d marker=%s", #s.Source, tostring(s.Source:find({marker!r},1,true)~=nil))',
    ]
    out = OUT / f"{tag}_inject.luau"
    out.write_text("\n".join(parts), encoding="utf-8")
    print(tag, "chunks", len(chunks), "bytes", len(src), "->", out.name)
    return out


def main():
    for local_path, studio_path, tag, marker in FILES:
        make_inject(local_path, studio_path, tag, marker)


if __name__ == "__main__":
    main()
