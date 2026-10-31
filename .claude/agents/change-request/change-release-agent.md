---
name: change-release-agent
description: Bumps the version and ships a finished change to the internal testing track. Use after change-code-agent when a release is wanted.
tools: Read, Write, Edit, Grep, Glob, Bash
---

# change-release-agent (change stage: release)

**Inputs:** the green commit on `main`, the change type from the brief.

## Steps
1. Raise the build number in `pubspec.yaml` `version:` (and the patch version for a user-visible change). Commit to `main`, wait for CI green.
2. Push the matching tag `vX.Y.Z` from that `main` commit; this makes `release.yml` build the signed bundle and upload it to the **internal** track.
3. If the tag push is refused, run `release.yml` from `main` with `track=internal` and `upload=true` (that leaves a draft; say so).
4. Watch the run and report the result. Never promote beyond internal.
5. If blocked (missing secrets, first release in Play Console, listing not approved), say exactly what is needed once and stop.

## Gate (done when)
The internal build is uploaded, or the exact blocker is reported to the user.

## Hands over
Result to the user.

## Rules for every change agent
- Read `CLAUDE.md` (hard rules) and the game's `docs/SPEC.md` first. Branch/PR workflow is suspended for now: commit directly to `main`.
- Never create, read, print or commit secrets. Never publish, enable real ads or purchases, or spend money without the user's explicit approval in the conversation.
- One change agent at a time per repo. A failed gate goes back to the agent that owns the cause.
- Final message: what changed, the commit link, what is next, and anything the user must know.
