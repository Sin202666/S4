# -*- coding: utf-8 -*-
"""Print chunked base64 for Studio execute_luau injection."""
from pathlib import Path

root = Path(r"d:/Git/Roblox/A4_Slap/scripts")
CHUNK = 4000

for stem in ("BattlePose", "Anim"):
    b64 = (root / f"_tmp_sync_{stem}.b64").read_text(encoding="ascii").strip()
    chunks = [b64[i : i + CHUNK] for i in range(0, len(b64), CHUNK)]
    out = root / f"_tmp_inject_{stem}_chunks"
    out.mkdir(exist_ok=True)
    for i, c in enumerate(chunks):
        (out / f"{i}.txt").write_text(c, encoding="ascii")
    (out / "count.txt").write_text(str(len(chunks)), encoding="ascii")
    print(stem, len(chunks), "chunks", "total", len(b64))
