#!/usr/bin/env python3
"""Unit tests for scripts/play_status.py (no network, no Google libraries needed)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_status as ps  # noqa: E402

TRACKS = [
    {"track": "production", "releases": []},
    {"track": "internal", "releases": [
        {"name": "1.0.1 (6)", "versionCodes": ["6"], "status": "completed"},
        {"name": "1.0.0 (3)", "versionCodes": ["3"], "status": "completed"},
    ]},
]


class Pubspec(unittest.TestCase):
    def test_version_and_build(self):
        self.assertEqual(ps.parse_pubspec_version("name: x\nversion: 1.0.1+2\n"), ("1.0.1", "2"))

    def test_version_without_build(self):
        self.assertEqual(ps.parse_pubspec_version("version: 2.3.4\n"), ("2.3.4", ""))

    def test_missing_version(self):
        with self.assertRaises(ps.StatusError):
            ps.parse_pubspec_version("name: x\n")


class Live(unittest.TestCase):
    def test_newest_rolled_out_code(self):
        self.assertEqual(ps.newest_live_code(TRACKS), 6)

    def test_drafts_do_not_count(self):
        tracks = [{"track": "internal", "releases": [{"versionCodes": ["9"], "status": "draft"}]}]
        self.assertIsNone(ps.newest_live_code(tracks))

    def test_tracks_sorted(self):
        self.assertEqual([t["track"] for t in ps.sort_tracks(TRACKS)], ["internal", "production"])


class Summary(unittest.TestCase):
    def test_match_with_last_successful_run(self):
        run = {"number": 6, "conclusion": "success", "headSha": "abcdef123", "url": "u"}
        text = ps.summarize("com.x", ("1.0.1", "2"), TRACKS, run, run)
        self.assertIn("matches the last successful release run", text)
        self.assertIn("| internal | 1.0.1 (6) | 6 | completed |", text)
        self.assertNotIn("Draft", text)

    def test_draft_and_lag_are_flagged(self):
        tracks = [{"track": "internal", "releases": [
            {"versionCodes": ["6"], "status": "draft"},
            {"versionCodes": ["3"], "status": "completed"},
        ]}]
        run = {"number": 6, "conclusion": "success", "headSha": "abcdef123", "url": "u"}
        text = ps.summarize("com.x", ("1.0.1", "2"), tracks, run, run)
        self.assertIn("Draft on internal", text)
        self.assertIn("may still be a draft", text)

    def test_no_releases_and_no_runs(self):
        text = ps.summarize("com.x", ("1.0.0", "1"), [], None, None)
        self.assertIn("No releases found", text)
        self.assertIn("No `release` workflow run found", text)


if __name__ == "__main__":
    unittest.main()
