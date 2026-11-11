#!/usr/bin/env python3
"""Sync a standalone game into a Mind hub as a copy (see game-studio docs/GAME_SYNC.md).

Usage:
  python3 scripts/sync_game.py <game-repo> <hub-repo> <game>           copy the game into the hub
  python3 scripts/sync_game.py --check <game-repo> <hub-repo> <game>   report hubs behind or edited

The standalone repo is only read. The copy goes to `lib/games/<game>/` (code), `test/games/<game>/`
(the game's own tests) and `assets/games/<game>/` is NOT used: assets keep their path under the
hub's `assets/` because the code loads them by name. Per game the table GAMES says which paths are
copied. Every Dart import is resolved: an import that stays inside the copied set is kept, an
import of a standalone-only file (its own shop, ads, profile ...) is rewritten to the hub's host
adapter `lib/games/<game>/host/<file>`, which the hub owns and the sync never touches. An import
that is neither is an error, so nothing standalone-only slips in unseen.

`lib/games/<game>/game.lock` records the source commit and a hash of the copy. --check exits 1 when
the copy was edited locally (hash differs) or is behind the source `HEAD`; it changes nothing.

Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import posixpath
import re
import shutil
import subprocess
import sys
from pathlib import Path

LOCK_NAME = "game.lock"

# What is copied from each standalone repo. Paths are relative to the repo root. `code` entries
# land under lib/games/<game>/ (the part after `lib/`), `tests` under test/games/<game>/ (the part
# after `test/`), `assets` keep their path. `host` maps a standalone-only lib file to the adapter
# file the hub provides (relative to lib/games/<game>/host/).
GAMES: dict[str, dict] = {
    "block_puzzle": {
        "copy": [
            "lib/game",
            "lib/core/audio",
            "lib/core/save/save_data.dart",
            "lib/core/retention",
            "lib/core/clock.dart",
            "lib/ui/best_move_dialog.dart",
            "lib/ui/boost_widgets.dart",
            "lib/ui/game_over_panel.dart",
            "lib/ui/game_screen.dart",
            "lib/ui/home_hero.dart",
            "lib/ui/widgets.dart",
            "lib/ui/share_card.dart",
            "lib/ui/theme_background.dart",
            "lib/ui/test_ids.dart",
            "test/game",
            "test/helpers/puzzle_bot.dart",
            "assets/voice",
            "assets/ambience",
        ],
        "host": {
            "lib/core/services.dart": "services.dart",
            "lib/core/profile/profile_store.dart": "profile_store.dart",
            "lib/core/ads/ad_service.dart": "ad_service.dart",
            "lib/ui/routes.dart": "routes.dart",
        },
        # Test helpers that build the standalone's own Services: the hub provides its own under
        # test/games/<game>/host/ (imported by a relative path).
        "test_host": {
            "test/helpers/fake_services.dart": "fake_services.dart",
        },
    },
}


class SyncError(Exception):
    pass


def package_name(repo: Path) -> str:
    pub = repo / "pubspec.yaml"
    if not pub.is_file():
        raise SyncError(f"{repo}: not a Flutter project (no pubspec.yaml)")
    m = re.search(r"^name:\s*(\S+)", pub.read_text(), re.M)
    if not m:
        raise SyncError(f"{pub}: no name")
    return m.group(1)


def source_commit(repo: Path) -> str:
    try:
        out = subprocess.run(
            ["git", "-C", str(repo), "rev-parse", "HEAD"],
            check=True, capture_output=True, text=True,
        )
    except (OSError, subprocess.CalledProcessError) as e:
        raise SyncError(f"{repo}: cannot read the git commit ({e})")
    return out.stdout.strip()


def _expand(repo: Path, entries: list[str]) -> list[str]:
    """Repo-relative file paths for files and directories listed in the table."""
    out: set[str] = set()
    for e in entries:
        p = repo / e
        if p.is_dir():
            out.update(f.relative_to(repo).as_posix() for f in p.rglob("*") if f.is_file())
        elif p.is_file():
            out.add(e)
        else:
            raise SyncError(f"{repo}: listed path does not exist: {e}")
    return sorted(out)


def _dest(game: str, rel: str) -> str:
    """Where a source file lands in the hub, relative to the hub root."""
    if rel.startswith("lib/"):
        return f"lib/games/{game}/{rel[4:]}"
    if rel.startswith("test/"):
        return f"test/games/{game}/{rel[5:]}"
    return rel  # assets keep their path


_IMPORT = re.compile(r"""^(\s*(?:import|export|part)\s+)(['"])([^'"]+)\2""", re.M)


def rewrite_dart(text: str, rel: str, game: str, src_pkg: str, hub_pkg: str,
                 copied: set[str], host: dict[str, str],
                 test_host: dict[str, str] | None = None) -> str:
    """Rewrite the imports of one source file `rel` (repo-relative) for the hub."""
    here = posixpath.dirname(rel)

    def fix(m: re.Match) -> str:
        pre, q, target = m.group(1), m.group(2), m.group(3)
        if target.startswith("dart:"):
            return m.group(0)
        if not target.startswith("package:") and rel.startswith("test/"):
            hit = posixpath.normpath(posixpath.join(here, target))
            if hit in (test_host or {}):
                dest_dir = posixpath.dirname(_dest(game, rel))
                hub_file = f"test/games/{game}/host/{test_host[hit]}"
                return f"{pre}{q}{posixpath.relpath(hub_file, dest_dir)}{q}"
        if target.startswith("package:"):
            if target.startswith(f"package:{src_pkg}/"):
                resolved = "lib/" + target[len(f"package:{src_pkg}/"):]
            else:
                return m.group(0)  # a vendor package; the hub's pubspec must have it
        else:
            resolved = posixpath.normpath(posixpath.join(here, target))
        if resolved in copied:
            if target.startswith("package:"):
                new = f"package:{hub_pkg}/{_dest(game, resolved)[4:]}"
            else:
                new = target
        elif resolved in host:
            new = f"package:{hub_pkg}/games/{game}/host/{host[resolved]}"
        else:
            raise SyncError(
                f"{rel}: imports {resolved}, which is neither copied nor mapped to the hub's "
                f"host adapter (add it to GAMES['{game}'])"
            )
        return f"{pre}{q}{new}{q}"

    return _IMPORT.sub(fix, text)


def _plan(game: str, src: Path, hub: Path) -> dict[str, bytes]:
    """The full set of hub-relative files the copy consists of."""
    cfg = GAMES.get(game)
    if cfg is None:
        raise SyncError(f"unknown game '{game}' (known: {', '.join(sorted(GAMES)) or 'none'})")
    src_pkg, hub_pkg = package_name(src), package_name(hub)
    files = [f for f in _expand(src, cfg["copy"]) if f not in cfg.get("exclude", [])]
    copied = {f for f in files if f.startswith(("lib/", "test/"))}
    host = cfg.get("host", {})
    out: dict[str, bytes] = {}
    for rel in files:
        data = (src / rel).read_bytes()
        if rel.endswith(".dart"):
            data = rewrite_dart(
                data.decode(), rel, game, src_pkg, hub_pkg, copied, host,
                cfg.get("test_host", {}),
            ).encode()
        if rel.startswith("test/") and rel.endswith(".dart"):
            # tests that read source files by path (purity checks) look in the copy
            data = data.replace(b"'lib/", f"'lib/games/{game}/".encode())
        out[_dest(game, rel)] = data
    return out


def digest(files: dict[str, bytes]) -> str:
    h = hashlib.sha256()
    for rel in sorted(files):
        h.update(rel.encode() + b"\0")
        h.update(hashlib.sha256(files[rel]).digest())
    return "sha256:" + h.hexdigest()


def _hub_files(hub: Path, game: str, planned: set[str], prev: set[str]) -> dict[str, bytes]:
    """The files in the hub that belong to the copy: planned paths plus those the lock listed."""
    out = {}
    for rel in planned | prev:
        f = hub / rel
        if f.is_file():
            out[rel] = f.read_bytes()
    return out


def lock_path(hub: Path, game: str) -> Path:
    return hub / "lib" / "games" / game / LOCK_NAME


def read_lock(hub: Path, game: str) -> dict | None:
    p = lock_path(hub, game)
    return json.loads(p.read_text()) if p.is_file() else None


def sync(src: Path, hub: Path, game: str) -> None:
    if package_name(src) == package_name(hub):
        raise SyncError("source and hub are the same package")
    files = _plan(game, src, hub)
    prev = read_lock(hub, game)
    for rel in (prev or {}).get("files", []):  # files the source no longer has
        if rel not in files and (hub / rel).is_file():
            (hub / rel).unlink()
    for rel, data in files.items():
        dst = hub / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(data)
    # The hub's CI runs `dart format --set-exit-if-changed`, so the copy is stored formatted and
    # the lock hashes the formatted files.
    dart_files = [str(hub / r) for r in files if r.endswith(".dart")]
    if dart_files and shutil.which("dart"):
        subprocess.run(["dart", "format", *dart_files], check=True, capture_output=True)
    files = {rel: (hub / rel).read_bytes() for rel in files}
    lp = lock_path(hub, game)
    lp.parent.mkdir(parents=True, exist_ok=True)
    lp.write_text(json.dumps({
        "game": game,
        "source": src.name,
        "commit": source_commit(src),
        "hash": digest(files),
        "files": sorted(files),
    }, indent=2) + "\n")


def check(src: Path, hub: Path, game: str) -> str | None:
    """A problem description, or None when the copy is in sync and unedited."""
    lock = read_lock(hub, game)
    if lock is None:
        return "behind: no game.lock (never synced)"
    problems = []
    have = _hub_files(hub, game, set(), set(lock["files"]))
    if sorted(have) != lock["files"] or digest(have) != lock["hash"]:
        problems.append("edited locally: copied files differ from game.lock")
    if lock["commit"] != source_commit(src):
        problems.append("behind: the standalone game has newer commits than game.lock")
    return "; ".join(problems) or None


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Sync a standalone game into a Mind hub.")
    p.add_argument("game_repo", type=Path)
    p.add_argument("hub_repo", type=Path)
    p.add_argument("game", help="game key, e.g. block_puzzle")
    p.add_argument("--check", action="store_true", help="report only; exit 1 if out of sync")
    args = p.parse_args(argv)
    try:
        if args.check:
            problem = check(args.game_repo, args.hub_repo, args.game)
            print(f"{args.hub_repo}: {args.game}: {problem or 'in sync'}")
            return 1 if problem else 0
        sync(args.game_repo, args.hub_repo, args.game)
        print(f"{args.hub_repo}: {args.game}: synced")
        return 0
    except SyncError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
