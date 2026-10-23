# -*- coding: utf-8 -*-
"""Emit Luau snippets that set ModuleScript.Source from base64 chunks."""
from __future__ import annotations

import base64
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "scripts" / "_tmp_aw_xyd_sync"
OUT.mkdir(parents=True, exist_ok=True)

CHUNK = 12000

FILES = [
	(
		"ConfigInstance",
		ROOT / "src/ReplicatedFirst/AllSideCode/ToolBasic/ConfigInstance.luau",
		"game.ReplicatedFirst.AllSideCode.ToolBasic.ConfigInstance",
	),
	(
		"ArmWrestleConfig",
		ROOT / "src/ReplicatedFirst/AllSideCode/ToolSystem/ArmWrestleConfig.luau",
		"game.ReplicatedFirst.AllSideCode.ToolSystem.ArmWrestleConfig",
	),
	(
		"Cards",
		ROOT / "src/ReplicatedStorage/ClientSideCode/GuiScripts/ModuleScript/ArmWrestleHUD/Cards.luau",
		"game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Cards",
	),
	(
		"Panels",
		ROOT / "src/ReplicatedStorage/ClientSideCode/GuiScripts/ModuleScript/ArmWrestleHUD/Panels.luau",
		"game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Panels",
	),
	(
		"DumbbellPanel",
		ROOT / "src/ReplicatedStorage/ClientSideCode/GuiScripts/ModuleScript/ArmWrestleHUD/DumbbellPanel.luau",
		"game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.DumbbellPanel",
	),
	(
		"Roll",
		ROOT / "src/ReplicatedStorage/ClientSideCode/GuiScripts/ModuleScript/ArmWrestleHUD/Roll.luau",
		"game.ReplicatedStorage.ClientSideCode.GuiScripts.ModuleScript.ArmWrestleHUD.Roll",
	),
	(
		"MachineShowcase",
		ROOT / "src/ReplicatedStorage/ClientSideCode/SystemModule/SystemArmWrestle/MachineShowcase.luau",
		"game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.MachineShowcase",
	),
	(
		"ArmSkin",
		ROOT / "src/ReplicatedFirst/AllSideCode/ToolSystem/ArmSkin.luau",
		"game.ReplicatedFirst.AllSideCode.ToolSystem.ArmSkin",
	),
]


def emit(name: str, path: Path, target: str):
	raw = path.read_bytes()  # already utf-8
	b64 = base64.b64encode(raw).decode("ascii")
	parts = [b64[i : i + CHUNK] for i in range(0, len(b64), CHUNK)]
	dirp = OUT / name
	dirp.mkdir(parents=True, exist_ok=True)
	(dirp / "target.txt").write_text(target, encoding="utf-8")
	(dirp / "count.txt").write_text(str(len(parts)), encoding="utf-8")
	for i, part in enumerate(parts):
		(dirp / f"{i}.b64").write_text(part, encoding="ascii")
	# apply script: expects _G.__AW_XYD_PARTS already filled
	apply = f'''local parts = _G.__AW_XYD_PARTS
assert(type(parts) == "table" and #parts > 0, "no parts")
local b64 = table.concat(parts)
local src = game:GetService("HttpService"):Base64Decode(b64)
local m = {target}
m.Source = src
_G.__AW_XYD_PARTS = nil
return (#src) .. " bytes -> " .. m:GetFullName()
'''
	(dirp / "apply.luau").write_text(apply, encoding="utf-8", newline="\n")
	print(name, len(raw), "bytes", len(parts), "parts")


def main():
	for name, path, target in FILES:
		emit(name, path, target)


if __name__ == "__main__":
	main()
