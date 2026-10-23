# -*- coding: utf-8 -*-
from pathlib import Path

out_q = Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_loadingui_q")
for i in range(4):
	raw = (out_q / f"{i}.txt").read_bytes()  # utf-8 bytes
	hex_str = raw.hex()
	# split hex into quoted pieces of 200 chars for readability
	pieces = [hex_str[j : j + 200] for j in range(0, len(hex_str), 200)]
	pieces_lua = ",\n\t".join(f'"{p}"' for p in pieces)
	code = f"""local s = game.ServerStorage._LoadingUISrc['p{i}']
local hex = table.concat({{
\t{pieces_lua}
}})
local out = table.create(#hex / 2)
for j = 1, #hex, 2 do
\tout[(j + 1) / 2] = string.char(tonumber(string.sub(hex, j, j + 1), 16))
end
s.Value = table.concat(out)
return #s.Value
"""
	Path(rf"d:\Git\Roblox\A4_Slap\scripts\_tmp_hex_p{i}.luau").write_text(code, encoding="ascii")
	print(f"{i} hex_len={len(hex_str)} code_len={len(code)}")
