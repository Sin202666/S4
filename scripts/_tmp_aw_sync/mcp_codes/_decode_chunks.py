import base64
import re
import pathlib

root = pathlib.Path(__file__).resolve().parent
out = root / "decoded"
out.mkdir(exist_ok=True)
pat = re.compile(r'b64decode\("([A-Za-z0-9+/=]+)"\)')
for i in range(1, 10):
    text = (root / f"{i:02d}.luau").read_text(encoding="utf-8")
    m = pat.search(text)
    if not m:
        raise SystemExit(f"no b64 in {i:02d}")
    decoded = base64.b64decode(m.group(1)).decode("utf-8")
    p = out / f"{i:02d}.luau"
    p.write_text(decoded, encoding="utf-8", newline="\n")
    print(f"{i:02d}: {len(decoded)} chars")
