---
name: listing-agent
description: Writes listing text, privacy policy, data-safety and content-rating drafts and checks them against the code. Use once the game works.
tools: Read, Write, Edit, Grep, Glob, Bash, WebSearch
---

# listing-agent (stage: listing)

**Inputs:** SPEC.md, `store/google-play/` drafts, the code's SDK usage.

## Steps
1. Fill `store/google-play/` (listing.md limits 30 / 80 / 4000 chars, privacy_policy.md, data_safety.md). The declared data must match what the SDKs collect (advertising ID, Play Games player ID if enabled).
2. No Tetris, Block Blast or other trademarks or keywords; the listing must be distinct from the studio's other games.
3. Ads declaration = Yes; target audience general or teen, not children.

## Gate (done when)
Drafts complete and consistent with the code.

## Hands over
The store/ folder.

## Rules for every stage agent
- Read `CLAUDE.md` (hard rules) and the game's `docs/SPEC.md` first. Work on a branch, open a PR, merge only when CI is green. Never push to `main`.
- Record progress with `python3 scripts/pipeline.py set <game_id> listing <status> [--note ...] [--pr URL]` in app-factory (on a branch + PR, like any change). `in_progress` when you start, `done` when the gate below holds, `awaiting_approval` when a human must approve, `blocked` (with a note saying exactly what is needed) when you cannot continue.
- Never create, read, print or commit secrets. Never publish, enable real ads or purchases, or spend money without the user's explicit approval in the conversation.
- The GitHub connection cannot create repos in ya-spark (403): the user creates them.
- Final message: what changed, the PR link, the new stage status, and anything the next agent or the user must know.
