# -*- coding: utf-8 -*-
from pathlib import Path

p = Path(__file__).resolve().parent / "_gen_aw_xlsx.py"
t = p.read_text(encoding="utf-8")
repls = [
	('["Id", "ZhName", "Mult", "Rarity", "Weight"', '["Id", "ZhName", "Mult", "Xyd", "Weight"'),
	('["Id", "ZhName", "Mult", "Rarity", "Price", "Robux"', '["Id", "ZhName", "Mult", "Xyd", "Price", "Robux"'),
	('["Id", "ZhName", "Mult", "Rarity", "Price", "PlateR"', '["Id", "ZhName", "Mult", "Xyd", "Price", "PlateR"'),
	(
		'["string", "string", "number", "string", "number", "string", "number", "number", "number", "number", "string", "string"]',
		'["string", "string", "number", "number", "number", "string", "number", "number", "number", "number", "string", "string"]',
	),
	(
		'["number", "string", "number", "string", "number", "number", "string", "number", "number", "number", "number", "string"]',
		'["number", "string", "number", "number", "number", "number", "string", "number", "number", "number", "number", "string"]',
	),
	(
		'["number", "string", "number", "string", "number", "number", "number", "number", "string", "number", "number", "number", "number", "string"]',
		'["number", "string", "number", "number", "number", "number", "number", "number", "string", "number", "number", "number", "number", "string"]',
	),
]
for a, b in repls:
	if a not in t:
		raise SystemExit(f"missing: {a[:60]}")
	t = t.replace(a, b)
for name, num in (
	("Common", 1),
	("Uncommon", 2),
	("Rare", 3),
	("Epic", 4),
	("Legendary", 5),
	("Mythic", 6),
	("Exclusive", 7),
):
	t = t.replace(f'"{name}"', str(num))
p.write_text(t, encoding="utf-8", newline="\n")
print("ok")
