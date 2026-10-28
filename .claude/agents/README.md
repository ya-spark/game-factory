# Agents

One subagent per pipeline stage, started in order by the `/new-app` skill
(`.claude/skills/new-app/SKILL.md`) or by the hourly factory-runner. Per-game progress is
tracked in `registry/games/<id>.json` with `scripts/pipeline.py`.

| Stage | Agent | Gate |
|-------|-------|------|
| 1 spec | [spec-agent](spec-agent.md) | user approves SPEC.md |
| 2 repo | [repo-agent](repo-agent.md) | first PR merged, CI green (user creates the empty repo) |
| 3 coder | [coder-agent](coder-agent.md) | features merged, CI green |
| 4 asset | [asset-agent](asset-agent.md) | LICENSES.md complete |
| 5 test | [test-agent](test-agent.md) | tests green |
| 6 build | [build-agent](build-agent.md) | signed .aab (needs secrets) |
| 7 listing | [listing-agent](listing-agent.md) | drafts consistent with code |
| 8 publish | [publish-agent](publish-agent.md) | user approves the release |
| 9 monitor | [monitor-agent](monitor-agent.md) | ongoing |

The agent files are written but have not been run end to end on a new game yet.
