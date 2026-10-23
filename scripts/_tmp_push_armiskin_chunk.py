# -*- coding: utf-8 -*-
"""Print one inject_N.luau to stdout for MCP paste. Usage: python _tmp_push_armiskin_chunk.py N"""
import pathlib
import sys

n = int(sys.argv[1])
path = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_chunks") / f"inject_{n}.luau"
sys.stdout.write(path.read_text(encoding="utf-8"))
