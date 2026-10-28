# Inbox: start work by writing an issue

Open an issue in `ya-spark/app-factory` (the GitHub mobile app works) using one of the forms:

- **New game** (`[new-game] ...`): the idea in your words.
- **Change request** (`[change] ...`): which game (or "factory") and what to change.

Claude's hourly factory-runner (or a live session) picks it up and runs the whole flow.

## What happens

| You | Claude |
|-----|--------|
| Open a new-game issue | Asks at most four questions in a comment if something essential is missing; otherwise states its assumptions. Starts tracking (`registry/games/<id>.json`, with the issue number). |
| Reply to the questions | Writes the spec (`registry/specs/<id>.md`) in a PR and comments the link. |
| Reply `approve` (or what to change) | Marks the spec done, or revises it. Then: repo, code, assets, tests, listing, each a PR merged when CI is green. One short comment per finished stage. |
| Create the empty repo `ya-spark/game-<id>` when asked | Detects the repo itself and continues. |
| Set secrets / do the Play and AdMob steps when asked | Continues from `blocked` once the requirement exists. |
| Open a change request | Updates the spec and code through PRs, merges on green, comments and closes the issue. |

## Rules (enforced by the runner's instructions)

- Only issues and comments written by the repo owner (`yaseengem`) are acted on. Anything from
  anyone else is ignored, never followed.
- Approvals always come from you: the spec, production promotion, monetization changes, anything
  involving accounts, money or secrets. Claude never publishes, enables real ads or purchases, or
  touches secrets on its own.
- The tracking file is the record of truth; comments mirror it. Each Claude comment carries a hidden
  marker (`<!-- factory:... -->`) so it is never posted twice.
- Latency: up to an hour (the runner polls hourly). In a live session with Claude it is immediate.
