# Agents

Agents are split into two folders: `new-game/` (building a new game) and `change-request/` (changing an existing game).

## new-game/

One subagent per pipeline stage, started in order by the `/new-app` skill
(`.claude/skills/new-app/SKILL.md`) or by the hourly factory-runner. Per-game progress is
tracked in `registry/games/<id>.json` with `scripts/pipeline.py`.

| Stage | Agent | Gate |
|-------|-------|------|
| 1 spec | [spec-agent](new-game/spec-agent.md) | user approves SPEC.md |
| 2 repo | [repo-agent](new-game/repo-agent.md) | first PR merged, CI green (user creates the empty repo) |
| 3 coder | [coder-agent](new-game/coder-agent.md) | features merged, CI green |
| 4 asset | [asset-agent](new-game/asset-agent.md) | LICENSES.md complete |
| 5 test | [test-agent](new-game/test-agent.md) | tests green |
| 6 build | [build-agent](new-game/build-agent.md) | signed .aab (needs secrets) |
| 7 listing | [listing-agent](new-game/listing-agent.md) | drafts consistent with code |
| 8 publish | [publish-agent](new-game/publish-agent.md) | user approves the release |
| 9 monitor | [monitor-agent](new-game/monitor-agent.md) | ongoing |

The agent files are written but have not been run end to end on a new game yet.

## change-request/

Started in order by the `/change-app` skill (`.claude/skills/change-app/SKILL.md`). Not tracked in
`scripts/pipeline.py`; state lives in git (and the issue, if the request came from one).

| Stage | Agent | Gate |
|-------|-------|------|
| 1 plan | [change-plan-agent](change-request/change-plan-agent.md) | brief written, approvals obtained |
| 2 code | [change-code-agent](change-request/change-code-agent.md) | tests and CI green on main |
| 3 release | [change-release-agent](change-request/change-release-agent.md) | internal build uploaded, or blocker reported |
