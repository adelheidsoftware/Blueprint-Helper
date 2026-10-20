"""Builds the Mod.io upload: dist/blueprint-helper-<version>.zip with main.lua and plugin.json at the top level.

Usage:   py package.py [--skip-tests]

Only the files the client loads go into the zip archive.
Luacheck (when installed) and the test suite run first, and a failure in either stops the build.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DIST = ROOT / "dist"
FILES = ["main.lua", "plugin.json"]
FOLDERS = ["src"]


def fail(message):
    sys.exit(f"package: {message}")


def read_version():
    version = json.loads((ROOT / "plugin.json").read_text(encoding="utf-8")).get("version", "")
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        fail(f'plugin.json version "{version}" must be three numbers with dots, as manifest_test checks')
    constants = (ROOT / "src" / "constants.lua").read_text(encoding="utf-8")
    match = re.search(r'Constants\.VERSION\s*=\s*"([^"]*)"', constants)
    if not match or match.group(1) != version:
        fail(f"plugin.json says {version} but src/constants.lua says {match.group(1) if match else 'nothing'}")
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    if f"## [{version}]" not in changelog:
        fail(f"CHANGELOG.md has no entry for {version}; add a '## [{version}]' heading with the release notes")
    return version


def find_lua():
    candidates = [os.environ.get("LUA"), shutil.which("lua"),
                  Path(os.environ.get("LOCALAPPDATA", "")) / "Programs" / "Lua" / "bin" / "lua.exe"]
    for candidate in candidates:
        if candidate and Path(candidate).is_file():
            return str(candidate)
    fail("no Lua interpreter found; set LUA to its path, or pass --skip-tests")


def run_tests():
    result = subprocess.run([find_lua(), str(ROOT / "tests" / "run_all.lua")])
    if result.returncode != 0:
        fail("tests failed; nothing was packaged")


def run_lint():
    luacheck = os.environ.get("LUACHECK") or shutil.which("luacheck")
    if not luacheck:
        print("package: luacheck not found, so the lint step was skipped; set LUACHECK or put it on PATH")
        return
    result = subprocess.run([luacheck, "--quiet", "main.lua", "src", "tests"], cwd=ROOT)
    if result.returncode != 0:
        fail("luacheck reported problems; nothing was packaged")


def collect():
    paths = [ROOT / name for name in FILES]
    for folder in FOLDERS:
        paths += sorted(p for p in (ROOT / folder).rglob("*") if p.is_file())
    missing = [p for p in paths if not p.is_file()]
    if missing:
        fail("missing " + ", ".join(str(p.relative_to(ROOT)) for p in missing))
    return paths


def main():
    parser = argparse.ArgumentParser(description="Package Blueprint Helper for Mod.io.")
    parser.add_argument("--skip-tests", action="store_true", help="build without running the test suite")
    args = parser.parse_args()

    version = read_version()
    if not args.skip_tests:
        run_lint()
        run_tests()

    DIST.mkdir(exist_ok=True)
    target = DIST / f"blueprint-helper-{version}.zip"
    paths = collect()
    with zipfile.ZipFile(target, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in paths:
            # as_posix keeps forward slashes, which every zip reader expects
            archive.write(path, path.relative_to(ROOT).as_posix())
    print(f"{target.relative_to(ROOT)}: {len(paths)} files, {target.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
