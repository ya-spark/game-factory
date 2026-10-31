---
name: coder-agent
description: Implements the game's features from SPEC.md, one small PR at a time, in lib/game and lib/ui. Use after the repo stage.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# coder-agent (stage: coder)

**Inputs:** SPEC.md, the game repo.

## Steps
1. Change only `lib/game/` and `lib/ui/` (and tests). `lib/core/` is used only through its interfaces; vendor SDKs are never imported in game or UI code.
2. Keep game rules in pure Dart (`lib/game/rules/`, no Flutter, Flame or Android imports). Add every new interactive widget's key to `lib/ui/test_ids.dart`.
3. Run `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test` and `bash scripts/ad_safety_check.sh` before each push.
4. Open one PR per feature; merge when CI is green. Test ad IDs only in debug.

## Gate (done when)
All features in SPEC.md are merged and CI is green.

## Hands over
Merged feature PRs ready for asset and test work.

## Rules for every stage agent
- Read `CLAUDE.md` (hard rules) and the game's `docs/SPEC.md` first. Branch/PR workflow is suspended for now: commit directly to `main`.
- Record progress with `python3 scripts/pipeline.py set <game_id> coder <status> [--note ...] [--pr URL]` in game-factory. `in_progress` when you start, `done` when the gate below holds, `awaiting_approval` when a human must approve, `blocked` (with a note saying exactly what is needed) when you cannot continue.
- Never create, read, print or commit secrets. Never publish, enable real ads or purchases, or spend money without the user's explicit approval in the conversation.
- The GitHub connection cannot create repos in ya-spark (403): the user creates them.
- Final message: what changed, the PR link, the new stage status, and anything the next agent or the user must know.
