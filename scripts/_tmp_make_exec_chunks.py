# -*- coding: utf-8 -*-
from pathlib import Path

root = Path(r"d:/Git/Roblox/A4_Slap/scripts")

for stem in ("BattlePose", "Anim"):
    chunk_dir = root / f"_tmp_inject_{stem}_chunks"
    count = int((chunk_dir / "count.txt").read_text(encoding="ascii").strip())
    for i in range(count):
        c = (chunk_dir / f"{i}.txt").read_text(encoding="ascii").strip()
        # Use long-string with equals to avoid ]] collision (base64 has none anyway)
        code = f"_G.__SyncB64 ..= [=[ {c} ]=]\nreturn #_G.__SyncB64"
        # Wait - spaces would corrupt. Use [= [ without spaces inside content.
        code = "_G.__SyncB64 ..= [=[" + c + "]=]\nreturn #_G.__SyncB64"
        (chunk_dir / f"exec_{i}.luau").write_text(code, encoding="utf-8")
    print(stem, count, "exec files ready")
