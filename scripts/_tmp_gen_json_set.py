# -*- coding: utf-8 -*-
import json
from pathlib import Path

out = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_inject_batch")
out.mkdir(parents=True, exist_ok=True)

ITEMS = [
    (
        "tm",
        r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\TranslationManager.client.luau",
        "game.StarterPlayer.StarterPlayerScripts.Manager.TranslationManager",
        "_watchProximityPrompts",
    ),
    (
        "th",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper",
        "BindProximityPrompt",
    ),
    (
        "lang",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\Language.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper.Language",
        "Scarecrow",
    ),
    (
        "thtype",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\Interface\TranslationHelper-Type.luau",
        "game.ReplicatedFirst.AllSideCode.Interface.TranslationHelper-Type",
        "BindProximityPrompt",
    ),
]


def make(tag: str, local: str, studio: str, marker: str) -> None:
    src = Path(local).read_text(encoding="utf-8").replace("\r\n", "\n")
    js = json.dumps({"src": src}, ensure_ascii=True)
    code = (
        'local HttpService = game:GetService("HttpService")\n'
        f"local s = {studio}\n"
        "local decoded = HttpService:JSONDecode([====[\n"
        + js
        + "\n]====])\n"
        "s.Source = decoded.src\n"
        f'return string.format("{tag} len=%d marker=%s", #s.Source, tostring(s.Source:find({marker!r},1,true)~=nil))\n'
    )
    p = out / f"{tag}_json_set.luau"
    p.write_text(code, encoding="utf-8")
    print(tag, p.stat().st_size)


def main() -> None:
    for item in ITEMS:
        make(*item)


if __name__ == "__main__":
    main()
