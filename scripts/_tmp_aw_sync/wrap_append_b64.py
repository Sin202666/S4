# -*- coding: utf-8 -*-
import base64
from pathlib import Path

DEC = '''local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data: string): string
	data = string.gsub(data, "[^A-Za-z0-9+/=]", "")
	local out = table.create(math.ceil(#data * 3 / 4))
	local n = 0
	for i = 1, #data, 4 do
		local a = lookup[string.byte(data, i)] or 0
		local b = lookup[string.byte(data, i + 1)] or 0
		local c = lookup[string.byte(data, i + 2)] or 0
		local d = lookup[string.byte(data, i + 3)] or 0
		n += 1
		out[n] = string.char(bit32.bor(bit32.lshift(a, 2), bit32.rshift(b, 4)))
		if string.sub(data, i + 2, i + 2) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(b, 4), bit32.rshift(c, 2)), 255))
		end
		if string.sub(data, i + 3, i + 3) ~= "=" then
			n += 1
			out[n] = string.char(bit32.band(bit32.bor(bit32.lshift(c, 6), d), 255))
		end
	end
	return table.concat(out)
end
'''

src_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/append_codes")
out_dir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/wrapped")
out_dir.mkdir(exist_ok=True)
for path in sorted(src_dir.glob("*_append.luau")):
	raw = path.read_bytes()  # exact UTF-8 file bytes
	b64 = base64.b64encode(raw).decode("ascii")
	code = (
		DEC
		+ f'local src = b64decode("{b64}")\n'
		+ "local fn, err = load(src)\n"
		+ "assert(fn, err)\n"
		+ "return fn()\n"
	)
	out = out_dir / path.name
	out.write_text(code, encoding="utf-8", newline="\n")
	print(out.name, out.stat().st_size)
