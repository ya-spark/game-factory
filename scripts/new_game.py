#!/usr/bin/env python3
"""Generate a new game project from template/flutter-game-template.

Usage:
  python3 scripts/new_game.py --id my_game --name "My Game" \
      --package com.yaspark.mygame --seed-color "#RRGGBB" --out <dir> [--register]

Python 3 standard library only. Never writes secrets: admob.release and play_games values
stay PLACEHOLDER_* (they are only filled in later by the release config / CI secrets).
"""

from __future__ import annotations

import argparse
import re
import shutil
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TEMPLATE_DIR = REPO_ROOT / "template" / "flutter-game-template"
REGISTRY_FILE = REPO_ROOT / "registry" / "apps.yaml"

TEMPLATE_PKG = "flutter_game_template"
EXCLUDE_DIRS = {".dart_tool", "build", ".idea"}
EXCLUDE_FILES = {"local.properties"}  # only excluded under android/
EXCLUDE_SUFFIXES = (".iml",)

ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
PKG_SEGMENT_RE = re.compile(r"^[a-z][a-z0-9_]*$")
COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")

# Words that cannot be a Dart package name or an Android/Java/Kotlin package segment.
RESERVED = {
    "abstract", "as", "assert", "async", "await", "boolean", "break", "byte", "case",
    "catch", "char", "class", "const", "continue", "covariant", "default", "deferred",
    "do", "double", "dynamic", "else", "enum", "export", "extends", "extension",
    "external", "factory", "false", "final", "finally", "float", "for", "function",
    "get", "goto", "if", "implements", "import", "in", "instanceof", "int", "interface",
    "is", "late", "library", "long", "mixin", "native", "new", "null", "operator", "package",
    "part", "private", "protected", "public", "required", "rethrow", "return", "set",
    "short", "static", "strictfp", "super", "switch", "synchronized", "this", "throw",
    "throws", "transient", "true", "try", "typedef", "var", "void", "volatile", "while",
    "with", "yield",
}


class GenError(Exception):
    """User-facing error (bad input, refusal)."""


# ---------------------------------------------------------------- validation
def validate_id(game_id: str) -> None:
    if not ID_RE.match(game_id):
        raise GenError(f"invalid --id {game_id!r}: must be snake_case ([a-z][a-z0-9_]*)")
    if game_id in RESERVED:
        raise GenError(f"invalid --id {game_id!r}: reserved word")
    if game_id == TEMPLATE_PKG:
        raise GenError(f"invalid --id {game_id!r}: reserved for the template itself")


def validate_package(package: str) -> None:
    segments = package.split(".")
    if len(segments) < 2 or not all(PKG_SEGMENT_RE.match(s) for s in segments):
        raise GenError(
            f"invalid --package {package!r}: need >= 2 dot-separated lowercase segments "
            "starting with a letter (letters, digits, underscore)"
        )
    bad = [s for s in segments if s in RESERVED]
    if bad:
        raise GenError(f"invalid --package {package!r}: reserved word segment(s) {bad}")
    if TEMPLATE_PKG in package:
        raise GenError(f"invalid --package {package!r}: must not contain {TEMPLATE_PKG}")


def validate_name(name: str) -> None:
    if not name.strip():
        raise GenError("invalid --name: must not be empty")
    # app.config.yaml is read by a tiny line-based Gradle reader: keep the value simple.
    if re.search(r"""["'#\\\x00-\x1f]""", name):
        raise GenError(
            "invalid --name: must not contain quotes, '#', backslashes or control characters"
        )


def validate_color(color: str) -> None:
    if not COLOR_RE.match(color):
        raise GenError(f"invalid --seed-color {color!r}: expected #RRGGBB")


def kebab(game_id: str) -> str:
    return game_id.replace("_", "-")


# ------------------------------------------------------------------ registry
def registry_ids(text: str) -> tuple[set[str], set[str]]:
    ids = set(re.findall(r"^\s*-\s*id:\s*(\S+)\s*$", text, re.M))
    pkgs = set(re.findall(r"^\s+package:\s*(\S+)\s*$", text, re.M))
    return ids, pkgs


def check_registry(registry: Path, game_id: str, package: str) -> None:
    if not registry.is_file():
        raise GenError(f"registry file not found: {registry}")
    ids, pkgs = registry_ids(registry.read_text(encoding="utf-8"))
    if game_id in ids or kebab(game_id) in ids:
        raise GenError(f"registry already contains id {game_id!r}; refusing to register twice")
    if package in pkgs:
        raise GenError(f"registry already contains package {package!r}")


def register(registry: Path, game_id: str, package: str) -> None:
    check_registry(registry, game_id, package)
    text = registry.read_text(encoding="utf-8")
    entry = (
        f"  - id: {game_id}\n"
        f"    repo: ya-spark/game-{kebab(game_id)}\n"
        f"    package: {package}\n"
        f"    status: draft\n"
    )
    flow_empty = re.compile(r"^apps:[ \t]*\[\][ \t]*(#.*)?$", re.M)
    if flow_empty.search(text):
        text = flow_empty.sub("apps:\n" + entry.rstrip("\n"), text, count=1)
        text = text.rstrip("\n") + "\n"
    else:
        if not re.search(r"^apps:[ \t]*(#.*)?$", text, re.M):
            raise GenError("registry/apps.yaml: cannot find a top-level 'apps:' key")
        text = text.rstrip("\n") + "\n" + entry
    registry.write_text(text, encoding="utf-8")


# ---------------------------------------------------------------- generation
def _ignore(src_dir: str, names: list[str]) -> set[str]:
    ignored = set()
    in_android = Path(src_dir).name == "android"
    for n in names:
        if n in EXCLUDE_DIRS and (Path(src_dir) / n).is_dir():
            ignored.add(n)
        elif n.endswith(EXCLUDE_SUFFIXES):
            ignored.add(n)
        elif in_android and n in EXCLUDE_FILES:
            ignored.add(n)
    return ignored


def _sub_file(path: Path, pattern: str, repl: str, count: int = 0, flags: int = 0) -> None:
    text = path.read_text(encoding="utf-8")
    new, n = re.subn(pattern, lambda _m: repl, text, count=count, flags=flags)
    if n == 0:
        raise GenError(f"generator bug: pattern {pattern!r} not found in {path}")
    path.write_text(new, encoding="utf-8")


def rewrite_config(out: Path, game_id: str, name: str, package: str, color: str) -> None:
    cfg = out / "app.config.yaml"
    _sub_file(cfg, r"^(  id:).*$", f"  id: {game_id}", 1, re.M)
    _sub_file(cfg, r"^(  display_name:).*$", f'  display_name: "{name}"', 1, re.M)
    _sub_file(cfg, r"^(  package_name:).*$", f"  package_name: {package}", 1, re.M)
    _sub_file(cfg, r"^(  seed_color:).*$", f'  seed_color: "{color.upper()}"', 1, re.M)


def rewrite_dart_package(out: Path, game_id: str) -> None:
    _sub_file(out / "pubspec.yaml", r"^name:.*$", f"name: {game_id}", 1, re.M)
    _sub_file(
        out / "pubspec.yaml",
        r'^description:.*$',
        f'description: "{game_id} (generated from the game-factory Flutter + Flame template)."',
        1,
        re.M,
    )
    for sub in ("lib", "test", "integration_test"):
        for f in (out / sub).rglob("*.dart"):
            text = f.read_text(encoding="utf-8")
            new = text.replace(f"package:{TEMPLATE_PKG}/", f"package:{game_id}/")
            if new != text:
                f.write_text(new, encoding="utf-8")


def rewrite_android(out: Path, package: str) -> None:
    _sub_file(
        out / "android" / "app" / "build.gradle.kts",
        r'namespace\s*=\s*"[^"]*"',
        f'namespace = "{package}"',
        1,
    )
    kotlin_root = out / "android" / "app" / "src" / "main" / "kotlin"
    old_dir = kotlin_root / "com" / "example" / TEMPLATE_PKG
    activity = old_dir / "MainActivity.kt"
    if not activity.is_file():
        raise GenError(f"generator bug: {activity} missing in template copy")
    text = activity.read_text(encoding="utf-8")
    text = re.sub(r"^package\s+\S+", f"package {package}", text, count=1, flags=re.M)
    new_dir = kotlin_root.joinpath(*package.split("."))
    new_dir.mkdir(parents=True, exist_ok=True)
    (new_dir / "MainActivity.kt").write_text(text, encoding="utf-8")
    if old_dir.resolve() != new_dir.resolve():
        activity.unlink()
    # prune now-empty template directories (com/example/flutter_game_template, com/example, com)
    d = old_dir
    while d != kotlin_root and d.is_dir() and not any(d.iterdir()):
        d.rmdir()
        d = d.parent


def move_workflows(out: Path) -> None:
    # Template workflows already assume the repo root is the Flutter project, so they
    # live in the template root's .github/workflows and stay at <out>/.github/workflows.
    wf = out / ".github" / "workflows"
    if not wf.is_dir():
        raise GenError("generator bug: template has no .github/workflows")


def leftover_template_refs(out: Path) -> list[str]:
    hits = []
    for f in out.rglob("*"):
        if f.is_file() and ".git" not in f.relative_to(out).parts:
            try:
                if TEMPLATE_PKG in f.read_text(encoding="utf-8"):
                    hits.append(str(f.relative_to(out)))
            except (UnicodeDecodeError, OSError):
                continue
    for p in out.rglob("*"):
        if TEMPLATE_PKG in p.name:
            hits.append(str(p.relative_to(out)))
    return hits


def generate(
    game_id: str,
    name: str,
    package: str,
    color: str,
    out: Path,
    do_register: bool = False,
    template: Path = TEMPLATE_DIR,
    registry: Path = REGISTRY_FILE,
) -> Path:
    validate_id(game_id)
    validate_name(name)
    validate_package(package)
    validate_color(color)
    if not template.is_dir():
        raise GenError(f"template not found: {template}")
    if out.exists() and (not out.is_dir() or any(out.iterdir())):
        raise GenError(f"refusing to overwrite non-empty or non-directory --out: {out}")
    if do_register:
        check_registry(registry, game_id, package)

    shutil.copytree(template, out, ignore=_ignore, dirs_exist_ok=True)
    rewrite_config(out, game_id, name, package, color)
    rewrite_dart_package(out, game_id)
    rewrite_android(out, package)
    move_workflows(out)
    left = leftover_template_refs(out)
    if left:
        raise GenError(f"leftover '{TEMPLATE_PKG}' references in: {', '.join(sorted(set(left)))}")
    if do_register:
        register(registry, game_id, package)
    return out


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Generate a new game project from the template.")
    p.add_argument("--id", required=True, dest="game_id", help="snake_case game id")
    p.add_argument("--name", required=True, help="display name")
    p.add_argument("--package", required=True, help="Android package, e.g. com.yaspark.mygame")
    p.add_argument("--seed-color", required=True, help="theme seed color, #RRGGBB")
    p.add_argument("--out", required=True, type=Path, help="output dir (must be empty/new)")
    p.add_argument("--register", action="store_true", help="append to registry/apps.yaml")
    args = p.parse_args(argv)
    try:
        out = generate(
            args.game_id, args.name, args.package, args.seed_color, args.out, args.register
        )
    except GenError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(f"Generated {args.game_id} at {out}")
    if args.register:
        print(f"Registered in {REGISTRY_FILE}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
