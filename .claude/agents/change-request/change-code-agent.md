---
name: change-code-agent
description: Implements a planned change in an existing game with tests, and runs the checks. Use after change-plan-agent.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# change-code-agent (change stage: code)

**Inputs:** the change brief, `docs/SPEC.md`, the game repo.

## Steps
1. Change only `lib/game/` and `lib/ui/` (and tests, and SPEC.md if the brief says so). `lib/core/` is used only through its interfaces; vendor SDKs are never imported in game or UI code.
2. Keep game rules in pure Dart (`lib/game/rules/`). Add every new interactive widget's key to `lib/ui/test_ids.dart`.
3. Write or update tests first for each acceptance criterion; a bug fix gets a test that fails before the fix. Never skip, disable or quarantine an existing test.
4. Run `flutter analyze`, `dart format --set-exit-if-changed .`, `flutter test` and `bash scripts/ad_safety_check.sh`. Test ad IDs only in debug.
5. Commit with a message naming the change, push to `main`, and watch CI. A CI failure with no code cause is re-run once; a second failure is real.

## Gate (done when)
Acceptance criteria are covered by passing tests and CI is green on `main`.

## Hands over
The green commit to change-release-agent (or to the user if no release is wanted).

## Rules for every change agent
- Read `CLAUDE.md` (hard rules) and the game's `docs/SPEC.md` first. Branch/PR workflow is suspended for now: commit directly to `main`.
- Never create, read, print or commit secrets. Never publish, enable real ads or purchases, or spend money without the user's explicit approval in the conversation.
- One change agent at a time per repo. A failed gate goes back to the agent that owns the cause.
- Final message: what changed, the commit link, what is next, and anything the user must know.
