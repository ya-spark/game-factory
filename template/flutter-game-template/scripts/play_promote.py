#!/usr/bin/env python3
"""Promote a release that is already on one Google Play track to another track (no rebuild).

Used by .github/workflows/promote-production.yml so production gets exactly the binary (version
code) that testers ran on the internal track. Reads the service account JSON from the
PLAY_SERVICE_ACCOUNT_JSON environment variable; never prints it.
"""
from __future__ import annotations

import argparse
import json
import os
import sys

SCOPE = "https://www.googleapis.com/auth/androidpublisher"
# A draft release cannot be promoted: it has not been rolled out to testers yet.
SOURCE_STATUSES = ("completed", "inProgress")
TARGET_STATUSES = ("draft", "inProgress", "completed")


class PromoteError(Exception):
    """A problem the operator can fix; reported without a stack trace."""


def pick_release(releases, version_code=None):
    """Choose the release to promote: the one holding version_code, else the newest."""
    usable = [r for r in releases if r.get("versionCodes") and r.get("status") in SOURCE_STATUSES]
    if not usable:
        raise PromoteError(
            "No rolled-out release found on the source track. A draft release cannot be "
            "promoted: roll it out to testers in Play Console first."
        )
    if version_code is not None:
        for release in usable:
            if str(version_code) in [str(v) for v in release["versionCodes"]]:
                return release
        available = sorted({str(v) for r in usable for v in r["versionCodes"]})
        raise PromoteError(
            f"Version code {version_code} is not on the source track. Available: {', '.join(available)}"
        )
    return max(usable, key=lambda r: max(int(v) for v in r["versionCodes"]))


def build_release(source, status, user_fraction):
    """The release body to write on the target track, copying code, name and notes."""
    if status not in TARGET_STATUSES:
        raise PromoteError(f"status must be one of {', '.join(TARGET_STATUSES)}, got {status!r}")
    release = {"versionCodes": [str(v) for v in source["versionCodes"]], "status": status}
    if source.get("name"):
        release["name"] = source["name"]
    if source.get("releaseNotes"):
        release["releaseNotes"] = source["releaseNotes"]
    if status == "inProgress":
        if not 0 < user_fraction < 1:
            raise PromoteError("user fraction must be between 0 and 1 (exclusive) for a staged rollout")
        release["userFraction"] = user_fraction
    return release


def parse_version_code(text):
    text = (text or "").strip()
    if not text:
        return None
    if not text.isdigit():
        raise PromoteError(f"version code must be a whole number, got {text!r}")
    return int(text)


def parse_args(argv):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--package", required=True)
    p.add_argument("--from-track", default="internal")
    p.add_argument("--to-track", default="production")
    p.add_argument("--version-code", default="")
    p.add_argument("--status", default="draft", choices=TARGET_STATUSES)
    p.add_argument("--user-fraction", type=float, default=0.1)
    return p.parse_args(argv)


def promote(args):
    # Imported here so the pure helpers above can be tested without the Google libraries.
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.errors import HttpError

    raw = os.environ.get("PLAY_SERVICE_ACCOUNT_JSON", "")
    if not raw:
        raise PromoteError("PLAY_SERVICE_ACCOUNT_JSON is not set")
    creds = service_account.Credentials.from_service_account_info(json.loads(raw), scopes=[SCOPE])
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()
    edit_id = edits.insert(packageName=args.package, body={}).execute()["id"]
    try:
        source_track = edits.tracks().get(
            packageName=args.package, editId=edit_id, track=args.from_track
        ).execute()
        source = pick_release(source_track.get("releases", []), parse_version_code(args.version_code))
        release = build_release(source, args.status, args.user_fraction)
        edits.tracks().update(
            packageName=args.package,
            editId=edit_id,
            track=args.to_track,
            body={"track": args.to_track, "releases": [release]},
        ).execute()
        edits.commit(packageName=args.package, editId=edit_id).execute()
    except HttpError as err:
        try:
            edits.delete(packageName=args.package, editId=edit_id).execute()
        except HttpError:
            pass
        raise PromoteError(
            f"Google Play API error: HTTP {err.resp.status} {getattr(err, 'reason', '')}".strip()
        ) from err
    except PromoteError:
        try:
            edits.delete(packageName=args.package, editId=edit_id).execute()
        except HttpError:
            pass
        raise
    print(
        f"Promoted version code(s) {', '.join(release['versionCodes'])} "
        f"from '{args.from_track}' to '{args.to_track}' with status '{release['status']}'."
    )


def main(argv=None):
    try:
        promote(parse_args(argv))
    except PromoteError as err:
        print(f"::error title=Promotion failed::{err}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
