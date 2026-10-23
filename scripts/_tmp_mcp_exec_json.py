# -*- coding: utf-8 -*-
"""Print JSON args for execute_luau from inject_N or apply file."""
import json
import pathlib
import sys

STUDIO = "67141699-85ef-45e9-90dd-061cabca4a19"
root = pathlib.Path(__file__).resolve().parent

if sys.argv[1] == "apply":
    code = (root / "_tmp_armiskin_apply.luau").read_text(encoding="utf-8")
else:
    n = int(sys.argv[1])
    code = (root / "_tmp_armiskin_chunks" / f"inject_{n}.luau").read_text(encoding="utf-8")

print(json.dumps({"code": code, "datamodel_type": "Edit", "studio_id": STUDIO}, ensure_ascii=False))
