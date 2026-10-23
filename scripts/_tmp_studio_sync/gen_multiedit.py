# -*- coding: utf-8 -*-
"""Build multi_edit payloads: old_string from Studio snapshots, new_string from local src."""
import json
import pathlib

PAIRS = [
    (
        r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync\studio\Visibility.studio.luau",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIMgr\Visibility.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIMgr.Visibility",
        "ModuleScript",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync\studio\UIMgr.studio.luau",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIMgr\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIMgr",
        "ModuleScript",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync\studio\UIMgr-Type.studio.luau",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\Interface\UIMgr-Type.luau",
        "game.ReplicatedFirst.AllSideCode.Interface.UIMgr-Type",
        "ModuleScript",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync\studio\UIanima.studio.luau",
        r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\UIanima\init.luau",
        "game.ReplicatedFirst.AllSideCode.ToolSystem.UIanima",
        "ModuleScript",
    ),
    (
        r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync\studio\UIManager.studio.luau",
        r"d:\Git\Roblox\A4_Slap\src\StarterPlayer\StarterPlayerScripts\Manager\UIManager.client.luau",
        "game.StarterPlayer.StarterPlayerScripts.Manager.UIManager",
        "LocalScript",
    ),
]
out_dir = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_studio_sync")
studio_id = "67141699-85ef-45e9-90dd-061cabca4a19"
for old_path, new_path, file_path, class_name in PAIRS:
    old_s = pathlib.Path(old_path).read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    new_s = pathlib.Path(new_path).read_text(encoding="utf-8").replace("\r\n", "\n").replace("\r", "\n")
    payload = {
        "file_path": file_path,
        "className": class_name,
        "datamodel_type": "Edit",
        "studio_id": studio_id,
        "edits": [{"old_string": old_s, "new_string": new_s}],
    }
    out = out_dir / (file_path.replace("game.", "").replace(".", "_") + "_multiedit.json")
    out.write_text(json.dumps(payload, ensure_ascii=False), encoding="utf-8")
    print(out.name, "old", len(old_s), "new", len(new_s), "match", old_s == new_s)
