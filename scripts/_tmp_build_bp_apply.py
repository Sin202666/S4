from pathlib import Path

outdir = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_json_chunks")
count = int((outdir / "count.txt").read_text())
parts = [(outdir / f"{i}.txt").read_text(encoding="utf-8") for i in range(count)]
pieces = []
for part in parts:
    assert "]==]" not in part
    pieces.append(f"[==[{part}]==]")

code = (
    'local buf = game.ReplicatedStorage:FindFirstChild("_BPSyncJson")\n'
    "if not buf then\n"
    '\tbuf = Instance.new("StringValue")\n'
    '\tbuf.Name = "_BPSyncJson"\n'
    "\tbuf.Parent = game.ReplicatedStorage\n"
    "end\n"
    'buf.Value = ""\n'
    + "\n".join([f"buf.Value ..= {p}" for p in pieces])
    + "\n"
    'local Hs = game:GetService("HttpService")\n'
    "local src = Hs:JSONDecode(buf.Value)\n"
    "local m = game.ReplicatedStorage.ClientSideCode.SystemModule.SystemArmWrestle.BattlePose\n"
    "m.Source = src\n"
    "buf:Destroy()\n"
    "return {\n"
    "\tn = #m.Source,\n"
    '\thasMeet = string.find(m.Source, "RIGHT_MEET_LOCAL", 1, true) ~= nil,\n'
    '\thasLeftPlayer = string.find(m.Source, "LEFT_REST_PLAYER_LOCAL", 1, true) ~= nil,\n'
    "\thead = string.sub(m.Source, 1, 60),\n"
    "}\n"
)

out = Path(r"d:/Git/Roblox/A4_Slap/scripts/_tmp_bp_apply_json.luau")
out.write_text(code, encoding="utf-8", newline="\n")
print("wrote", out.stat().st_size, "parts", count)
