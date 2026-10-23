# -*- coding: utf-8 -*-
"""Emit Luau that assigns Source via HttpService:JSONDecode of UTF-8 JSON."""
import json
import pathlib

OUT = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_inject_batch")
OUT.mkdir(parents=True, exist_ok=True)

FILES = [
    (
        r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\TranslationManager.client.luau",
        "game.StarterPlayer.StarterPlayerScripts.Manager.TranslationManager",
        "tm",
        "_watchProximityPrompts",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper",
        "th",
        "BindProximityPrompt",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolBasic\TranslationHelper\Language.luau",
        "game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper.Language",
        "lang",
        "Scarecrow",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\Interface\TranslationHelper-Type.luau",
        "game.ReplicatedFirst.AllSideCode.Interface.TranslationHelper-Type",
        "thtype",
        "BindProximityPrompt",
    ),
]


def main():
    for local_path, studio_path, tag, marker in FILES:
        src = pathlib.Path(local_path).read_text(encoding="utf-8").replace("\r\n", "\n")
        # Write JSON payload file for HTTP fetch
        payload_path = OUT / f"{tag}_payload.json"
        payload_path.write_text(json.dumps({"src": src}, ensure_ascii=False), encoding="utf-8")
        # Small runner that fetches JSON via HttpService
        runner = "\n".join(
            [
                "local HttpService = game:GetService(\"HttpService\")",
                "local was = HttpService.HttpEnabled",
                "HttpService.HttpEnabled = true",
                f'local ok, body = pcall(function() return HttpService:GetAsync("http://127.0.0.1:8777/{tag}_payload.json") end)',
                "HttpService.HttpEnabled = was",
                'if not ok then return "http: " .. tostring(body) end',
                "local decoded = HttpService:JSONDecode(body)",
                f"local s = {studio_path}",
                "s.Source = decoded.src",
                f'return string.format("{tag} len=%d marker=%s", #s.Source, tostring(s.Source:find({marker!r},1,true)~=nil))',
            ]
        )
        (OUT / f"{tag}_http_runner.luau").write_text(runner, encoding="utf-8")
        print(tag, "payload", payload_path.stat().st_size, "runner", len(runner))


if __name__ == "__main__":
    main()
