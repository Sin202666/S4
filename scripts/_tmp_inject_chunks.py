# -*- coding: utf-8 -*-
"""Print one base64 chunk for manual MCP; or write StringValue sources."""
from pathlib import Path

parts = [
    Path(rf"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_parts/{i}.txt").read_text(encoding="ascii").strip()
    for i in range(6)
]
# Write a single luau that embeds all parts - already have _tmp_inject_bp.luau
print("parts", len(parts), [len(p) for p in parts])
