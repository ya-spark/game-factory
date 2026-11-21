#!/usr/bin/env python3
"""Generate a game package in games/<id>/ (SH1: one copy of every game).

Usage:
  python3 scripts/new_game_package.py --id my_game --name "My Game" [--out games]

Writes a package any container can list: its barrel (`lib/<id>.dart`), a host interface
(`<Pascal>Services` + `<Pascal>ServicesScope`, the only way the game reaches its container), test
IDs (`<Pascal>Ids`), pure-Dart rules (`lib/src/rules/`), one sample screen with a test, a testing
library (`lib/testing.dart`: fake services + `pumpGame`), `docs/SPEC.md` (the game's only spec),
`README.md`, `pubspec.yaml` (game_core by constraint) and `pubspec_overrides.yaml` (path to
../../game_core, for work inside this repo). Python 3 standard library only.
"""

from __future__ import annotations

import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GAMES_DIR = REPO_ROOT / "games"
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")


class GenError(Exception):
    """User-facing error (bad input, refusal)."""


def pascal(game_id: str) -> str:
    return "".join(w.capitalize() for w in game_id.split("_"))


def validate(game_id: str, name: str, games_dir: Path) -> None:
    if not ID_RE.match(game_id):
        raise GenError(f"invalid --id {game_id!r}: snake_case, starting with a letter")
    if not name or any(c in name for c in "\"'#\\\n"):
        raise GenError(f"invalid --name {name!r}: no quotes, # or backslashes")
    if (games_dir / game_id).exists():
        raise GenError(f"games/{game_id} already exists")


def files(game_id: str, name: str) -> dict[str, str]:
    p = pascal(game_id)
    return {
        ".gitignore": ".dart_tool/\nbuild/\npubspec.lock\n",
        "analysis_options.yaml": "analyzer:\n  exclude:\n    - build/**\ninclude: package:flutter_lints/flutter.yaml\n",
        "pubspec.yaml": f"""name: game_{game_id}
description: "{name}: a game in game-factory/games; apps and the web are containers that list it."
publish_to: 'none'
version: 1.0.0
environment:
  sdk: ^3.13.7

dependencies:
  flutter:
    sdk: flutter
  # Resolved by the container's dependency_overrides (git ref of game-factory). In this repo,
  # pubspec_overrides.yaml points it at ../../game_core.
  game_core: ^1.0.0
  flutter_test:
    sdk: flutter  # the testing library (lib/testing.dart) uses it

dev_dependencies:
  flutter_lints: ^6.0.0
""",
        "pubspec_overrides.yaml": """# Used when working inside game-factory (a container's own dependency_overrides win when this
# package is a dependency).
dependency_overrides:
  game_core:
    path: ../../game_core
""",
        "README.md": f"""# game_{game_id}

{name}: a game in `game-factory/games/`; apps and the web are containers that list it (SH1, owner 2026-11-21).

- Spec: `docs/SPEC.md` (the only copy). Public API: `lib/{game_id}.dart`.
- Needs Flutter and `game_core` (shared kit and host contract). A container adds `game_{game_id}` as a git
  dependency at one commit of `game-factory`, pins `game_core` with `dependency_overrides` to the same commit,
  provides a `GameHost` (`GameHostScope`) and a `{p}Services` (`{p}ServicesScope`) above the game.
- Tests: `flutter test` here. Containers reuse `lib/testing.dart` (`FakeServices`, `pumpGame`).
- Never imports container code: everything it needs from its container is in `{p}Services` or `GameHost`.
""",
        "docs/SPEC.md": f"""# {name} (game package `game_{game_id}`)

Status: DRAFT. The game lives once in `game-factory/games/{game_id}/`; containers list it. Write the behaviour
here (rules, feel, layout, offsets) and change it in the same commit as the code.

### Goal
- One sentence: what the player does and how a run ends.

### Controls (defaults unless this spec says otherwise)
- Left / right move, up zaps or selects, down chooses the best option (else slows), Space pauses (a pause
  button is on screen), Enter or Q opens the question, 1 to 4 pick an answer, Esc pauses.

### Layout
- No title bar: the game gets the whole play area; exit, pause and score are small overlays.
- Responsive for the web (`template/flutter-game-template/docs/WEB_LAYOUT.md`).

### What the container provides
- `{p}Services`: best score and the container's other hooks (see `lib/src/{game_id}_host.dart`).
- `GameHost` (game_core): read aloud, reduce motion, banner slots, palette.

### Test IDs
- `{p}Ids` in `lib/src/{game_id}_ids.dart`; every interactive widget carries one.
""",
        f"lib/{game_id}.dart": f"""/// {name}: a game in game-factory/games. A container shows [{p}Screen] and provides a
/// [{p}Services] ([{p}ServicesScope]) and a `GameHost` above it. Spec: `docs/SPEC.md`.
library;

export 'src/{game_id}_host.dart';
export 'src/{game_id}_ids.dart';
export 'src/{game_id}_screen.dart';
export 'src/rules/{game_id}_state.dart';
""",
        f"lib/src/{game_id}_ids.dart": f"""import 'package:flutter/widgets.dart';

/// The stable test IDs of {name} (hard rule 4). The key strings are part of the game's contract:
/// tests in every container use them.
abstract final class {p}Ids {{
  static const screen = Key('{game_id}.screen');
  static const exit = Key('{game_id}.exit');
  static const pause = Key('{game_id}.pause');
  static const score = Key('{game_id}.score');
  static const best = Key('{game_id}.best');
  static const tap = Key('{game_id}.tap');
  static const banner = Key('{game_id}.banner');
}}
""",
        f"lib/src/{game_id}_host.dart": f"""import 'package:flutter/widgets.dart';

/// What {name} asks of its container (the app or the web). The container implements it with its own
/// save and services; the game never imports container code.
abstract interface class {p}Services {{
  /// The best score so far.
  int get bestScore;

  /// Called when a run ends with [score]; the container keeps the best and may show an ad.
  Future<void> runFinished(int score);
}}

/// Provides the container's [{p}Services] to the game.
class {p}ServicesScope extends InheritedWidget {{
  const {p}ServicesScope({{super.key, required this.services, required super.child}});
  final {p}Services services;

  static {p}Services of(BuildContext context) {{
    final scope = context.dependOnInheritedWidgetOfExactType<{p}ServicesScope>();
    assert(scope != null, 'No {p}ServicesScope above this context');
    return scope!.services;
  }}

  @override
  bool updateShouldNotify({p}ServicesScope oldWidget) => services != oldWidget.services;
}}
""",
        f"lib/src/rules/{game_id}_state.dart": f"""/// Pure-Dart rules of {name} (no Flutter, hard rule 3). The sample: each tap scores a point.
class {p}State {{
  int _score = 0;
  bool _finished = false;

  int get score => _score;
  bool get finished => _finished;

  /// One player action; no effect once the run is finished.
  void tap() {{
    if (!_finished) _score++;
  }}

  /// Ends the run; returns the final score.
  int finish() {{
    _finished = true;
    return _score;
  }}
}}
""",
        f"lib/src/{game_id}_screen.dart": f"""import 'package:flutter/material.dart';
import 'package:game_core/game_core.dart';

import '{game_id}_host.dart';
import '{game_id}_ids.dart';
import 'rules/{game_id}_state.dart';

/// The sample screen of {name}: replace the body with the real game. It shows the contract every
/// game screen follows: no title bar, exit and score as small overlays, banners from the host,
/// everything else from [{p}Services].
class {p}Screen extends StatefulWidget {{
  const {p}Screen({{super.key, required this.onExit}});
  final VoidCallback onExit;

  @override
  State<{p}Screen> createState() => _{p}ScreenState();
}}

class _{p}ScreenState extends State<{p}Screen> {{
  final {p}State _state = {p}State();

  void _exit() {{
    final services = {p}ServicesScope.of(context);
    services.runFinished(_state.finish());
    widget.onExit();
  }}

  @override
  Widget build(BuildContext context) {{
    final services = {p}ServicesScope.of(context);
    final host = GameHostScope.of(context);
    return Scaffold(
      key: {p}Ids.screen,
      body: SafeArea(
        child: Stack(
          children: [{{
            Center(
              child: FilledButton(
                key: {p}Ids.tap,
                onPressed: () => setState(_state.tap),
                child: const Text('Tap'),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                key: {p}Ids.exit,
                tooltip: 'Exit',
                icon: const Icon(Icons.close),
                onPressed: _exit,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Text(
                'Score ${{_state.score}}  Best ${{services.bestScore}}',
                key: {p}Ids.score,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: KeyedSubtree(
                key: {p}Ids.banner,
                child: host.banner(context, GameBannerSlot.postGame),
              ),
            ),
          }}],
        ),
      ),
    );
  }}
}}
""".replace("[{", "[").replace("}],", "],"),
        "lib/testing.dart": f"""/// Test helpers for containers and for this package's own tests: fake services and a harness.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'src/{game_id}_host.dart';
import 'src/{game_id}_screen.dart';

/// In-memory {p}Services that records what the game reported.
class Fake{p}Services implements {p}Services {{
  Fake{p}Services({{this.bestScore = 0}});

  @override
  int bestScore;
  final List<int> finishedRuns = [];

  @override
  Future<void> runFinished(int score) async {{
    finishedRuns.add(score);
    if (score > bestScore) bestScore = score;
  }}
}}

/// Pumps the game with fake services and the default (no-op) host. Returns the services.
Future<Fake{p}Services> pumpGame(
  WidgetTester tester, {{
  Fake{p}Services? services,
  VoidCallback? onExit,
}}) async {{
  final s = services ?? Fake{p}Services();
  await tester.pumpWidget(
    MaterialApp(
      home: GameHostScope(
        host: const NoGameHost(),
        child: {p}ServicesScope(
          services: s,
          child: {p}Screen(onExit: onExit ?? () {{}}),
        ),
      ),
    ),
  );
  await tester.pump();
  return s;
}}
""",
        f"test/{game_id}_state_test.dart": f"""import 'package:flutter_test/flutter_test.dart';
import 'package:game_{game_id}/{game_id}.dart';

void main() {{
  test('each tap scores a point until the run is finished', () {{
    final s = {p}State();
    s.tap();
    s.tap();
    expect(s.score, 2);
    expect(s.finish(), 2);
    s.tap();
    expect(s.score, 2);
    expect(s.finished, isTrue);
  }});
}}
""",
        f"test/{game_id}_screen_test.dart": f"""import 'package:flutter_test/flutter_test.dart';
import 'package:game_{game_id}/{game_id}.dart';
import 'package:game_{game_id}/testing.dart';

void main() {{
  testWidgets('tapping scores and exit reports the run to the container', (tester) async {{
    var exited = false;
    final s = await pumpGame(tester, onExit: () => exited = true);
    expect(find.byKey({p}Ids.screen), findsOneWidget);
    await tester.tap(find.byKey({p}Ids.tap));
    await tester.tap(find.byKey({p}Ids.tap));
    await tester.pump();
    expect(find.text('Score 2  Best 0'), findsOneWidget);
    await tester.tap(find.byKey({p}Ids.exit));
    await tester.pump();
    expect(s.finishedRuns, [2]);
    expect(s.bestScore, 2);
    expect(exited, isTrue);
  }});
}}
""",
    }


def generate(game_id: str, name: str, games_dir: Path = GAMES_DIR) -> Path:
    validate(game_id, name, games_dir)
    out = games_dir / game_id
    for rel, text in files(game_id, name).items():
        f = out / rel
        f.parent.mkdir(parents=True, exist_ok=True)
        f.write_text(text, encoding="utf-8")
    # Line breaks depend on the names, so the package is formatted like every other one (when dart is installed).
    if shutil.which("dart"):
        subprocess.run(["dart", "format", "lib", "test"], cwd=out, capture_output=True, check=False)
    return out


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Generate a game package in games/<id>/.")
    ap.add_argument("--id", required=True, dest="game_id", help="snake_case game id")
    ap.add_argument("--name", required=True, help="display name")
    ap.add_argument("--out", type=Path, default=GAMES_DIR, help="games folder (default: games/)")
    args = ap.parse_args(argv)
    try:
        out = generate(args.game_id, args.name, args.out)
    except GenError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    print(f"Generated {args.game_id} at {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
