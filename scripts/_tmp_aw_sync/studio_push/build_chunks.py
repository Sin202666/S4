# -*- coding: utf-8 -*-
"""Build base64 execute_luau chunks to push local Source into Studio."""
from __future__ import annotations

import base64
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent
SRC_ROOT = Path(r"d:/Git/Roblox/A4_Slap/src")

TARGETS = [
	(
		"ConfigInstance",
		"game.ReplicatedFirst.AllSideCode.ToolBasic.ConfigInstance",
		SRC_ROOT / "ReplicatedFirst/AllSideCode/ToolBasic/ConfigInstance.luau",
	),
	(
		"Language",
		"game.ReplicatedFirst.AllSideCode.ToolBasic.TranslationHelper.Language",
		SRC_ROOT / "ReplicatedFirst/AllSideCode/ToolBasic/TranslationHelper/Language.luau",
	),
	(
		"ArmWrestleConfig",
		"game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig",
		SRC_ROOT / "ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau",
	),
	(
		"CfgFind",
		"game.ReplicatedFirst.AllSideCode.ToolSystem.CfgFind",
		SRC_ROOT / "ReplicatedFirst/AllSideCode/ToolSystem/CfgFind.luau",
	),
	(
		"SystemBuyRoblox",
		"game.ServerStorage.ServerSideCode.System.SystemBuyRoblox",
		SRC_ROOT / "ServerStorage/ServerSideCode/System/SystemBuyRoblox.luau",
	),
	(
		"SystemBuyRobloxClient",
		"game.ReplicatedStorage.ClientSideCode.SystemModule.SystemBuyRoblox",
		SRC_ROOT / "ReplicatedStorage/ClientSideCode/SystemModule/SystemBuyRoblox/init.luau",
	),
	(
		"Common",
		"game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Common",
		SRC_ROOT / "ReplicatedStorage/ClientSideCode/GuiScripts/ModuleScript/ArmWrestleHUD/Common.luau",
	),
	(
		"Economy",
		"game.ServerStorage.ServerSideCode.System.SystemArmWrestle.Economy",
		SRC_ROOT / "ServerStorage/ServerSideCode/System/SystemArmWrestle/Economy.luau",
	),
	(
		"SystemArmWrestle",
		"game.ServerStorage.ServerSideCode.System.SystemArmWrestle",
		SRC_ROOT / "ServerStorage/ServerSideCode/System/SystemArmWrestle/init.luau",
	),
]

DEC = r'''local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local lookup = {}
for i = 1, #alphabet do
	lookup[string.byte(alphabet, i)] = i - 1
end
local function b64decode(data)
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

CHUNK = 2500


def main() -> None:
	manifest = []
	for name, inst, path in TARGETS:
		src = path.read_text(encoding="utf-8").replace("\r\n", "\n")
		if "]=]" in src:
			raise SystemExit(f"longstring conflict: {name}")
		parts = [src[i : i + CHUNK] for i in range(0, len(src), CHUNK)]
		folder = OUT / name
		folder.mkdir(exist_ok=True)
		(folder / "00_clear.luau").write_text(
			f"local m = {inst}\nm.Source = \"\"\nreturn #m.Source\n",
			encoding="utf-8",
			newline="\n",
		)
		for i, part in enumerate(parts):
			append = f"local m = {inst}\nm.Source ..= [=[{part}]=]\nreturn #m.Source\n"
			b64 = base64.b64encode(append.encode("utf-8")).decode("ascii")
			code = DEC + f'local src = b64decode("{b64}")\nlocal fn, err = load(src)\nassert(fn, err)\nreturn fn()\n'
			(folder / f"{i + 1:02d}.luau").write_text(code, encoding="utf-8", newline="\n")
		(folder / "count.txt").write_text(str(len(parts)), encoding="utf-8")
		manifest.append({"name": name, "inst": inst, "parts": len(parts), "chars": len(src)})
		print(name, "parts", len(parts), "chars", len(src))
	(OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
	print("done")


if __name__ == "__main__":
	main()
