# -*- coding: utf-8 -*-
import base64
import pathlib

files = [
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIMgr\Visibility.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIMgr.Visibility",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIMgr\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIMgr",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\Interface\UIMgr-Type.luau",
        "game.ReplicatedFirst.AllSideCode.Interface.UIMgr-Type",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIanima\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIanima",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\UIManager.client.luau",
        "game.StarterPlayer.StarterPlayerScripts.Manager.UIManager",
    ),
]
out_dir = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync")
for local, dotpath in files:
    src = pathlib.Path(local).read_bytes()
    b64 = base64.b64encode(src).decode("ascii")
    chunks = [b64[i : i + 12000] for i in range(0, len(b64), 12000)]
    lines = [f"local s = {dotpath}"]
    lines.append("local b64 = " + " .. ".join(repr(c) for c in chunks))
    lines.append("local ok, buf = pcall(function() return buffer.frombase64(b64) end)")
    lines.append('if not ok then return "no buffer: " .. tostring(buf) end')
    lines.append("s.Source = buffer.tostring(buf)")
    lines.append(
        f'return {{ path = "{dotpath}", len = #s.Source, '
        f'hasRefresh = s.Source:find("RefreshPopShowState", 1, true) ~= nil }}'
    )
    name = dotpath.replace("game.", "").replace(".", "_") + "_inject.luau"
    code = "\n".join(lines)
    (out_dir / name).write_text(code, encoding="utf-8")
    print(name, "b64", len(b64), "code", len(code))
