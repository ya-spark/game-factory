#!/usr/bin/env python3
"""Generate a new container app from template/flutter-game-template (the shell: services, theme,
shop, settings, CI, store files). Games are not copied in: they are packages in games/<id>/ that
the app pins by git (--games), and the engine is game_core.

Usage:
  python3 scripts/new_game.py --id my_game --name "My Game" \
      --package com.yaspark.mygame --seed-color "#RRGGBB" --out <dir> [--register] \
      [--profile puzzle|craft|mind] [--audience child|teen|adult] [--ci on|off] [--repo owner/name] \
      [--design <design app_id>] [--games game_a,game_b] [--ref <game-factory commit>]

Python 3 standard library only. Never writes secrets: admob.release and play_games values
stay PLACEHOLDER_* (they are only filled in later by the release config / CI secrets).
"""

from __future__ import annotations

import argparse
import importlib.util
import json
import re
import shutil
import subprocess
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
        f'description: "{game_id} (generated from the game-factory container template)."',
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


def rewrite_web(out: Path) -> None:
    """Writes the web shell (page title, description, social tags, loading screen, manifest) from
    the game's app.config.yaml with scripts/web_shell.py (the copy in the game). Call after rewrite_config."""
    if not (out / "web").is_dir():
        return
    spec = importlib.util.spec_from_file_location("web_shell", out / "scripts" / "web_shell.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    mod.write_shell(out)


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

CI_GUARD = "${{ vars.CI_ENABLED == 'true' }}"

# What every generated game must carry from the template's features.
REQUIRED_FILES = (
    "lib/core/share/share_service.dart",
    "lib/core/tips/tip_service.dart",
    "lib/core/purchase/parent_gate_guard.dart",
    "lib/ui/share_card.dart",
    "lib/ui/tip_dialog.dart",
    "lib/ui/parent_gate.dart",
    "lib/ui/shop_screen.dart",
)
REQUIRED_TEST_IDS = (
    "gate.dialog", "gate.answer", "gate.submit", "gate.cancel",
    "settings.volume", "settings.ambience", "settings.voice", "settings.hand",
    "settings.tips", "settings.shareApp", "tip.home", "tip.close", "tip.dontShow",
)
REQUIRED_PRODUCTS = ("remove_ads_all", "coins_500", "coins_1500", "coins_4000")


def check_features(out: Path, profile: str = "puzzle") -> None:
    """Fails (generator bug) when the copy misses a template feature."""
    missing = [f for f in REQUIRED_FILES if not (out / f).is_file()]
    ids = (out / "lib" / "ui" / "test_ids.dart").read_text(encoding="utf-8")
    missing += [f"test id {t}" for t in REQUIRED_TEST_IDS if f"'{t}'" not in ids]
    products = (out / "products.yaml").read_text(encoding="utf-8")
    missing += [f"product {p}" for p in REQUIRED_PRODUCTS if f"id: {p}\n" not in products]
    cfg = (out / "app.config.yaml").read_text(encoding="utf-8")
    if not re.search(r"^share:\s*$", cfg, re.M):
        missing.append("app.config.yaml share: key")
    manifest = (out / "android/app/src/main/AndroidManifest.xml").read_text(encoding="utf-8")
    if 'permission.AD_ID" tools:node="remove"' not in manifest:
        missing.append("AndroidManifest AD_ID removal")
    # The release steps live in one shared workflow in this repo; the copy only holds a thin caller.
    caller = (out / ".github/workflows/release-to-closed-testing.yml").read_text(encoding="utf-8")
    if "shared-release-to-closed-testing.yml" not in caller:
        missing.append("release-to-closed-testing.yml must call the shared release workflow")
    shared = (REPO_ROOT / ".github/workflows/shared-release-to-closed-testing.yml").read_text(encoding="utf-8")
    if "Report whether the bundle asks for the advertising ID" not in shared:
        missing.append("shared release workflow AD_ID report step")
    if missing:
        raise GenError(f"generator bug: template feature missing in the copy: {missing}")


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
    # X2b: the AdSense Tag for Age Treatment follows the audience (child, teen; adult = none).
    _set_key(cfg, "adsense", "age_treatment", {"child": "child", "teen": "teen"}.get(audience, "none"))
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
        # C4: goals and reminders are set in the Parent area; Scout and Ranger (child) have no
        # reminder row in Settings, Champion (teen) keeps one.
        _set_key(cfg, "goals_reminders", "parent_area", "true")
        _set_key(cfg, "goals_reminders", "settings_row", "false" if audience == "child" else "true")
        # C7: exam practice in Study mode only for the teen app (Champion).
        _set_key(cfg, "exam_practice", "enabled", "true" if audience == "teen" else "false")
    if profile == "mind":
        _set_key(cfg, "minigames", "coin_price", "300")
        # M2: per-game stats, the Stats page and the "New personal best" message.
        _set_key(cfg, "game_stats", "enabled", "true")
        text = cfg.read_text(encoding="utf-8")
        new, n = re.subn(r"(  stars:\n    enabled:) true", r"\1 false", text, count=1)
        if n == 0:
            raise GenError("generator bug: rewards.stars.enabled not found")
        cfg.write_text(new, encoding="utf-8")


def apply_content_packs(out: Path) -> None:
    """Craft apps bundle packs from assets/content/packs/: list the folder in pubspec.yaml (Flutter
    does not look into sub-folders) and create it so the build works before the first pack."""
    pubspec = out / "pubspec.yaml"
    text = pubspec.read_text(encoding="utf-8")
    marker = "    - assets/content/\n"
    line = "    - assets/content/packs/\n"
    if marker not in text:
        raise GenError("generator bug: assets/content/ entry not found in pubspec.yaml")
    if line not in text:
        pubspec.write_text(text.replace(marker, marker + line, 1), encoding="utf-8")
    packs = out / "assets" / "content" / "packs"
    packs.mkdir(parents=True, exist_ok=True)
    keep = packs / ".gitkeep"
    if not any(packs.iterdir()):
        keep.write_text("", encoding="utf-8")
        lic = out / "assets" / "LICENSES.md"
        row = ("| assets/content/packs/.gitkeep | Written by the studio | original "
               "| empty placeholder so the packs folder exists before the first pack |\n")
        text = lic.read_text(encoding="utf-8")
        if row not in text:
            lic.write_text(text.rstrip("\n") + "\n" + row, encoding="utf-8")


def apply_ci_guard(out: Path, ci: str) -> None:
    """With --ci off the generated check-code.yml only runs when the CI_ENABLED variable is 'true'."""
    if ci == "on":
        return
    wf = out / ".github" / "workflows" / "check-code.yml"
    text = wf.read_text(encoding="utf-8")
    text, n = re.subn(
        r"^(  check:\n    name: [^\n]*\n)", lambda m: m.group(1) + f"    if: {CI_GUARD}\n", text, count=1, flags=re.M
    )
    if n == 0:
        raise GenError("generator bug: check-code.yml check job not found")
    wf.write_text(text, encoding="utf-8")


def leftover_template_refs(out: Path) -> list[str]:
    hits = []
    for f in out.rglob("*"):
        rel = f.relative_to(out)
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


GAMES_DIR = REPO_ROOT / "games"
FACTORY_URL = "https://github.com/ya-spark/game-factory.git"
# The shell's Study mode and mistakes round use Flash review, so every container lists it.
ALWAYS_GAMES = ("flash_review",)
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


def camel(game_id: str) -> str:
    head, *rest = game_id.split("_")
    return head + "".join(w.capitalize() for w in rest)


def game_entry_name(game_id: str, games_dir: Path = GAMES_DIR) -> str | None:
    """The `<id>Game` MiniGame a quiz game package exports, or None when it has none (an arcade game)."""
    name = f"{camel(game_id)}Game"
    for f in (games_dir / game_id / "lib").rglob("*.dart"):
        if re.search(rf"^(?:final|const)\s+[\w<>]*\s*{name}\b|^MiniGame\s+{name}\b", f.read_text(encoding="utf-8"), re.M):
            return name
    return None


ADAPTERS_DIR = REPO_ROOT / "scripts" / "arcade_adapters"
# Games that are not quiz MiniGames. `host` games (Wingy, Block Puzzle, Blockfall) need services from their
# container: `scripts/arcade_adapters/<id>/` holds the adapter (profile, ads, services, host widget) written
# into `lib/host/<id>/`. The others are plain screens that only need the `GameHost` the app provides.
# Fields: registry id, title, Pascal class, access, coin price, star scores, widget (None: `<Class>Screen`).
ARCADE: dict[str, dict] = {
    "wingy": dict(rid="wingy", title="Wingy", cls="Wingy", access="freeWithAds", stars="const [10, 25, 50]", host=True),
    "block_puzzle": dict(rid="block_puzzle", title="Block Puzzle", cls="BlockPuzzle", access="freeWithAds",
                         stars="const [500, 2000, 5000]", host=True),
    "blockfall": dict(rid="blockfall", title="Blockfall", cls="Blockfall", access="coins", coin=300,
                      stars="const [1000, 5000, 15000]", host=True),
    "snake": dict(rid="snake", title="Snake", cls="Snake", access="freeWithAds", stars="snakeStarScores"),
    "brick_breaker": dict(rid="bricks", title="Brick breaker", cls="BrickBreaker", access="freeWithAds",
                          stars="brickStarScores"),
    "stack_tower": dict(rid="stack", title="Stack tower", cls="StackTower", access="coins", coin=300,
                        stars="stackStarScores"),
    "runner": dict(rid="runner", title="Runner", cls="Runner", access="coins", coin=300, stars="runnerStarScores"),
    "sudoku": dict(rid="sudoku", title="Sudoku", cls="Sudoku", access="freeWithAds", stars="sudokuStarScores"),
    "solitaire": dict(rid="solitaire", title="Solitaire", cls="Solitaire", access="freeWithAds",
                      stars="solitaireStarScores"),
    "ball_sort": dict(rid="ball_sort", title="Ball sort", cls="BallSort", access="coins", coin=300,
                      stars="ballSortStarScores"),
    "mahjong": dict(rid="mahjong", title="Mahjong solitaire", cls="Mahjong", access=None, stars="mahjongStarScores"),
    "merge": dict(rid="merge", title="Merge", cls="Merge", access="coins", coin=300, stars="mergeStarScores"),
}


def arcade_entry(game_id: str) -> str:
    """The `RegistryEntry` of an arcade or hub game, as the hubs write it (standalone builder)."""
    a = ARCADE[game_id]
    widget = f"{a['cls']}Host" if a.get("host") else f"{a['cls']}Screen"
    lines = [
        "  RegistryEntry(",
        "    MiniGame(",
        f"      id: '{a['rid']}',",
        f"      title: '{a['title']}',",
        "      itemTypes: const {},",
        "      minPool: 0,",
        "      modes: const {MiniGameMode.game},",
    ]
    if a["access"]:
        lines.append(f"      access: GameAccess.{a['access']},")
    if a.get("coin"):
        lines.append(f"      coinPrice: {a['coin']},")
    lines += [
        f"      starScores: {a['stars']},",
        f"      build: (_) => throw UnsupportedError('{a['title']} is a standalone game'),",
        f"      buildStandalone: (onScore) => {widget}(onScore: onScore),",
        "    ),",
        "  ),",
    ]
    return "\n".join(lines) + "\n"


def write_adapter(out: Path, game_id: str, app_package: str) -> None:
    """Writes lib/host/<id>/ from scripts/arcade_adapters/<id>/ for an app package."""
    src = ADAPTERS_DIR / game_id
    if not src.is_dir():
        raise GenError(f"generator bug: no adapter templates for {game_id} in {src}")
    dest = out / "lib" / "host" / game_id
    dest.mkdir(parents=True, exist_ok=True)
    for f in sorted(src.glob("*.tmpl")):
        text = f.read_text(encoding="utf-8").replace("__APP__", app_package)
        (dest / f.name[: -len(".tmpl")]).write_text(text, encoding="utf-8")


def write_host_smoke_test(out: Path, hosts: list[str], app_package: str) -> None:
    """test/host/arcade_hosts_test.dart: each listed host game opens over the app's fake services."""
    imports = "".join(
        f"import 'package:{app_package}/host/{g}/{g}_host.dart';\n" for g in sorted(hosts)
    )
    cases = "".join(f"    '{g}': () => const {ARCADE[g]['cls']}Host(),\n" for g in hosts)
    text = f"""import 'package:{app_package}/core/services.dart';
{imports}import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_services.dart';

void main() {{
  for (final entry in <String, Widget Function()>{{
{cases}  }}.entries) {{
    testWidgets('${{entry.key}} host opens the game over the app services', (
      tester,
    ) async {{
      SharedPreferences.setMockInitialValues({{}});
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final s = await buildFakeServices();
      await tester.pumpWidget(
        MaterialApp(
          home: ServicesScope(
            services: s,
            child: GameHostScope(host: const NoGameHost(), child: entry.value()),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {{
        await tester.pump(const Duration(milliseconds: 100));
      }}
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    }});
  }}
}}
"""
    f = out / "test" / "host" / "arcade_hosts_test.dart"
    f.parent.mkdir(parents=True, exist_ok=True)
    f.write_text(text, encoding="utf-8")


def parse_games(value: str | None, games_dir: Path = GAMES_DIR) -> list[str]:
    """Game ids for --games: each must be a package in games/ that a container can list."""
    ids = [g for g in (value or "").split(",") if g]
    for g in ids:
        if not ID_RE.match(g) or not (games_dir / g / "pubspec.yaml").is_file():
            known = sorted(d.name for d in games_dir.iterdir() if (d / "pubspec.yaml").is_file()) if games_dir.is_dir() else []
            raise GenError(f"unknown game {g!r} in --games: one of {', '.join(known)}")
        if game_entry_name(g, games_dir) is None and g not in ARCADE:
            raise GenError(f"game {g!r} has no `{camel(g)}Game` and no entry in ARCADE (new_game.py): add one")
    return list(dict.fromkeys([*ALWAYS_GAMES, *ids]))


def factory_head() -> str:
    try:
        return subprocess.run(
            ["git", "-C", str(REPO_ROOT), "rev-parse", "HEAD"], check=True, capture_output=True, text=True
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError) as e:
        raise GenError(f"cannot read the game-factory commit; pass --ref <sha>: {e}")


def _git_dep(name: str, path: str, ref: str) -> str:
    return f"  {name}:\n    git:\n      url: {FACTORY_URL}\n      path: {path}\n      ref: {ref}\n"


def apply_games(out: Path, games: list[str], ref: str, app_package: str, games_dir: Path = GAMES_DIR) -> None:
    """Pins game_core and each game package by git at `ref` (one game-factory commit), and lists
    every game in the registry. The template itself uses path dependencies inside this repo."""
    if not SHA_RE.match(ref):
        raise GenError(f"invalid --ref {ref!r}: a full 40-character commit sha of game-factory main")
    pub = out / "pubspec.yaml"
    text = pub.read_text(encoding="utf-8")
    old_deps = "  game_core:\n    path: ../../game_core\n  game_flash_review:\n    path: ../../games/flash_review\n"
    old_over = "dependency_overrides:\n  game_core:\n    path: ../../game_core\n"
    if old_deps not in text or old_over not in text:
        raise GenError("generator bug: game_core path dependencies not found in pubspec.yaml")
    deps = _git_dep("game_core", "game_core", ref) + "".join(
        _git_dep(f"game_{g}", f"games/{g}", ref) for g in sorted(games)
    )
    text = text.replace(old_deps, deps, 1)
    text = text.replace(old_over, "dependency_overrides:\n" + _git_dep("game_core", "game_core", ref), 1)
    pub.write_text(text, encoding="utf-8")
    reg = out / "lib" / "ui" / "game_registry.dart"
    rtext = reg.read_text(encoding="utf-8")
    # Quiz games import their package; host games import their adapter; screen games import their package.
    imports = "".join(
        f"import 'package:game_{g}/{g}.dart';\n"
        for g in sorted(games)
        if not (g in ARCADE and ARCADE[g].get("host"))
    )
    imports += "".join(
        f"import '../host/{g}/{g}_host.dart';\n" for g in sorted(games) if g in ARCADE and ARCADE[g].get("host")
    )
    entries = "".join(
        arcade_entry(g) if g in ARCADE else f"  RegistryEntry({game_entry_name(g, games_dir)}),\n"
        for g in games
        if g != "flash_review"
    )
    hosts = [g for g in games if g in ARCADE and ARCADE[g].get("host")]
    for g in hosts:
        write_adapter(out, g, app_package)
    if hosts:
        write_host_smoke_test(out, hosts, app_package)
    rtext = rtext.replace("import 'package:game_flash_review/flash_review.dart';\n", imports, 1)
    rtext = rtext.replace("  RegistryEntry(flashReviewGame),\n", "  RegistryEntry(flashReviewGame),\n" + entries, 1)
    reg.write_text(rtext, encoding="utf-8")
    # Line breaks depend on the games listed, so format what was written (when dart is installed).
    if shutil.which("dart"):
        targets = ["lib/ui/game_registry.dart"] + (
            ["lib/host", "test/host"] if (out / "lib" / "host").is_dir() else []
        )
        subprocess.run(["dart", "format", *targets], cwd=out, capture_output=True, check=False)


# Tests written for one app's design (they load its tokens): a generated app keeps them only when
# it ships that design.
DESIGN_SPECIFIC_TESTS = {
    "test/ui/exam_practice_test.dart": "craft_highteen",
    "test/ui/game_stats_ui_test.dart": "mind_1",
}


def drop_other_design_tests(out: Path, design_id: str) -> None:
    for rel, needs in DESIGN_SPECIFIC_TESTS.items():
        path = out / rel
        if needs != design_id and path.is_file():
            path.unlink()


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
    games: str | None = None,
    ref: str | None = None,
    games_dir: Path = GAMES_DIR,
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
    game_ids = parse_games(games, games_dir)
    if ref is None:
        ref = factory_head()
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
    # The tile art source stays with the game so scripts/gen_game_art.py works there too.
    if (template / "design" / "game_art").is_dir():
        shutil.copytree(template / "design" / "game_art", out / "tool" / "game_art", dirs_exist_ok=True)
    rewrite_config(out, game_id, name, package, color)
    rewrite_dart_package(out, game_id)
    rewrite_android(out, package)
    rewrite_web(out)
    move_workflows(out)
    rewrite_docs(out, name)
    apply_games(out, game_ids, ref, game_id, games_dir)
    apply_profile_config(out, profile, audience)
    if profile == "craft":
        apply_content_packs(out)
    # Design: explicit --design, else the game id when it names one of the five apps (craft and
    # mind profiles only). The plain puzzle profile keeps today's look unless --design is given.
    if design is None and profile != "puzzle":
        if game_id in design_ids(template):
            design = game_id
        else:
            design = DEFAULT_DESIGN[(profile, audience if profile == "craft" else "adult")]
    if design is not None:
        apply_design(out, template, design)
        drop_other_design_tests(out, design)
    else:
        drop_design_tests(out)
    apply_ci_guard(out, ci)
    check_features(out, profile)
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
                   help="puzzle (default: plain shell, no design), craft or mind (game-based designs)")
    p.add_argument("--audience", choices=AUDIENCES,
                   help="compliance profile; craft: child or teen, mind: adult")
    p.add_argument("--ci", default="off", choices=("on", "off"),
                   help="off (default): check-code.yml runs only when repo variable CI_ENABLED is 'true'")
    p.add_argument("--design", help="design app_id (craft_lowteen, mind_1, ...); default: the game id "
                   "when it names one of the five apps (craft and mind profiles)")
    p.add_argument("--games", help="comma-separated ids from games/ to list in the app (git-pinned, "
                   "with Flash review always); needs a pushed game-factory commit")
    p.add_argument("--ref", help="game-factory commit sha to pin (default: this checkout's HEAD)")
    p.add_argument("--repo", help="owner/name for the registry (default ya-spark/game-<kebab-id>)")
    args = p.parse_args(argv)
    try:
        out = generate(
            args.game_id, args.name, args.package, args.seed_color, args.out, args.register,
            profile=args.profile, audience=args.audience, ci=args.ci, repo=args.repo,
            design=args.design, games=args.games, ref=args.ref,
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
