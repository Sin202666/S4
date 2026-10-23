# -*- coding: utf-8 -*-
import base64
from pathlib import Path

text = (
	Path(r"d:/Git/Roblox/A4_Slap/src/ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau")
	.read_text(encoding="utf-8")
	.replace("\r\n", "\n")
)
raw = text.encode("utf-8")
PIECE = 4500
PER_BATCH = 3
out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_aw_sync/b64_batches")
out.mkdir(parents=True, exist_ok=True)
for old in out.glob("*.luau"):
	old.unlink()

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

pieces = [base64.b64encode(raw[i : i + PIECE]).decode("ascii") for i in range(0, len(raw), PIECE)]
(out / "00_clear.luau").write_text(
	'local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig\nm.Source = ""\nreturn #m.Source\n',
	encoding="utf-8",
	newline="\n",
)
batch_i = 0
for start in range(0, len(pieces), PER_BATCH):
	batch = pieces[start : start + PER_BATCH]
	batch_i += 1
	lines = [DEC, "local m = game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig", "local parts = {"]
	for p in batch:
		lines.append(f'\t"{p}",')
	lines.append("}")
	lines.append("for _, p in ipairs(parts) do")
	lines.append("\tm.Source ..= b64decode(p)")
	lines.append("end")
	lines.append("return #m.Source")
	path = out / f"{batch_i:02d}_batch.luau"
	path.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
	print(path.name, path.stat().st_size)
print("pieces", len(pieces), "batches", batch_i)
