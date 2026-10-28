import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import pipeline as pl  # noqa: E402


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.dir = Path(self._tmp.name)
        self.addCleanup(self._tmp.cleanup)

    def init(self, gid="g_one"):
        return pl.init(gid, "ya-spark/game-g-one", "com.x.y", self.dir, today="2026-01-01")

    def test_init_creates_nine_pending_stages(self):
        g = self.init()
        self.assertEqual(list(g["stages"]), pl.STAGE_IDS)
        self.assertEqual(len(pl.STAGE_IDS), 9)
        self.assertTrue(all(s["status"] == "pending" for s in g["stages"].values()))

    def test_init_rejects_bad_input_and_duplicates(self):
        with self.assertRaises(pl.PipelineError):
            pl.init("Bad-Id", "ya-spark/x", games_dir=self.dir)
        with self.assertRaises(pl.PipelineError):
            pl.init("ok", "not-a-repo", games_dir=self.dir)
        self.init()
        with self.assertRaises(pl.PipelineError):
            self.init()

    def test_next_walks_stages_in_order(self):
        self.init()
        seen = []
        for _ in range(9):
            n = pl.next_action(pl.all_games(self.dir))
            seen.append(n["stage"])
            pl.set_status("g_one", n["stage"], "done", games_dir=self.dir)
        self.assertEqual(seen, pl.STAGE_IDS)
        self.assertIsNone(pl.next_action(pl.all_games(self.dir)))

    def test_cannot_finish_a_stage_before_earlier_ones(self):
        self.init()
        with self.assertRaises(pl.PipelineError):
            pl.set_status("g_one", "coder", "done", games_dir=self.dir)
        with self.assertRaises(pl.PipelineError):
            pl.set_status("g_one", "repo", "in_progress", games_dir=self.dir)

    def test_blocked_and_awaiting_approval_stop_the_chain(self):
        self.init()
        pl.set_status("g_one", "spec", "awaiting_approval", games_dir=self.dir)
        self.assertIsNone(pl.next_action(pl.all_games(self.dir)))
        pl.set_status("g_one", "spec", "done", games_dir=self.dir)
        pl.set_status("g_one", "repo", "blocked", note="create the empty repo", games_dir=self.dir)
        self.assertIsNone(pl.next_action(pl.all_games(self.dir)))

    def test_note_is_cleared_when_status_changes_without_a_new_note(self):
        self.init()
        pl.set_status("g_one", "spec", "awaiting_approval", note="waiting", games_dir=self.dir)
        g = pl.set_status("g_one", "spec", "done", games_dir=self.dir)
        self.assertEqual(g["stages"]["spec"]["note"], "")
        g = pl.set_status("g_one", "repo", "pending", games_dir=self.dir)  # unchanged status
        self.assertEqual(g["stages"]["repo"]["note"], "")

    def test_blocked_needs_a_note(self):
        self.init()
        with self.assertRaises(pl.PipelineError):
            pl.set_status("g_one", "spec", "blocked", games_dir=self.dir)

    def test_skipped_counts_as_passed(self):
        self.init()
        pl.set_status("g_one", "spec", "skipped", note="sample", games_dir=self.dir)
        self.assertEqual(pl.next_action(pl.all_games(self.dir))["stage"], "repo")

    def test_in_progress_is_reported_as_resume(self):
        self.init()
        pl.set_status("g_one", "spec", "in_progress", games_dir=self.dir)
        n = pl.next_action(pl.all_games(self.dir))
        self.assertTrue(n["resume"])
        self.assertEqual(n["agent"], "spec-agent")

    def test_next_moves_to_second_game_when_first_is_blocked(self):
        self.init("g_one")
        self.init("g_two")
        pl.set_status("g_one", "spec", "blocked", note="needs user", games_dir=self.dir)
        self.assertEqual(pl.next_action(pl.all_games(self.dir))["game"], "g_two")

    def test_unknown_stage_status_and_game(self):
        self.init()
        with self.assertRaises(pl.PipelineError):
            pl.set_status("g_one", "nope", "done", games_dir=self.dir)
        with self.assertRaises(pl.PipelineError):
            pl.set_status("g_one", "spec", "weird", games_dir=self.dir)
        with self.assertRaises(pl.PipelineError):
            pl.load("missing", self.dir)

    def test_note_pr_and_date_are_recorded(self):
        self.init()
        g = pl.set_status("g_one", "spec", "done", note="ok", pr="https://x/pr/1",
                          games_dir=self.dir, today="2026-02-02")
        st = g["stages"]["spec"]
        self.assertEqual((st["note"], st["pr"], st["updated"]), ("ok", "https://x/pr/1", "2026-02-02"))
        self.assertIn("spec", pl.render(g))


if __name__ == "__main__":
    unittest.main()
