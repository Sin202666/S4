from pathlib import Path

root = Path(__file__).resolve().parent
out = root / "patched"
out.mkdir(exist_ok=True)
for i in range(1, 10):
    text = (root / f"{i:02d}.luau").read_text(encoding="utf-8")
    text = text.replace("local fn, err = load(src)", "local fn, err = loadstring(src)")
    (out / f"{i:02d}.luau").write_text(text, encoding="utf-8", newline="\n")
    print(f"{i:02d}: {len(text)} loadstring={('loadstring(src)' in text)}")
