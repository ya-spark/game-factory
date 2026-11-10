#!/usr/bin/env python3
"""Engine lock: proves a game's copy of the shared engine is the one the factory shipped.

The engine is vendored into every game (see docs/ENGINE.md). It is the files under
lib/engine, test/engine, test/fixtures and tool/content_cli.dart. The lock is a SHA-256 over
their relative names and bytes, with `package:<this game>/` normalised to
`package:flutter_game_template/` so the same engine hashes the same in every game.

  python3 scripts/engine_lock.py hash     print the hash of this repo's engine files
  python3 scripts/engine_lock.py write    write it to engine.lock (done by scripts/sync_engine.py)
  python3 scripts/engine_lock.py check    exit 1 if the engine files differ from engine.lock

Run from anywhere; the repo root is the parent of this script's folder. Standard library only.
"""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LOCK_FILE = "engine.lock"
TEMPLATE_PKG = "flutter_game_template"
ENGINE_PATHS = ("lib/engine", "test/engine", "test/fixtures", "tool/content_cli.dart")


def package_name(root: Path) -> str:
    m = re.search(r"^name:\s*(\S+)\s*$", (root / "pubspec.yaml").read_text("utf-8"), re.M)
    if not m:
        raise SystemExit("engine_lock: no name: in pubspec.yaml")
    return m.group(1)


def engine_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for rel in ENGINE_PATHS:
        p = root / rel
        if p.is_dir():
            files += [f for f in p.rglob("*") if f.is_file()]
        elif p.is_file():
            files.append(p)
    return sorted(files, key=lambda f: f.relative_to(root).as_posix())


def normalise(data: bytes, pkg: str) -> bytes:
    return data.replace(f"package:{pkg}/".encode(), f"package:{TEMPLATE_PKG}/".encode())


def engine_hash(root: Path = ROOT) -> str:
    pkg = package_name(root)
    h = hashlib.sha256()
    for f in engine_files(root):
        name = f.relative_to(root).as_posix().encode()
        data = normalise(f.read_bytes().replace(b"\r\n", b"\n"), pkg)
        h.update(len(name).to_bytes(4, "big") + name)
        h.update(len(data).to_bytes(8, "big") + data)
    return h.hexdigest()


def read_lock(root: Path = ROOT) -> str | None:
    f = root / LOCK_FILE
    return f.read_text("utf-8").strip().removeprefix("sha256:") if f.is_file() else None


def write_lock(root: Path = ROOT) -> str:
    digest = engine_hash(root)
    (root / LOCK_FILE).write_text(f"sha256:{digest}\n", encoding="utf-8")
    return digest


def check(root: Path = ROOT) -> int:
    locked = read_lock(root)
    if locked is None:
        print(f"ENGINE LOCK: {LOCK_FILE} is missing (run scripts/sync_engine.py)", file=sys.stderr)
        return 1
    actual = engine_hash(root)
    if actual != locked:
        print(
            "ENGINE LOCK: the engine files differ from engine.lock. Do not edit the engine in a "
            "game: change game-factory and run a sync (docs/ENGINE.md).",
            file=sys.stderr,
        )
        return 1
    print("ENGINE LOCK: OK")
    return 0


def main(argv: list[str]) -> int:
    cmd = argv[0] if argv else ""
    if cmd == "hash":
        print(engine_hash())
        return 0
    if cmd == "write":
        print(write_lock())
        return 0
    if cmd == "check":
        return check()
    print(__doc__, file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
