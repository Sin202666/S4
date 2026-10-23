"""Download pinned official CI tools; verify release asset digest when supplied.

Author: 林奥宇
"""
import hashlib
import io
import json
import os
from pathlib import Path
import urllib.request
import zipfile

EXPECTED_DIGESTS = {
    # Official release expanded_assets pages; versions change only together with these digests.
    "luau-ubuntu.zip": "152058b98c60ff1f5b5ec9bca0b8eb37793cae161dd3a05608cc3d8738ba1a4d",
    "rojo-7.7.0-rc.1-linux-x86_64.zip": "3d29a60590365303fdd2a1e3c4684e44da7c4eb4de2b19fcf9884cc20a1ccd0c",
}

def install(repo, tag, accepts, destination):
    request = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/releases/tags/{tag}",
        headers={"User-Agent": "Dev-Framework-CI", "Accept": "application/vnd.github+json"},
    )
    with urllib.request.urlopen(request, timeout=60) as response:
        release = json.load(response)
    matches = [asset for asset in release["assets"] if accepts(asset["name"])]
    if len(matches) != 1:
        raise RuntimeError(f"Expected one Linux archive for {repo}@{tag}, got {[a['name'] for a in matches]}")
    asset = matches[0]
    with urllib.request.urlopen(asset["browser_download_url"], timeout=60) as response:
        archive = response.read()
    digest = EXPECTED_DIGESTS[asset["name"]]
    if digest != hashlib.sha256(archive).hexdigest():
        raise RuntimeError(f"Digest mismatch: {asset['name']}")
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(io.BytesIO(archive)) as bundle:
        root = destination.resolve()
        for member in bundle.infolist():
            if not (root / member.filename).resolve().is_relative_to(root):
                raise RuntimeError("Archive contains an unsafe path")
        bundle.extractall(destination)
    for binary in destination.rglob("*"):
        if binary.is_file():
            binary.chmod(0o755)
    print(f"Installed {repo}@{tag}: {asset['name']}")


if __name__ == "__main__":
    install("luau-lang/luau", os.environ["LUAU_VERSION"], lambda n: n == "luau-ubuntu.zip", Path("/tmp/luau"))
    install("rojo-rbx/rojo", "v" + os.environ["ROJO_VERSION"],
            lambda n: n.endswith("linux-x86_64.zip"), Path("/tmp/rojo"))
