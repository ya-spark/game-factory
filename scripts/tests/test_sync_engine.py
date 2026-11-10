import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import new_game  # noqa: E402
import sync_engine  # noqa: E402


class SyncEngineTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        registry = self.tmp / "apps.yaml"
        registry.write_text("apps: []\n", encoding="utf-8")
        self.game = self.tmp / "game"
        new_game.generate("my_game", "My Game", "com.yaspark.mygame", "#112233", self.game,
                          registry=registry, profile="craft")
        # a copy of the template that the test may change
        self.template = self.tmp / "template"
        import shutil
        shutil.copytree(new_game.TEMPLATE_DIR, self.template)

    def tearDown(self):
        self._tmp.cleanup()

    def check(self):
        return sync_engine.check_game(self.game, self.template)

    def test_fresh_game_is_in_sync(self):
        self.assertIsNone(self.check())

    def test_local_edit_is_reported(self):
        f = self.game / "lib/engine/engine.dart"
        f.write_text(f.read_text() + "// local\n")
        self.assertIn("edited locally", self.check())

    def test_template_change_makes_game_behind_then_sync_fixes_it(self):
        e = self.template / "lib/engine/engine.dart"
        e.write_text(e.read_text() + "// new\n")
        new_file = self.template / "lib/engine/extra.dart"
        new_file.write_text("import 'package:flutter_game_template/engine/engine.dart';\n")
        self.assertIn("behind", self.check())
        sync_engine.sync_game(self.game, self.template)
        self.assertIsNone(self.check())
        copied = (self.game / "lib/engine/extra.dart").read_text()
        self.assertEqual(copied, "import 'package:my_game/engine/engine.dart';\n")

    def test_stale_files_are_removed(self):
        stale = self.game / "lib/engine/old/stale.dart"
        stale.parent.mkdir(parents=True)
        stale.write_text("// stale\n")
        sync_engine.sync_game(self.game, self.template)
        self.assertFalse(stale.exists())
        self.assertFalse(stale.parent.exists())
        self.assertIsNone(self.check())

    def test_sync_overwrites_local_edit_and_leaves_other_files(self):
        (self.game / "lib/engine/engine.dart").write_text("// edited\n")
        other = self.game / "lib/ui/home_screen.dart"
        before = other.read_text()
        sync_engine.sync_game(self.game, self.template)
        self.assertEqual(other.read_text(), before)
        self.assertIsNone(self.check())

    def test_never_synced_game_is_behind(self):
        (self.game / "engine.lock").unlink()
        self.assertIn("behind", self.check())

    def test_refuses_the_template_itself(self):
        with self.assertRaises(sync_engine.SyncError):
            sync_engine.sync_game(self.template, self.template)

    def test_cli_check_exit_codes(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            self.assertEqual(sync_engine.main(["--check", str(self.game)]), 0)
        f = self.game / "tool/content_cli.dart"
        f.write_text(f.read_text() + "// x\n")
        with contextlib.redirect_stdout(out):
            self.assertEqual(sync_engine.main(["--check", str(self.game)]), 1)


if __name__ == "__main__":
    unittest.main()
