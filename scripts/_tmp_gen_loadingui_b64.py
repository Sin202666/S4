# -*- coding: utf-8 -*-
from pathlib import Path
import base64
import json

text = Path(r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\FirstPreload\LoadingUI.luau").read_text(
	encoding="utf-8"
)
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
chunk_size = 3500
chunks = [b64[i : i + chunk_size] for i in range(0, len(b64), chunk_size)]
out_dir = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_chunks")
out_dir.mkdir(exist_ok=True)
for i, c in enumerate(chunks):
	(out_dir / f"{i}.txt").write_text(c, encoding="ascii")
(out_dir / "count.txt").write_text(str(len(chunks)), encoding="ascii")
print(f"chunks={len(chunks)} b64_len={len(b64)} src_len={len(text)}")
