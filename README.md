# game-factory

Factory scripts, registry and the Flutter + Flame game template used to build, test and publish
Android games to Google Play (AdMob ads + Play Billing). It is a submodule of `game-studio`: the
skills, agents, issue inbox and decisions live there, and all work starts from there.

| Path | Purpose |
|------|---------|
| `template/flutter-game-template/` | The game template. Game repos are generated from this. |
| `registry/apps.yaml` | Registry of games produced by the factory. |
| `docs/PLAY_SETUP.md` | Manual (human-only) Google Play / AdMob setup checklist. |
| `scripts/` | `new_game.py` (generator) and `pipeline.py` (per-game stage tracking). |
| `.github/workflows/template-ci.yml` | Verifies the template itself on every push and PR. |

Agents: work from the `game-studio` root and read its `CLAUDE.md` first.

## Flutter version

Pinned to the version in `.flutter-version` (also used by all workflows).
