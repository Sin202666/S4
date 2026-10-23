"""Compile Luau sources and run engine-independent fault-injection tests.

Usage: python scripts/check_framework.py --luau-dir PATH_TO_OFFICIAL_LUAU_TOOLS
Author: 林奥宇
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau-dir", type=Path, required=True)
    args = parser.parse_args()
    suffix = ".exe" if os.name == "nt" else ""
    compiler = args.luau_dir / ("luau-compile" + suffix)
    runtime = args.luau_dir / ("luau" + suffix)
    sources = sorted((ROOT / "src").rglob("*.luau")) + sorted((ROOT / "scripts").glob("*.luau"))
    failures = []
    for source in sources:
        result = subprocess.run([str(compiler), "--null", str(source)], capture_output=True, text=True, encoding="utf-8")
        if result.returncode:
            failures.append(result.stderr)
    print(f"Syntax: {len(sources)} files, {len(failures)} failures", flush=True)
    for failure in failures:
        print(failure)
    if failures:
        return 1
    # Engine-free core algorithms have no Roblox globals, so analyze them without stubs.
    pure_modules = [
        "ServerStorage/ServerSideCode/System/SystemDataStore/ValueGuard.luau",
        "ServerStorage/ServerSideCode/System/SystemBag/BagRemovePlan.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/NetWork/RequestBudget.luau",
        "StarterPlayer/StarterCharacterScripts/Animate/FallVfxState.luau",
        "StarterPlayer/StarterCharacterScripts/Animate/FallVfxConfig.luau",
    ]
    analyzer = args.luau_dir / ("luau-analyze" + suffix)
    analyzed = subprocess.run([str(analyzer), *[str(ROOT / "src" / name) for name in pure_modules]])
    if analyzed.returncode:
        return analyzed.returncode
    print(f"Analysis: {len(pure_modules)} core modules passed", flush=True)
    fall_checks = subprocess.run([str(runtime), str(ROOT / "tests" / "fall_vfx.spec.luau")])
    if fall_checks.returncode:
        return fall_checks.returncode
    # Load actual production source into isolated mocked environments; no copying algorithms into tests.
    modules = [
        "ServerStorage/ServerSideCode/System/SystemDataStore/init.luau",
        "ServerStorage/ServerSideCode/System/SystemDataStore/StoreRegistry.luau",
        "ServerStorage/ServerSideCode/System/SystemDataStore/StoreKeys.luau",
        "ServerStorage/ServerSideCode/System/SystemEmail.luau",
        "ServerStorage/ServerSideCode/System/SystemPurchaseRecovery.luau",
        "ServerStorage/ServerSideCode/System/SystemBag/BagInventory.luau",
        "ServerStorage/ServerSideCode/System/SystemBag/BagUseItem.luau",
        "ReplicatedStorage/ShortVideoFeature/Server/SocialStore.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/NetWork/RequestBudget.luau",
        "ServerStorage/ServerSideCode/System/SystemSave/TransactionArchive.luau",
        "ServerStorage/ServerSideCode/System/SystemDataStore/ValueGuard.luau",
        "ServerStorage/ServerSideCode/System/SystemBag/BagRemovePlan.luau",
        "ServerStorage/ServerSideCode/System/SystemSave/init.luau",
        "ServerStorage/ServerSideCode/System/SystemBuyRoblox.luau",
        "ServerStorage/ServerSideCode/System/SystemCDK.luau",
        "ServerStorage/ServerSideCode/System/SystemSave/SaveMetaData.luau",
        "ServerStorage/ServerSideCode/System/SystemSave/FixData.luau",
        "ServerStorage/ServerSideCode/System/SystemSave/SessionPolicy.luau",
        "ServerStorage/ServerSideCode/System/SystemBag/BagPlan.luau",
        "ReplicatedStorage/ShortVideoFeature/Server/LikePolicy.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/UpdateModule.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/NetWork/PayloadGuard.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/NetWork/InboundDispatch.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/NetWork/init.luau",
        "ReplicatedFirst/AllSideCode/ToolSystem/RequestRateLimit.luau",
    ]
    bundle = ["local sources = {}"]
    for module in modules:
        content = (ROOT / "src" / module).read_text(encoding="utf-8-sig")
        assert "]====]" not in content
        bundle.append(f'sources["{module}"] = [====[{content}]====]')
    bundle.append("""
local function loadModule(path, env)
    local chunk = assert(loadstring(sources[path], path))
    setfenv(chunk, setmetatable(env or {}, { __index = getfenv() }))
    return chunk()
end
""")
    bundle.append((ROOT / "tests" / "framework.spec.luau").read_text(encoding="utf-8"))
    with tempfile.TemporaryDirectory(prefix="framework-tests-") as directory:
        target = Path(directory) / "run.luau"
        target.write_text("\n".join(bundle), encoding="utf-8")
        return subprocess.run([str(runtime), str(target)]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
