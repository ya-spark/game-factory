# app-factory

Factory scripts, agent definitions and the Flutter + Flame game template used to
build, test and publish Android games to Google Play (AdMob ads + Play Billing).

| Path | Purpose |
|------|---------|
| `template/flutter-game-template/` | The game template. Game repos are generated from this. |
| `registry/apps.yaml` | Registry of games produced by the factory. |
| `docs/PLAY_SETUP.md` | Manual (human-only) Google Play / AdMob setup checklist. |
| `scripts/` | Factory scripts (placeholder). |
| `.claude/agents/`, `.claude/skills/` | Subagent and skill definitions (placeholders). |
| `.github/workflows/template-ci.yml` | Verifies the template itself on every PR. |

Agents: read `CLAUDE.md` first.

## Flutter version

Pinned to the version in `.flutter-version` (also used by all workflows).
