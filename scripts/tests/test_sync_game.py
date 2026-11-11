import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import sync_game as sg  # noqa: E402


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", "-C", str(repo), *args], check=True, capture_output=True)


class SyncGameTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        root = Path(self._tmp.name)
        self.src, self.hub = root / "src", root / "hub"
        (self.src / "lib/game").mkdir(parents=True)
        (self.src / "lib/core").mkdir(parents=True)
        (self.src / "test/game").mkdir(parents=True)
        (self.src / "pubspec.yaml").write_text("name: toy\n")
        (self.src / "lib/game/a.dart").write_text(
            "import 'package:toy/game/b.dart';\nimport 'package:flutter/material.dart';\n"
            "import '../core/svc.dart';\n"
        )
        (self.src / "lib/game/b.dart").write_text("const b = 1;\n")
        (self.src / "lib/core/svc.dart").write_text("class Svc {}\n")
        (self.src / "test/game/a_test.dart").write_text(
            "import 'package:toy/game/a.dart';\nconst p = 'lib/game/a.dart';\n"
        )
        (self.hub / "lib").mkdir(parents=True)
        (self.hub / "pubspec.yaml").write_text("name: hub\n")
        _git(self.src, "init", "-q")
        _git(self.src, "-c", "user.name=t", "-c", "user.email=t@t", "add", ".")
        _git(self.src, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qm", "x")
        sg.GAMES["toy"] = {
            "copy": ["lib/game", "test/game"],
            "host": {"lib/core/svc.dart": "svc.dart"},
        }

    def tearDown(self):
        sg.GAMES.pop("toy", None)
        self._tmp.cleanup()

    def test_sync_rewrites_imports_and_locks(self):
        sg.sync(self.src, self.hub, "toy")
        a = (self.hub / "lib/games/toy/game/a.dart").read_text()
        self.assertIn("package:hub/games/toy/game/b.dart", a)
        self.assertIn("package:flutter/material.dart", a)
        self.assertIn("package:hub/games/toy/host/svc.dart", a)
        t = (self.hub / "test/games/toy/game/a_test.dart").read_text()
        self.assertIn("'lib/games/toy/game/a.dart'", t)
        lock = json.loads((self.hub / "lib/games/toy/game.lock").read_text())
        self.assertEqual(lock["commit"], sg.source_commit(self.src))
        self.assertIsNone(sg.check(self.src, self.hub, "toy"))

    def test_check_reports_local_edit_and_behind(self):
        self.assertIn("never synced", sg.check(self.src, self.hub, "toy"))
        sg.sync(self.src, self.hub, "toy")
        (self.hub / "lib/games/toy/game/b.dart").write_text("const b = 2;\n")
        self.assertIn("edited locally", sg.check(self.src, self.hub, "toy"))
        sg.sync(self.src, self.hub, "toy")
        (self.src / "lib/game/b.dart").write_text("const b = 3;\n")
        _git(self.src, "-c", "user.name=t", "-c", "user.email=t@t", "commit", "-qam", "y")
        self.assertIn("behind", sg.check(self.src, self.hub, "toy"))

    def test_unmapped_import_is_an_error(self):
        sg.GAMES["toy"]["host"] = {}
        with self.assertRaises(sg.SyncError):
            sg.sync(self.src, self.hub, "toy")

    def test_removed_source_file_is_removed_from_hub(self):
        sg.sync(self.src, self.hub, "toy")
        (self.src / "lib/game/b.dart").unlink()
        (self.src / "lib/game/a.dart").write_text("const a = 1;\n")
        sg.sync(self.src, self.hub, "toy")
        self.assertFalse((self.hub / "lib/games/toy/game/b.dart").exists())


if __name__ == "__main__":
    unittest.main()
