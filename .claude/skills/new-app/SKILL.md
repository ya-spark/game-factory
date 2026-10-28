---
name: new-app
description: Orchestrates a new game end to end, from the user's prompt and a short Q&A through spec, repo, code, assets, tests, build, listing and publish, one stage subagent at a time. Use when the user says /new-app or asks for a new game.
---

# /new-app: the orchestrator

You run in the main session. You do the Q&A with the user, then call one stage subagent at a
time (defined in `.claude/agents/`), record every result with `scripts/pipeline.py`, and stop at
the gates. All state lives in the repos (`registry/games/<id>.json`), never in your memory, so any
session, and the hourly factory-runner, can resume it.

## 1. Intake (you, with the user)
1. Take the user's prompt. Ask only what the prompt does not answer, in one round: genre and template
   (block puzzle exists; falling blocks is not built), key features, monetization preferences,
   art style, retention features to switch off (all ON by default), anything they do not want,
   the game's name (original; no existing game names or keywords).
2. Derive: `id` (snake_case), repo `ya-spark/game-<id-kebab>`, package `com.activemindcraft.<idwithoutunderscores>`,
   seed color. Check the package id is not already a Play listing (store URL) when you can.
3. Start tracking: `python3 scripts/pipeline.py init <id> --repo ya-spark/game-<kebab> --package <pkg>`
   (on a branch + PR to app-factory; merge when CI is green).

## 2. Run the stages in order
Use `python3 scripts/pipeline.py next --json` to learn the next (game, stage, agent). Start that
subagent with the game id, the Q&A answers and the paths it needs. When it returns, read its
final message and confirm the stage status with `pipeline.py status <id>`. Then call `next` again.

| Stage | Agent | You must stop for |
|-------|-------|-------------------|
| spec | spec-agent | the user's approval of `docs/SPEC.md` (then set `done`) |
| repo | repo-agent | the user creating the empty private repo (GitHub gives us a 403) and turning on auto-merge + a branch rule |
| coder | coder-agent | nothing; CI green per PR |
| asset | asset-agent | nothing; license check green |
| test | test-agent | nothing; CI green |
| build | build-agent | the five release secrets + real AdMob IDs (blocked until the user sets them) |
| listing | listing-agent | the user's review of the store text |
| publish | publish-agent | every promotion; the first release needs the user in Play Console |
| monitor | monitor-agent | none |

## 3. Rules
- One subagent at a time per repo (the git proxy allows two concurrent operations per repo).
- A failed gate goes back to the agent that owns the cause, not forward.
- Claude merges its own PRs when CI is green. The user approves: the spec, production promotion,
  monetization changes, and anything involving accounts, money or secrets.
- Never publish, enable real ads or purchases, spend money, or touch secrets without the user.
- If a stage is `blocked`, tell the user exactly the note's text and stop; the hourly runner resumes
  when the status changes.
- Report briefly after each stage: what changed, PR link, status, what is next.
