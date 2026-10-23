# -*- coding: utf-8 -*-
import base64
from pathlib import Path

root = Path(r"d:/Git/Roblox/A4_Slap")
mod = root / "src/ReplicatedStorage/ClientSideCode/SystemModule/SystemArmWrestle"
out_dir = root / "scripts"

for name in ("BattlePose.luau", "Anim.luau"):
    p = mod / name
    raw = p.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    text = raw.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n")
    p.write_bytes(text.encode("utf-8"))
    b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
    stem = name.replace(".luau", "")
    (out_dir / f"_tmp_sync_{stem}.b64").write_text(b64, encoding="ascii")
    print(name, "chars", len(text), "b64", len(b64))
    for line in text.split("\n")[:8]:
        if "Author" in line or "Module" in line or "Description" in line:
            print(" ", line)
