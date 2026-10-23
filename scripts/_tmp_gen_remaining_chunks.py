# -*- coding: utf-8 -*-
import pathlib

path = pathlib.Path(r"d:\Git\Roblox\A4_Slap\scripts\_tmp_armiskin_chunks")
needed = [1, 3, 4, 5, 6]
parts = [
    'local f=game.ServerStorage._ArmSkinInject',
    'local function put(n, s) local v=Instance.new("StringValue") v.Name=tostring(n) v.Value=s v.Parent=f end',
]
for n in needed:
    c = (path / f"{n}.txt").read_text(encoding="ascii")
    assert "]]" not in c
    parts.append(f"put({n}, [[{c}]])")
parts.append('local names={} for _,c in ipairs(f:GetChildren()) do table.insert(names,c.Name) end table.sort(names) return table.concat(names,",")')
out = path / "inject_remaining.luau"
out.write_text("\n".join(parts), encoding="utf-8", newline="\n")
print(out.stat().st_size)
