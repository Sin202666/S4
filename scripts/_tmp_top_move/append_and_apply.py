# -*- coding: utf-8 -*-
"""Print execute_luau code that appends one chunk; then a final apply script."""
import pathlib
import sys

base = pathlib.Path(__file__).resolve().parent / "mcp_chunks"
idx = int(sys.argv[1])
chunk = (base / f"c{idx}.txt").read_text(encoding="ascii")
print(
	"local sv = game.ServerStorage._TmpTopMove.Payload\n"
	f"local chunk = [[{chunk}]]\n"
	"sv.Value ..= chunk\n"
	"return { ok = true, idx = "
	+ str(idx)
	+ ", len = #sv.Value }"
)
