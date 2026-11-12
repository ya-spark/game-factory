#!/usr/bin/env python3
"""Generate a new game project from template/flutter-game-template.

Usage:
  python3 scripts/new_game.py --id my_game --name "My Game" \
      --package com.yaspark.mygame --seed-color "#RRGGBB" --out <dir> [--register] \
      [--profile puzzle|craft|mind] [--audience child|teen|adult] [--ci on|off] [--repo owner/name] \
      [--design <design app_id>]

Python 3 standard library only. Never writes secrets: admob.release and play_games values
stay PLACEHOLDER_* (they are only filled in later by the release config / CI secrets).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
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


def register(registry: Path, game_id: str, package: str, repo: str | None = None) -> None:
    check_registry(registry, game_id, package)
    repo = repo or f"ya-spark/game-{kebab(game_id)}"
    text = registry.read_text(encoding="utf-8")
    entry = (
        f"  - id: {game_id}\n"
        f"    repo: {repo}\n"
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
    # design/ holds all five apps' files; a game gets only its own, copied by apply_design.
    if "design" in names and (Path(src_dir) / "pubspec.yaml").is_file():
        ignored.add("design")
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
    for sub in ("lib", "test", "integration_test", "tool"):
        if not (out / sub).is_dir():
            continue
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


def rewrite_web(out: Path, name: str) -> None:
    """Puts the game name in the web page title and manifest (the web copy, web/)."""
    web = out / "web"
    if not web.is_dir():
        return
    esc = name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
    for fn in ("index.html", "manifest.json"):
        f = web / fn
        text = f.read_text(encoding="utf-8")
        f.write_text(text.replace("Block Puzzle", name if fn == "manifest.json" else esc), encoding="utf-8")


def move_workflows(out: Path) -> None:
    # Template workflows already assume the repo root is the Flutter project, so they
    # live in the template root's .github/workflows and stay at <out>/.github/workflows.
    wf = out / ".github" / "workflows"
    if not wf.is_dir():
        raise GenError("generator bug: template has no .github/workflows")


def rewrite_docs(out: Path, name: str) -> None:
    """Puts the game name in the heading of docs/SPEC.md (filled in by the spec agent)."""
    _sub_file(out / "docs" / "SPEC.md", r"^# Game spec$", f"# {name}: game spec", 1, re.M)


PROFILES = ("puzzle", "craft", "mind")
AUDIENCES = ("child", "teen", "adult")
REPO_RE = re.compile(r"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$")

# Block Puzzle files removed for the craft and mind profiles (no puzzle game in those apps).
# lib/game/tips.dart and lib/ui/share_card.dart stay: tip_service and the challenges screen use them.
PUZZLE_ONLY_PATHS = (
    "lib/game/flame",
    "lib/game/rules",
    "lib/game/layout.dart",
    "lib/ui/game_screen.dart",
    "lib/ui/game_over_panel.dart",
    "test/game",
    "test/helpers/puzzle_bot.dart",
    "test/ui/game_over_centre_test.dart",
    "test/ui/game_over_panel_test.dart",
    "test/ui/screens_test.dart",
    "test/ui/share_tips_ui_test.dart",
    "integration_test/block_puzzle_bot_test.dart",
)
PUZZLE_ONLY_FILES = (
    "lib/ui/game_over_panel.dart",
    "lib/game/flame/special_overlay.dart",
)
PUZZLE_ONLY_TEST_IDS = (
    "game.over.panel", "game.over.view", "game.over.share", "game.over.revive", "game.rush",
)
CI_GUARD = "${{ vars.CI_ENABLED == 'true' }}"
CI_GUARD_DISPATCH = "${{ vars.CI_ENABLED == 'true' && github.event_name == 'workflow_dispatch' }}"

# What every generated game must carry from the template's features.
REQUIRED_FILES = (
    "lib/core/audio/audio_service.dart",
    "lib/core/audio/voice_arbiter.dart",
    "lib/core/share/share_service.dart",
    "lib/core/tips/tip_service.dart",
    "lib/core/purchase/parent_gate_guard.dart",
    "lib/ui/share_card.dart",
    "lib/ui/tip_dialog.dart",
    "lib/ui/game_over_panel.dart",
    "lib/game/flame/special_overlay.dart",
    "lib/ui/parent_gate.dart",
    "lib/ui/shop_screen.dart",
    "assets/ambience/night.mp3",
)
REQUIRED_TEST_IDS = (
    "game.over.panel", "game.over.view", "game.over.share", "game.over.revive",
    "game.rush",
    "gate.dialog", "gate.answer", "gate.submit", "gate.cancel",
    "settings.volume", "settings.ambience", "settings.voice", "settings.hand",
    "settings.tips", "settings.shareApp", "tip.home", "tip.close", "tip.dontShow",
)
REQUIRED_PRODUCTS = ("remove_ads_all", "coins_500", "coins_1500", "coins_4000")


def check_features(out: Path, profile: str = "puzzle") -> None:
    """Fails (generator bug) when the copy misses a template feature."""
    puzzle = profile == "puzzle"
    files = [f for f in REQUIRED_FILES if puzzle or f not in PUZZLE_ONLY_FILES]
    missing = [f for f in files if not (out / f).is_file()]
    ids = (out / "lib" / "ui" / "test_ids.dart").read_text(encoding="utf-8")
    test_ids = [t for t in REQUIRED_TEST_IDS if puzzle or t not in PUZZLE_ONLY_TEST_IDS]
    missing += [f"test id {t}" for t in test_ids if f"'{t}'" not in ids]
    if not puzzle:
        missing += [f"{p} (must be removed)" for p in PUZZLE_ONLY_PATHS if (out / p).exists()]
        home = (out / "lib/ui/home_screen.dart").read_text(encoding="utf-8")
        if "game_screen.dart" in home:
            missing.append("home_screen.dart still imports game_screen.dart")
    products = (out / "products.yaml").read_text(encoding="utf-8")
    missing += [f"product {p}" for p in REQUIRED_PRODUCTS if f"id: {p}\n" not in products]
    cfg = (out / "app.config.yaml").read_text(encoding="utf-8")
    if not re.search(r"^share:\s*$", cfg, re.M):
        missing.append("app.config.yaml share: key")
    manifest = (out / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    if 'permission.AD_ID" tools:node="remove"' not in manifest:
        missing.append("AndroidManifest AD_ID removal")
    release = (out / ".github/workflows/release.yml").read_text(encoding="utf-8")
    if "Report whether the bundle asks for the advertising ID" not in release:
        missing.append("release.yml AD_ID report step")
    if missing:
        raise GenError(f"generator bug: template feature missing in the copy: {missing}")


def strip_puzzle(out: Path) -> None:
    """Removes the Block Puzzle game and gives Home a hub placeholder (craft, mind)."""
    for rel in PUZZLE_ONLY_PATHS:
        path = out / rel
        if path.is_dir():
            shutil.rmtree(path)
        elif path.is_file():
            path.unlink()
        else:
            raise GenError(f"generator bug: {rel} missing in template copy")
    home = out / "lib" / "ui" / "home_screen.dart"
    _sub_file(home, r"^import 'game_screen\.dart';\n", "", 1, re.M)
    _sub_file(
        home,
        r"MenuButton\(\s*key: TestIds\.homePlay,.*?onPressed: \(\) => _open\(const GameScreen\(\)\),\s*\),",
        "Text(\n"
        "                            'Your games will appear here.',\n"
        "                            key: TestIds.homeHub,\n"
        "                            textAlign: TextAlign.center,\n"
        "                          ),",
        1,
        re.S,
    )
    # Tests that wait for Home use the hub marker instead of the Play button.
    for rel in ("test/ui/more_games_test.dart", "test/ui/parent_area_test.dart"):
        f = out / rel
        f.write_text(
            f.read_text(encoding="utf-8").replace("TestIds.homePlay", "TestIds.homeHub"),
            encoding="utf-8",
        )
    ids = out / "lib" / "ui" / "test_ids.dart"
    text = ids.read_text(encoding="utf-8")
    anchor = "  static const homePlay = Key('home.play');\n"
    if anchor not in text:
        raise GenError("generator bug: homePlay test id not found")
    ids.write_text(
        text.replace(anchor, anchor + "  static const homeHub = Key('home.hub');\n", 1),
        encoding="utf-8",
    )


def _set_key(path: Path, section: str | None, key: str, value: str) -> None:
    """Sets `key: value` (keeping any trailing comment) at top level or one level down."""
    indent = "  " if section else ""
    pat = re.compile(rf"^({indent}{re.escape(key)}:)[ \t]*[^\s#][^#\n]*?([ \t]*(#.*)?)$")
    lines = path.read_text(encoding="utf-8").split("\n")
    in_sec = section is None
    for i, line in enumerate(lines):
        if section is not None and re.match(r"^[^ #\n]", line):
            in_sec = line.startswith(f"{section}:")
            continue
        m = pat.match(line)
        if in_sec and m:
            lines[i] = f"{m.group(1)} {value}{m.group(2)}"
            path.write_text("\n".join(lines), encoding="utf-8")
            return
    raise GenError(f"generator bug: key {section}.{key} not found in {path}")


def apply_profile_config(out: Path, profile: str, audience: str) -> None:
    cfg = out / "app.config.yaml"
    _set_key(cfg, None, "audience", audience)
    if profile == "puzzle":
        return
    directed = "true" if audience in ("child", "teen") else "false"
    _set_key(cfg, "ads", "child_directed", directed)
    _set_key(cfg, "ads", "max_ad_content_rating", "G" if audience == "child" else "PG")
    if audience in ("child", "teen"):
        _set_key(cfg, "ads", "rewarded_enabled", "false")
    # Only the learning (craft) profile has child profiles and a picker; hubs go straight to the shell.
    if profile == "craft":
        _set_key(cfg, "content", "enabled", "true")
    if profile == "mind":
        _set_key(cfg, "minigames", "coin_price", "300")
        text = cfg.read_text(encoding="utf-8")
        new, n = re.subn(r"(  stars:\n    enabled:) true", r"\1 false", text, count=1)
        if n == 0:
            raise GenError("generator bug: rewards.stars.enabled not found")
        cfg.write_text(new, encoding="utf-8")


def apply_ci_guard(out: Path, ci: str) -> None:
    """With --ci off the generated ci.yml only runs when the CI_ENABLED variable is 'true'."""
    if ci == "on":
        return
    wf = out / ".github" / "workflows" / "ci.yml"
    text = wf.read_text(encoding="utf-8")
    text, n = re.subn(
        r"^(  check:\n    name: [^\n]*\n)", lambda m: m.group(1) + f"    if: {CI_GUARD}\n", text, count=1, flags=re.M
    )
    if n == 0:
        raise GenError("generator bug: ci.yml check job not found")
    wf.write_text(text, encoding="utf-8")
    _sub_file(
        wf,
        r"^    if: github\.event_name == 'workflow_dispatch'$",
        "    if: " + CI_GUARD_DISPATCH,
        1,
        re.M,
    )


def write_engine_lock(out: Path) -> None:
    """Writes engine.lock from the copy's own engine files (see scripts/engine_lock.py)."""
    spec = importlib.util.spec_from_file_location(
        "engine_lock", out / "scripts" / "engine_lock.py"
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.write_lock(out)


def leftover_template_refs(out: Path) -> list[str]:
    hits = []
    for f in out.rglob("*"):
        rel = f.relative_to(out)
        # engine_lock.py names the template package on purpose: it normalises imports with it.
        if rel.as_posix() == "scripts/engine_lock.py":
            continue
        if f.is_file() and ".git" not in rel.parts:
            try:
                if TEMPLATE_PKG in f.read_text(encoding="utf-8"):
                    hits.append(str(f.relative_to(out)))
            except (UnicodeDecodeError, OSError):
                continue
    for p in out.rglob("*"):
        if TEMPLATE_PKG in p.name:
            hits.append(str(p.relative_to(out)))
    return hits


FONT_LICENSE = {
    "Nunito": ("OFL-Nunito.txt", "https://github.com/googlefonts/nunito"),
    "Plus Jakarta Sans": ("OFL-PlusJakartaSans.txt", "https://github.com/tokotype/PlusJakartaSans"),
}
STUDIO_ORIGINAL = "Written by the studio (design phase, game-factory design/)"
FONT_WEIGHTS = {"Regular": 400, "Bold": 700, "ExtraBold": 800}


# A craft or mind game always gets a design; when its id is not one of the five apps (a sample game,
# a new app) the profile and audience pick the default look.
DEFAULT_DESIGN = {
    ("craft", "child"): "craft_lowteen",
    ("craft", "teen"): "craft_highteen",
    ("mind", "adult"): "mind_1",
}
# Tests that read the design files; a game without a design (plain puzzle) does not carry them.
DESIGN_TESTS = (
    "test/ui/theme/design_theme_test.dart",
    "test/ui/kit/kit_test.dart",
    "test/ui/themed_screens_test.dart",
)


def drop_design_tests(out: Path) -> None:
    for rel in DESIGN_TESTS:
        path = out / rel
        if path.is_file():
            path.unlink()
    # Any other test that borrows the design helpers (imports kit_test.dart) goes too.
    for path in sorted((out / "test").rglob("*_test.dart")):
        if "kit/kit_test.dart" in path.read_text(encoding="utf-8"):
            path.unlink()
    for d in (out / "test/ui/theme", out / "test/ui/kit"):
        if d.is_dir() and not any(d.iterdir()):
            d.rmdir()


def design_ids(template: Path) -> list[str]:
    d = template / "design"
    if not d.is_dir():
        return []
    return sorted(p.name for p in d.iterdir() if (p / "tokens.json").is_file())


def apply_design(out: Path, template: Path, design_id: str) -> None:
    """Copy only this game's design files into assets/, wire pubspec, LICENSES and app.config."""
    src = template / "design"
    if design_id not in design_ids(template):
        raise GenError(f"unknown --design {design_id!r}: one of {', '.join(design_ids(template))}")
    tokens = json.loads((src / design_id / "tokens.json").read_text(encoding="utf-8"))
    font = tokens["font"]
    rows: list[tuple[str, str, str, str]] = []  # path, source, license, notes
    dest = out / "assets" / "design"
    (dest / design_id).mkdir(parents=True, exist_ok=True)
    shutil.copy2(src / "tokens.json", dest / "tokens.json")
    rows.append(("assets/design/tokens.json", STUDIO_ORIGINAL, "original", "shared design tokens"))
    shutil.copy2(src / design_id / "tokens.json", dest / design_id / "tokens.json")
    rows.append((f"assets/design/{design_id}/tokens.json", STUDIO_ORIGINAL, "original",
                 "this app's colours and radii"))
    art = src / design_id / "art"
    if art.is_dir():
        shutil.copytree(art, dest / design_id / "art")
        for f in sorted(art.iterdir()):
            kind = "mascot (a friendly shape, no human figure)" if f.name.startswith("mascot") else "hero scene"
            rows.append((f"assets/design/{design_id}/art/{f.name}", STUDIO_ORIGINAL, "original", f"{kind}; SVG"))
    (dest / "icons").mkdir(exist_ok=True)
    for f in sorted((src / "icons").glob("*.svg")):
        shutil.copy2(f, dest / "icons" / f.name)
        rows.append((f"assets/design/icons/{f.name}", STUDIO_ORIGINAL, "original", "24 x 24 icon, currentColor"))
    fonts = out / "assets" / "fonts"
    fonts.mkdir(parents=True, exist_ok=True)
    lic_file, url = FONT_LICENSE[font["family"]]
    for name in [*font["files"], lic_file]:
        shutil.copy2(src / "fonts" / name, fonts / name)
        what = f"{font['family']} font" if name.endswith(".ttf") else f"{font['family']} licence text"
        rows.append((f"assets/fonts/{name}", url, "SIL OFL 1.1", what))
    lic = out / "assets" / "LICENSES.md"
    text = lic.read_text(encoding="utf-8").rstrip("\n") + "\n\n"
    text += "".join(f"| {a} | {b} | {c} | {d} |\n" for a, b, c, d in rows)
    lic.write_text(text, encoding="utf-8")

    dirs = ["assets/design/", f"assets/design/{design_id}/", "assets/design/icons/"]
    if art.is_dir():
        dirs.insert(2, f"assets/design/{design_id}/art/")
    pub = out / "pubspec.yaml"
    ptext = pub.read_text(encoding="utf-8")
    marker = "    - assets/content/\n"
    if marker not in ptext:
        raise GenError("generator bug: assets/content/ entry not found in pubspec.yaml")
    ptext = ptext.replace(marker, marker + "".join(f"    - {d}\n" for d in dirs), 1)
    if len(font["files"]) == 1:
        entries = f"        - asset: assets/fonts/{font['files'][0]}\n"
    else:
        entries = "".join(
            f"        - asset: assets/fonts/{f}\n          weight: {FONT_WEIGHTS[Path(f).stem.split('-')[1]]}\n"
            for f in font["files"]
        )
    ptext = ptext.rstrip("\n") + f"\n  fonts:\n    - family: {font['family']}\n      fonts:\n{entries}"
    pub.write_text(ptext, encoding="utf-8")
    _sub_file(out / "app.config.yaml", r"^  # design:.*$", f"  design: {design_id}", 1, re.M)


def generate(
    game_id: str,
    name: str,
    package: str,
    color: str,
    out: Path,
    do_register: bool = False,
    template: Path = TEMPLATE_DIR,
    registry: Path = REGISTRY_FILE,
    profile: str = "puzzle",
    audience: str | None = None,
    ci: str = "off",
    repo: str | None = None,
    design: str | None = None,
) -> Path:
    if profile not in PROFILES:
        raise GenError(f"invalid --profile {profile!r}: one of {', '.join(PROFILES)}")
    if audience is None:
        audience = {"puzzle": "adult", "craft": "child", "mind": "adult"}[profile]
    if audience not in AUDIENCES:
        raise GenError(f"invalid --audience {audience!r}: one of {', '.join(AUDIENCES)}")
    allowed = {"puzzle": AUDIENCES, "craft": ("child", "teen"), "mind": ("adult",)}[profile]
    if audience not in allowed:
        raise GenError(f"--profile {profile} needs --audience {' or '.join(allowed)}")
    if ci not in ("on", "off"):
        raise GenError(f"invalid --ci {ci!r}: on or off")
    if repo is not None and not REPO_RE.match(repo):
        raise GenError(f"invalid --repo {repo!r}: expected owner/name")
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
    rewrite_web(out, name)
    move_workflows(out)
    rewrite_docs(out, name)
    if profile != "puzzle":
        strip_puzzle(out)
    apply_profile_config(out, profile, audience)
    # Design: explicit --design, else the game id when it names one of the five apps (craft and
    # mind profiles only). The plain puzzle profile keeps today's look unless --design is given.
    if design is None and profile != "puzzle":
        if game_id in design_ids(template):
            design = game_id
        else:
            design = DEFAULT_DESIGN[(profile, audience if profile == "craft" else "adult")]
    if design is not None:
        apply_design(out, template, design)
    else:
        drop_design_tests(out)
    apply_ci_guard(out, ci)
    check_features(out, profile)
    write_engine_lock(out)
    left = leftover_template_refs(out)
    if left:
        raise GenError(f"leftover '{TEMPLATE_PKG}' references in: {', '.join(sorted(set(left)))}")
    if do_register:
        register(registry, game_id, package, repo)
    return out


def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(description="Generate a new game project from the template.")
    p.add_argument("--id", required=True, dest="game_id", help="snake_case game id")
    p.add_argument("--name", required=True, help="display name")
    p.add_argument("--package", required=True, help="Android package, e.g. com.yaspark.mygame")
    p.add_argument("--seed-color", required=True, help="theme seed color, #RRGGBB")
    p.add_argument("--out", required=True, type=Path, help="output dir (must be empty/new)")
    p.add_argument("--register", action="store_true", help="append to registry/apps.yaml")
    p.add_argument("--profile", default="puzzle", choices=PROFILES,
                   help="puzzle (default: the Block Puzzle game), craft or mind (no puzzle game)")
    p.add_argument("--audience", choices=AUDIENCES,
                   help="compliance profile; craft: child or teen, mind: adult")
    p.add_argument("--ci", default="off", choices=("on", "off"),
                   help="off (default): ci.yml runs only when repo variable CI_ENABLED is 'true'")
    p.add_argument("--design", help="design app_id (craft_lowteen, mind_1, ...); default: the game id "
                   "when it names one of the five apps (craft and mind profiles)")
    p.add_argument("--repo", help="owner/name for the registry (default ya-spark/game-<kebab-id>)")
    args = p.parse_args(argv)
    try:
        out = generate(
            args.game_id, args.name, args.package, args.seed_color, args.out, args.register,
            profile=args.profile, audience=args.audience, ci=args.ci, repo=args.repo,
            design=args.design,
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
