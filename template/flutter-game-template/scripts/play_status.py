#!/usr/bin/env python3
"""Read-only report of what is on each Google Play track for this game.

Used by .github/workflows/check-play-status.yml. It opens a Play "edit", lists the tracks and deletes
the edit again without committing, so nothing on Play changes. It compares the result with
pubspec.yaml and the latest release workflow run, and writes a Markdown report to the job summary.
Reads the service account JSON from PLAY_SERVICE_ACCOUNT_JSON; never prints it. Only version
names, version codes and statuses are written out.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
TRACK_ORDER = ("internal", "alpha", "beta", "production")
# The track releases go to (closed testing). Internal is only used when the owner asks (owner, 2026-11-09).
RELEASE_TRACK = "alpha"


class StatusError(Exception):
    """A problem the operator can fix; reported without a stack trace."""


def parse_pubspec_version(text):
    """Return (version_name, build_number) from the pubspec `version:` line, e.g. ('1.0.1', '2')."""
    match = re.search(r"^version:\s*([^\s+#]+)(?:\+(\S+))?", text or "", re.MULTILINE)
    if not match:
        raise StatusError("no `version:` line found in pubspec.yaml")
    return match.group(1), match.group(2) or ""


def _codes(release):
    return sorted((int(v) for v in release.get("versionCodes", [])), reverse=True)


def sort_tracks(tracks):
    def key(t):
        name = t.get("track", "")
        return (TRACK_ORDER.index(name) if name in TRACK_ORDER else len(TRACK_ORDER), name)

    return sorted(tracks, key=key)


def newest_live_code(tracks, track=RELEASE_TRACK):
    """Highest version code on `track` whose release is rolled out (completed or inProgress)."""
    best = None
    for t in tracks:
        if t.get("track") != track:
            continue
        for release in t.get("releases", []):
            if release.get("status") in ("completed", "inProgress"):
                for code in _codes(release):
                    best = code if best is None else max(best, code)
    return best


def expected_label(name, code):
    """The Play release name the release workflow sets: '<pubspec version name> (<version code>)'."""
    return f"{name} ({code})"


def newest_code(tracks, track=RELEASE_TRACK):
    """Highest version code on `track` whatever its status (a closed-testing upload stays a draft until rolled out)."""
    best = None
    for t in tracks:
        if t.get("track") != track:
            continue
        for release in t.get("releases", []):
            for code in _codes(release):
                best = code if best is None else max(best, code)
    return best


def label_mismatch(tracks, name):
    """The Play release name of the newest release (draft or live) on the release track if it is not '<name> (<code>)', else None."""
    newest = newest_code(tracks)
    if newest is None:
        return None
    names = [
        r.get("name") for t in tracks if t.get("track") == RELEASE_TRACK
        for r in t.get("releases", []) if newest in _codes(r) and r.get("name")
    ]
    return names[0] if names and names[0] != expected_label(name, newest) else None


def summarize(package, pubspec_version, tracks, latest_run=None, latest_success=None):
    """Build the Markdown report. `latest_run` / `latest_success` are dicts from `gh run list`."""
    name, build = pubspec_version
    lines = [f"## Google Play status: `{package}`", ""]
    lines.append(f"pubspec.yaml version: **{name}**" + (f" (build `{build}` is ignored by releases)" if build else ""))
    lines.append("")
    lines += ["| Track | Release | Version codes | Status | Rollout |", "|---|---|---|---|---|"]
    any_release = False
    for t in sort_tracks(tracks):
        releases = t.get("releases", [])
        if not releases:
            lines.append(f"| {t.get('track', '?')} | (none) | | | |")
            continue
        for release in releases:
            any_release = True
            codes = ", ".join(str(c) for c in _codes(release)) or "-"
            fraction = release.get("userFraction")
            rollout = f"{fraction * 100:g}%" if fraction else ""
            lines.append(
                f"| {t.get('track', '?')} | {release.get('name') or '-'} | {codes} "
                f"| {release.get('status', '?')} | {rollout} |"
            )
    if not any_release:
        lines += ["", "No releases found on any track."]
    lines += ["", "### Checks", ""]
    live = newest_live_code(tracks)
    drafts = [
        c for t in tracks if t.get("track") == RELEASE_TRACK
        for r in t.get("releases", []) if r.get("status") == "draft" for c in _codes(r)
    ]
    if latest_run:
        lines.append(
            f"- Latest `release` run: #{latest_run.get('number')} "
            f"({latest_run.get('conclusion') or latest_run.get('status')}) "
            f"on `{str(latest_run.get('headSha', ''))[:7]}` {latest_run.get('url', '')}".rstrip()
        )
    else:
        lines.append("- No `release` workflow run found.")
    lines.append(
        "- The Play version code is the `release` run number (`--build-number`); "
        "the Play release name is `<pubspec version name> (<version code>)`."
    )
    if latest_success is not None:
        expected = int(latest_success.get("number"))
        if live is None:
            lines.append(f"- :warning: Nothing is rolled out on {RELEASE_TRACK}; the last good release run was #{expected}.")
        elif live == expected:
            lines.append(f"- :white_check_mark: Newest live {RELEASE_TRACK} version code {live} matches the last successful release run.")
        elif live < expected:
            lines.append(
                f"- :warning: Newest live {RELEASE_TRACK} version code is {live} but release run #{expected} succeeded: "
                "it may still be a draft or not uploaded."
            )
        else:
            lines.append(f"- Newest live {RELEASE_TRACK} version code {live} is newer than the last successful release run #{expected} (uploaded by hand or from another run).")
    elif live is not None:
        lines.append(f"- Newest live {RELEASE_TRACK} version code: {live}.")
    mismatch = label_mismatch(tracks, name)
    if mismatch is not None:
        lines.append(
            f"- :x: Play release name `{mismatch}` for the newest {RELEASE_TRACK} release "
            f"is not `{expected_label(name, newest_code(tracks))}` (pubspec.yaml version name plus Play version code)."
        )
    if drafts:
        lines.append(
            f"- :warning: Draft on {RELEASE_TRACK} (not rolled out yet): version code(s) {', '.join(str(c) for c in sorted(set(drafts), reverse=True))}."
        )
    return "\n".join(lines) + "\n"


def load_run(env_prefix):
    """A run dict from JSON in an environment variable, or None."""
    raw = os.environ.get(env_prefix, "").strip()
    if not raw or raw in ("[]", "null"):
        return None
    data = json.loads(raw)
    if isinstance(data, list):
        data = data[0] if data else None
    return data or None


def fetch_tracks(package):
    # Imported here so the pure helpers above can be tested without the Google libraries.
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError

    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if not raw:
        raise StatusError("PLAY_SERVICE_ACCOUNT_JSON is not set")
    creds = service_account.Credentials.from_service_account_info(json.loads(raw), scopes=[SCOPE])
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()
    edit_id = None
    try:
        edit_id = edits.insert(packageName=package, body={}).execute()["id"]
        return edits.tracks().list(packageName=package, editId=edit_id).execute().get("tracks", [])
    except HttpError as err:
        hint = ""
        if err.resp.status in (401, 403):
            hint = " (the service account may lack access to this app in Play Console)"
        elif err.resp.status == 404:
            hint = " (package not found: has the app been created in Play Console?)"
        raise StatusError(
            f"Google Play API error: HTTP {err.resp.status} {getattr(err, 'reason', '')}{hint}".strip()
        ) from err
    finally:
        if edit_id:
            try:
                edits.delete(packageName=package, editId=edit_id).execute()
            except HttpError:
                pass


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--package", required=True)
    p.add_argument("--pubspec", default="pubspec.yaml")
    p.add_argument("--summary-file", default=os.environ.get("GITHUB_STEP_SUMMARY", ""))
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)
    try:
        with open(args.pubspec, encoding="utf-8") as fh:
            version = parse_pubspec_version(fh.read())
        tracks = fetch_tracks(args.package)
        report = summarize(
            args.package,
            version,
            tracks,
            load_run("LATEST_RUN_JSON"),
            load_run("LATEST_SUCCESS_JSON"),
        )
        out_of_sync = label_mismatch(tracks, version[0]) is not None
    except StatusError as err:
        print(f"::error title=Play status failed::{err}", file=sys.stderr)
        if args.summary_file:
            with open(args.summary_file, "a", encoding="utf-8") as fh:
                fh.write(f"## Google Play status failed\n\n{err}\n")
        return 1
    print(report)
    if args.summary_file:
        with open(args.summary_file, "a", encoding="utf-8") as fh:
            fh.write(report)
    if out_of_sync:
        print("::error title=Play label out of sync::the Play release name differs from the pubspec.yaml version name", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
