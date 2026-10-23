# -*- coding: utf-8 -*-
import pathlib
import sys

n = int(sys.argv[1])
c = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_chunks") / f"{n}.txt"
text = c.read_text(encoding="ascii")
sys.stdout.write(
    f'local f=game.ServerStorage._ArmSkinInject local v=Instance.new("StringValue") '
    f'v.Name="{n}" v.Value=[[{text}]] v.Parent=f return #v.Value'
)
