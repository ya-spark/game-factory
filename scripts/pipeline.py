#!/usr/bin/env python3
"""Per-game stage tracking for the factory pipeline. Python 3 standard library only.

State lives in registry/games/<game_id>.json (one file per game), so every session, subagent
and the hourly runner sees the same truth. Commands:

  pipeline.py init <game_id> --repo ya-spark/game-x [--package com.x.y] [--issue N]
  pipeline.py status [<game_id>] [--json]
  pipeline.py next [--json]            first actionable (game, stage) across all games
  pipeline.py set <game_id> <stage> <status> [--note TEXT] [--pr URL]

Stage order is fixed (STAGES). A stage is actionable when it is `pending` (or `in_progress`,
meaning resume) and every earlier stage is `done` or `skipped`.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GAMES_DIR = ROOT / "registry" / "games"

# (stage id, subagent, gate that must hold before the stage may be marked done)
STAGES = [
    ("spec", "spec-agent", "user approved docs/SPEC.md"),
    ("repo", "repo-agent", "empty repo filled, first PR merged, CI green"),
    ("coder", "coder-agent", "feature PRs merged, CI green"),
    ("asset", "asset-agent", "assets/LICENSES.md lists every asset, license check green"),
    ("test", "test-agent", "unit, widget and bot tests green"),
    ("build", "build-agent", "signed .aab built by release.yml (needs secrets)"),
    ("listing", "listing-agent", "store/ drafts complete, policy check passed"),
    ("publish", "publish-agent", "user approved the release"),
    ("monitor", "monitor-agent", "ongoing"),
]
STAGE_IDS = [s[0] for s in STAGES]
STATUSES = ["pending", "in_progress", "awaiting_approval", "done", "blocked", "skipped"]
PASSED = {"done", "skipped"}
ID_RE = re.compile(r"^[a-z][a-z0-9_]*$")
REPO_RE = re.compile(r"^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$")


class PipelineError(Exception):
    pass


def _path(game_id: str, games_dir: Path) -> Path:
    if not ID_RE.match(game_id):
        raise PipelineError(f"invalid game id {game_id!r} (snake_case expected)")
    return games_dir / f"{game_id}.json"


def load(game_id: str, games_dir: Path = GAMES_DIR) -> dict:
    p = _path(game_id, games_dir)
    if not p.exists():
        raise PipelineError(f"unknown game {game_id!r} ({p} not found)")
    return json.loads(p.read_text())


def save(game: dict, games_dir: Path = GAMES_DIR) -> None:
    games_dir.mkdir(parents=True, exist_ok=True)
    _path(game["id"], games_dir).write_text(json.dumps(game, indent=2) + "\n")


def init(game_id: str, repo: str, package: str = "", games_dir: Path = GAMES_DIR,
         today: str | None = None, issue: int | None = None) -> dict:
    if _path(game_id, games_dir).exists():
        raise PipelineError(f"game {game_id!r} already tracked")
    if not REPO_RE.match(repo):
        raise PipelineError(f"invalid repo {repo!r} (owner/name expected)")
    day = today or date.today().isoformat()
    game = {
        "id": game_id,
        "repo": repo,
        "package": package,
        "issue": issue if issue else "",  # game-factory issue that asked for this game
        "stages": {
            sid: {"agent": agent, "status": "pending", "gate": gate, "pr": "", "note": "",
                  "updated": day}
            for sid, agent, gate in STAGES
        },
    }
    save(game, games_dir)
    return game


def all_games(games_dir: Path = GAMES_DIR) -> list[dict]:
    if not games_dir.exists():
        return []
    return [json.loads(p.read_text()) for p in sorted(games_dir.glob("*.json"))]


def next_action(games: list[dict]) -> dict | None:
    """First game/stage ready to run: pending or in_progress with all earlier stages passed."""
    for game in games:
        for sid in STAGE_IDS:
            st = game["stages"][sid]["status"]
            if st in PASSED:
                continue
            if st in ("pending", "in_progress"):
                return {"game": game["id"], "repo": game["repo"], "stage": sid,
                        "agent": game["stages"][sid]["agent"], "resume": st == "in_progress",
                        "gate": game["stages"][sid]["gate"]}
            break  # blocked or awaiting_approval stops this game's chain
    return None


def set_status(game_id: str, stage: str, status: str, note: str | None = None,
               pr: str | None = None, games_dir: Path = GAMES_DIR,
               today: str | None = None) -> dict:
    if stage not in STAGE_IDS:
        raise PipelineError(f"unknown stage {stage!r}; stages: {', '.join(STAGE_IDS)}")
    if status not in STATUSES:
        raise PipelineError(f"unknown status {status!r}; statuses: {', '.join(STATUSES)}")
    game = load(game_id, games_dir)
    idx = STAGE_IDS.index(stage)
    if status in ("done", "in_progress", "awaiting_approval"):
        for earlier in STAGE_IDS[:idx]:
            if game["stages"][earlier]["status"] not in PASSED:
                raise PipelineError(
                    f"cannot set {stage} to {status}: earlier stage {earlier} is "
                    f"{game['stages'][earlier]['status']}")
    if status == "blocked" and not note:
        raise PipelineError("a blocked stage needs a --note saying what is required")
    st = game["stages"][stage]
    if note is None and status != st["status"]:
        note = ""  # a note describes the old status; do not leave it behind
    st["status"] = status
    if note is not None:
        st["note"] = note
    if pr is not None:
        st["pr"] = pr
    st["updated"] = today or date.today().isoformat()
    save(game, games_dir)
    return game


def render(game: dict) -> str:
    issue = f"  issue #{game['issue']}" if game.get("issue") else ""
    lines = [f"{game['id']}  ({game['repo']}){issue}"]
    for sid in STAGE_IDS:
        st = game["stages"][sid]
        extra = f"  - {st['note']}" if st["note"] else ""
        pr = f"  [{st['pr']}]" if st["pr"] else ""
        lines.append(f"  {sid:<8}{st['status']:<18}{st['agent']}{pr}{extra}")
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    p = sub.add_parser("init")
    p.add_argument("game_id")
    p.add_argument("--repo", required=True)
    p.add_argument("--package", default="")
    p.add_argument("--issue", type=int)
    p = sub.add_parser("status")
    p.add_argument("game_id", nargs="?")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("next")
    p.add_argument("--json", action="store_true")
    p = sub.add_parser("set")
    p.add_argument("game_id")
    p.add_argument("stage")
    p.add_argument("status")
    p.add_argument("--note")
    p.add_argument("--pr")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "init":
            print(render(init(a.game_id, a.repo, a.package, issue=a.issue)))
        elif a.cmd == "set":
            print(render(set_status(a.game_id, a.stage, a.status, a.note, a.pr)))
        elif a.cmd == "status":
            games = [load(a.game_id)] if a.game_id else all_games()
            print(json.dumps(games, indent=2) if a.json else "\n\n".join(map(render, games)))
        elif a.cmd == "next":
            n = next_action(all_games())
            if a.json:
                print(json.dumps(n))
            else:
                print("nothing to do" if n is None else
                      f"{n['game']}: {n['stage']} ({n['agent']})" + (" [resume]" if n["resume"] else ""))
    except PipelineError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
