# -*- coding: utf-8 -*-
from pathlib import Path

text = Path(r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\FirstPreload\LoadingUI.luau").read_text(
	encoding="utf-8"
)
n = 0
while True:
	open_d = "[" + "=" * n + "["
	close_d = "]" + "=" * n + "]"
	if open_d not in text and close_d not in text:
		break
	n += 1

code = (
	"local m = game.ReplicatedFirst.AllSideCode.FirstPreload.LoadingUI\n"
	f"m.Source = {open_d}{text}{close_d}\n"
	"return 'ok len=' .. #m.Source\n"
)
out = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_inject.luau")
out.write_text(code, encoding="utf-8")
print(f"n={n} code_len={len(code)}")
