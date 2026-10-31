#!/usr/bin/env python3
"""Unit tests for scripts/play_promote.py (no network, no Google libraries needed)."""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import play_promote as pp  # noqa: E402

REL = [
    {"versionCodes": ["3"], "status": "completed", "name": "1.0.0 (3)", "releaseNotes": [{"language": "en-US", "text": "a"}]},
    {"versionCodes": ["5"], "status": "completed"},
    {"versionCodes": ["7"], "status": "draft"},
]


class PickRelease(unittest.TestCase):
    def test_newest_rolled_out_release_ignoring_drafts(self):
        self.assertEqual(pp.pick_release(REL)["versionCodes"], ["5"])

    def test_specific_version_code(self):
        self.assertEqual(pp.pick_release(REL, 3)["name"], "1.0.0 (3)")

    def test_draft_version_code_is_refused(self):
        with self.assertRaises(pp.PromoteError):
            pp.pick_release(REL, 7)

    def test_unknown_version_code_lists_available(self):
        with self.assertRaises(pp.PromoteError) as ctx:
            pp.pick_release(REL, 99)
        self.assertIn("3, 5", str(ctx.exception))

    def test_only_drafts_is_refused(self):
        with self.assertRaises(pp.PromoteError):
            pp.pick_release([{"versionCodes": ["7"], "status": "draft"}])

    def test_empty_track_is_refused(self):
        with self.assertRaises(pp.PromoteError):
            pp.pick_release([])


class BuildRelease(unittest.TestCase):
    def test_copies_code_name_and_notes(self):
        r = pp.build_release(REL[0], "draft", 0.1)
        self.assertEqual(r["versionCodes"], ["3"])
        self.assertEqual(r["name"], "1.0.0 (3)")
        self.assertEqual(r["releaseNotes"][0]["text"], "a")
        self.assertEqual(r["status"], "draft")
        self.assertNotIn("userFraction", r)

    def test_staged_rollout_sets_fraction(self):
        self.assertEqual(pp.build_release(REL[1], "inProgress", 0.2)["userFraction"], 0.2)

    def test_staged_rollout_rejects_bad_fraction(self):
        for bad in (0, 1, 1.5, -0.1):
            with self.assertRaises(pp.PromoteError):
                pp.build_release(REL[1], "inProgress", bad)

    def test_rejects_unknown_status(self):
        with self.assertRaises(pp.PromoteError):
            pp.build_release(REL[1], "halted", 0.1)


class ParseVersionCode(unittest.TestCase):
    def test_empty_means_newest(self):
        self.assertIsNone(pp.parse_version_code(""))
        self.assertIsNone(pp.parse_version_code("  "))

    def test_number(self):
        self.assertEqual(pp.parse_version_code(" 12 "), 12)

    def test_rejects_non_numbers(self):
        for bad in ("1.0", "abc", "5; rm -rf /", "-3"):
            with self.assertRaises(pp.PromoteError):
                pp.parse_version_code(bad)


if __name__ == "__main__":
    unittest.main()
