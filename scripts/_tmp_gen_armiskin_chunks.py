# -*- coding: utf-8 -*-
import base64
import pathlib

text = pathlib.Path(
    r"d:\Git\Roblox\A4_Slap\src\ReplicatedFirst\AllSideCode\ToolSystem\ArmSkin.luau"
).read_text(encoding="utf-8").replace("\r\n", "\n")
b64 = base64.b64encode(text.encode("utf-8")).decode("ascii")
chunks = [b64[i : i + 3500] for i in range(0, len(b64), 3500)]
path = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_chunks")
path.mkdir(exist_ok=True)
for i, c in enumerate(chunks):
    (path / f"{i}.txt").write_text(c, encoding="ascii")
    code = (
        f'local f=game.ServerStorage._ArmSkinInject '
        f'local v=Instance.new("StringValue") '
        f'v.Name="{i}" v.Value=[[{c}]] v.Parent=f return #v.Value'
    )
    (path / f"inject_{i}.luau").write_text(code, encoding="utf-8", newline="\n")
(path / "count.txt").write_text(str(len(chunks)), encoding="ascii")
print(len(chunks), sum(len(c) for c in chunks))
