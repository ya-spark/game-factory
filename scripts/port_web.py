#!/usr/bin/env python3
"""Ports the web build work (template commit ef7359f) into one generated app.

Usage: python3 scripts/port_web.py <app_dir> --folder <scout|ranger|champion|ember|presto> [--rev ef7359f] [--dry-run]

Why a script: the apps own copies of lib/core and lib/ui (only lib/engine is synced by
sync_engine.py), so the web changes must be carried over by hand. This does it safely:

* New files (lib/core/platform/, web/, scripts/web_smoke.sh, the web
  stub test, ...) are copied when missing; a file that already exists with other content is refused.
* Files the commit modified are replaced by the new template version only when the app's copy is
  byte-identical to the template's version before the commit. A copy that already equals the new
  version is skipped. Anything else is a "diverged" file: it is ported only through the small,
  exact-match edits below (buy call sites, the Play Games row); if an edit does not match, the
  script stops with an error and changes NOTHING in the app.
* Idempotent: a second run reports "up to date".
* Puts the app's display name into web/index.html and web/manifest.json and adds the "Web build on the Hostinger VPS" note to docs/SPEC.md.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

FACTORY = Path(__file__).resolve().parent.parent
PREFIX = "template/flutter-game-template/"
FOLDERS = ("scout", "ranger", "champion", "ember", "presto")

SPEC_HEADING = "## Web build on the Hostinger VPS"
SPEC_NOTE = """
## Web build on the Hostinger VPS

The product stays Android-only. A web copy of the game is built from `main` and deployed by the studio workflow
`deploy-to-vps-as-web` (in `game-studio`, started by hand) to the owner's Hostinger VPS at
`https://activemindcraft.com/appgames/<repo name without game->/`, behind Caddy, which does the access control (the app has no login).
`platforms.web.enabled` stays `false` in `app.config.yaml`.

- Ads, purchases, notifications and Play Games sign-in are not available in the browser. They are
  honest stubs picked by conditional import in `lib/core/platform/`: no ad is shown, purchases say
  "not available in this web version", reminders do nothing, the Play Games row is hidden.
- Progress and settings are kept in the browser (`SharedPreferences`). Downloaded content is kept in
  memory for the session; built-in content ships in the bundle. Content downloads use the browser
  `fetch` over HTTPS and need CORS on the content host; signed-content verification is unchanged.
- Build: `flutter build web --release --base-href /{folder}/` (optionally
  `--dart-define=CONTENT_BASE_URL=https://.../v1/`). Check a build with `bash scripts/web_smoke.sh`.
"""


def git_show(rev: str, path: str) -> bytes | None:
    r = subprocess.run(
        ["git", "-C", str(FACTORY), "show", f"{rev}:{path}"], capture_output=True
    )
    return r.stdout if r.returncode == 0 else None


def changed_files(rev: str) -> list[tuple[str, str]]:
    out = subprocess.run(
        ["git", "-C", str(FACTORY), "diff-tree", "--no-commit-id", "--name-status", "-r", rev],
        capture_output=True, text=True, check=True,
    ).stdout
    res = []
    for line in out.splitlines():
        status, path = line.split("\t", 1)
        if path.startswith(PREFIX):
            res.append((status[0], path))
    return res


class Diverged(Exception):
    pass


def port_buy_sites(text: str) -> str:
    """parent_area_screen.dart: route buy calls through _buy, add the _buy helper."""
    if "_buy(context, s," in text and "Future<void> _buy(" in text:
        return text
    pat = re.compile(r"onPressed: \(\) => s\.purchases\.buy\(([^()]+)\)")
    new, n = pat.subn(r"onPressed: () => _buy(context, s, \1)", text)
    if n == 0:
        raise Diverged("no `onPressed: () => s.purchases.buy(...)` call sites found")
    helper = (
        "  /// A purchase, or the \"not available in this web version\" note where there is no store.\n"
        "  Future<void> _buy(BuildContext context, Services s, String productId) async {\n"
        "    final note = s.purchases.unavailableMessage;\n"
        "    if (note != null) {\n"
        "      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(note)));\n"
        "      return;\n"
        "    }\n"
        "    await s.purchases.buy(productId);\n"
        "  }\n\n"
    )
    anchor = "  Widget _packTile("
    if new.count(anchor) != 1:
        raise Diverged("anchor `Widget _packTile(` not found exactly once")
    return new.replace(anchor, helper + anchor)


def port_play_games_row(text: str) -> str:
    """settings_screen.dart: hide the Play Games row on web."""
    if "playGames.enabled && !kIsWeb" in text:
        return text
    old = "if (s.config.playGames.enabled)"
    if text.count(old) != 1:
        raise Diverged("`if (s.config.playGames.enabled)` not found exactly once")
    if "package:flutter/foundation.dart" not in text:
        raise Diverged("settings_screen.dart does not import flutter/foundation.dart")
    return text.replace(old, "if (s.config.playGames.enabled && !kIsWeb)")


EDITS = {
    PREFIX + "lib/ui/parent_area_screen.dart": port_buy_sites,
    PREFIX + "lib/ui/settings_screen.dart": port_play_games_row,
}

# FakePurchaseService-like fakes need the new interface member; checked after porting.


def app_display_name(app: Path) -> str:
    m = re.search(r'^\s*display_name:\s*"?([^"\n]+?)"?\s*(#.*)?$', (app / "app.config.yaml").read_text(), re.M)
    if not m:
        raise Diverged("display_name not found in app.config.yaml")
    return m.group(1).strip()


def package_name(app: Path) -> str:
    m = re.search(r"^name:\s*(\S+)", (app / "pubspec.yaml").read_text(), re.M)
    if not m:
        raise Diverged("package name not found in pubspec.yaml")
    return m.group(1)


def personalise(rel: str, data: bytes, name: str, folder: str, pkg: str) -> bytes:
    if rel.endswith(".dart") and b"package:flutter_game_template/" in data:
        data = data.replace(b"package:flutter_game_template/", f"package:{pkg}/".encode())
    if rel in ("web/index.html", "web/manifest.json"):
        t = data.decode()
        if rel.endswith(".html"):
            t = t.replace("Block Puzzle", name.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"))
        else:
            t = t.replace("Block Puzzle", name)
        return t.encode()
    return data


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("app")
    ap.add_argument("--folder", required=True, choices=FOLDERS)
    ap.add_argument("--rev", default="ef7359f")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    app = Path(a.app).resolve()
    if not (app / "app.config.yaml").is_file():
        print(f"error: {app} is not a game repo (no app.config.yaml)")
        return 2
    try:
        name = app_display_name(app)
        pkg = package_name(app)
    except Diverged as e:
        print(f"STOP, nothing changed: {e}")
        return 1

    plan: list[tuple[str, Path, bytes]] = []  # (action, path, content)
    skipped: list[str] = []
    try:
        for status, path in changed_files(a.rev):
            rel = path[len(PREFIX):]
            if rel == "docs/workflows/web-vps.yml":
                continue  # superseded by the studio-level deploy-to-vps-as-web workflow
            dst = app / rel
            new = git_show(a.rev, path)
            if new is None:
                continue
            new = personalise(rel, new, name, a.folder, pkg)
            if status == "A":
                if not dst.exists():
                    plan.append(("add", dst, new))
                elif dst.read_bytes() == new:
                    skipped.append(f"{rel} (up to date)")
                else:
                    raise Diverged(f"{rel} exists in the app with other content; refusing to overwrite")
            elif status == "M":
                if not dst.exists():
                    skipped.append(f"{rel} (not in this app)")
                    continue
                cur = dst.read_bytes()
                old = git_show(a.rev + "^", path)
                if cur == new:
                    skipped.append(f"{rel} (up to date)")
                elif cur == old:
                    plan.append(("replace", dst, new))
                elif path in EDITS:
                    try:
                        edited = EDITS[path](cur.decode()).encode()
                    except Diverged as e:
                        raise Diverged(f"{rel} differs from the template and cannot be ported safely: {e}")
                    if edited == cur:
                        skipped.append(f"{rel} (up to date)")
                    else:
                        plan.append(("edit", dst, edited))
                else:
                    raise Diverged(f"{rel} differs from the template and has no safe edit; refusing")
            elif status == "D":
                continue
        spec = app / "docs" / "SPEC.md"
        if spec.is_file():
            t = spec.read_text()
            if SPEC_HEADING not in t:
                plan.append(("edit", spec, (t.rstrip("\n") + "\n" + SPEC_NOTE.format(folder=a.folder)).encode()))
            else:
                skipped.append("docs/SPEC.md (note present)")
    except Diverged as e:
        print(f"STOP, nothing changed: {e}")
        return 1

    for action, path, data in plan:
        print(f"{action:8} {path.relative_to(app)}")
        if not a.dry_run:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data)
            if path.suffix == ".sh":
                path.chmod(0o755)
    for s in skipped:
        print(f"skip     {s}")
    print("up to date" if not plan else ("dry run: nothing written" if a.dry_run else f"changed {len(plan)} files"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
