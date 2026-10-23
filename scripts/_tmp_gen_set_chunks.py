# -*- coding: utf-8 -*-
from pathlib import Path

out = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_q")
for i in range(4):
	chunk = (out / f"{i}.txt").read_text(encoding="utf-8")
	n = 0
	while True:
		o = "[" + "=" * n + "["
		c = "]" + "=" * n + "]"
		if o not in chunk and c not in chunk:
			break
		n += 1
	code = (
		f"local s = game.ServerStorage._LoadingUISrc['p{i}']\n"
		f"s.Value = {o}{chunk}{c}\n"
		"return #s.Value\n"
	)
	Path(rf"d:\Git\Roblox\A4_Slap\scripts\_tmp_set_p{i}.luau").write_text(code, encoding="utf-8")
	print(f"{i} n={n} code_len={len(code)}")
