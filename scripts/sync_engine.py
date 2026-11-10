#!/usr/bin/env python3
"""Sync the shared engine from the template into game repos (see template docs/ENGINE.md).

Usage:
  python3 scripts/sync_engine.py <game-dir>...           copy the engine into each game
  python3 scripts/sync_engine.py --check <game-dir>...   report games behind or edited locally

A sync copies lib/engine, test/engine, test/fixtures and tool/content_cli.dart from the template,
rewrites `package:flutter_game_template/` to the game's own package, deletes engine files the
template no longer has, copies scripts/engine_lock.py and writes engine.lock. Nothing outside the
engine paths is touched. --check exits 1 when any game is behind the template or its engine files
were edited locally; it changes nothing.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import importlib.util
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = REPO_ROOT / "template" / "flutter-game-template"


class SyncError(Exception):
    pass


def _load_lock(root: Path):
    spec = importlib.util.spec_from_file_location("engine_lock", root / "scripts" / "engine_lock.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _game_pkg(lock, game: Path) -> str:
    if not (game / "pubspec.yaml").is_file():
        raise SyncError(f"{game}: not a Flutter project (no pubspec.yaml)")
    pkg = lock.package_name(game)
    if pkg == lock.TEMPLATE_PKG:
        raise SyncError(f"{game}: refusing to sync into the template itself")
    return pkg


def sync_game(game: Path, template: Path = TEMPLATE_DIR) -> None:
    lock = _load_lock(template)
    pkg = _game_pkg(lock, game)
    template_files = {f.relative_to(template).as_posix(): f for f in lock.engine_files(template)}
    # stale: engine files in the game that the template no longer has
    for f in lock.engine_files(game):
        rel = f.relative_to(game).as_posix()
        if rel not in template_files:
            f.unlink()
    for rel_dir in lock.ENGINE_PATHS:
        d = game / rel_dir
        if d.is_dir():
            for sub in sorted((p for p in d.rglob("*") if p.is_dir()), reverse=True):
                if not any(sub.iterdir()):
                    sub.rmdir()
    for rel, src in template_files.items():
        dst = game / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        data = src.read_bytes()
        if rel.endswith(".dart"):
            data = data.replace(
                f"package:{lock.TEMPLATE_PKG}/".encode(), f"package:{pkg}/".encode()
            )
        dst.write_bytes(data)
    (game / "scripts").mkdir(exist_ok=True)
    shutil.copyfile(template / "scripts" / "engine_lock.py", game / "scripts" / "engine_lock.py")
    _load_lock(game).write_lock(game)


def check_game(game: Path, template: Path = TEMPLATE_DIR) -> str | None:
    """Returns a problem description, or None when the game is in sync and unedited."""
    tlock = _load_lock(template)
    _game_pkg(tlock, game)
    if not (game / "scripts" / "engine_lock.py").is_file():
        return "behind: no scripts/engine_lock.py (never synced)"
    glock = _load_lock(game)
    locked = glock.read_lock(game)
    if locked is None:
        return "behind: no engine.lock (never synced)"
    problems = []
    if glock.engine_hash(game) != locked:
        problems.append("edited locally: engine files differ from engine.lock")
    if locked != tlock.engine_hash(template):
        problems.append("behind: engine.lock is not the template's engine")
    return "; ".join(problems) or None


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Sync the shared engine into game repos.")
    p.add_argument("games", nargs="+", type=Path, help="game repo directories")
    p.add_argument("--check", action="store_true", help="report only; exit 1 if any game differs")
    args = p.parse_args(argv)
    bad = 0
    for game in args.games:
        try:
            if args.check:
                problem = check_game(game)
                print(f"{game}: {problem or 'in sync'}")
                bad += problem is not None
            else:
                sync_game(game)
                print(f"{game}: synced")
        except SyncError as e:
            print(f"error: {e}", file=sys.stderr)
            return 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
