import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import new_game_package as ngp  # noqa: E402


class NewGamePackageTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.games = Path(self._tmp.name)

    def tearDown(self):
        self._tmp.cleanup()

    def test_writes_the_whole_package(self):
        out = ngp.generate("sky_hop", "Sky Hop", self.games)
        for rel in (
            "pubspec.yaml", "pubspec_overrides.yaml", "README.md", "docs/SPEC.md", "lib/sky_hop.dart",
            "lib/testing.dart", "lib/src/sky_hop_host.dart", "lib/src/sky_hop_ids.dart",
            "lib/src/sky_hop_screen.dart", "lib/src/rules/sky_hop_state.dart",
            "test/sky_hop_state_test.dart", "test/sky_hop_screen_test.dart",
        ):
            self.assertTrue((out / rel).is_file(), rel)
        self.assertIn("name: game_sky_hop\n", (out / "pubspec.yaml").read_text())
        self.assertIn("game_core: ^1.0.0", (out / "pubspec.yaml").read_text())
        self.assertIn("path: ../../game_core", (out / "pubspec_overrides.yaml").read_text())
        self.assertIn("class SkyHopServicesScope", (out / "lib/src/sky_hop_host.dart").read_text())
        self.assertIn("Sky Hop", (out / "docs/SPEC.md").read_text())

    def test_rules_stay_pure_dart(self):
        out = ngp.generate("sky_hop", "Sky Hop", self.games)
        self.assertNotIn("import", (out / "lib/src/rules/sky_hop_state.dart").read_text())

    def test_refusals(self):
        for gid, name in (("Sky", "x"), ("1sky", "x"), ("sky-hop", "x"), ("sky", ""), ("sky", 'a"b')):
            with self.assertRaises(ngp.GenError, msg=(gid, name)):
                ngp.generate(gid, name, self.games)
        ngp.generate("sky", "Sky", self.games)
        with self.assertRaises(ngp.GenError):
            ngp.generate("sky", "Sky", self.games)

    def test_cli(self):
        r = subprocess.run(
            [sys.executable, str(Path(ngp.__file__)), "--id", "cli_game", "--name", "Cli Game",
             "--out", str(self.games)], capture_output=True, text=True)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.games / "cli_game/lib/cli_game.dart").is_file())

    @unittest.skipUnless(shutil.which("flutter") and (ngp.REPO_ROOT / "game_core").is_dir(), "needs flutter")
    def test_generated_package_analyses_and_tests_clean(self):
        # Generated inside games/ so ../../game_core resolves; removed afterwards.
        out = ngp.generate("zz_probe_game", "Probe Game", ngp.GAMES_DIR)
        try:
            for cmd in (["flutter", "pub", "get"], ["dart", "format", "--set-exit-if-changed", "."],
                        ["flutter", "analyze"], ["flutter", "test"]):
                r = subprocess.run(cmd, cwd=out, capture_output=True, text=True)
                self.assertEqual(r.returncode, 0, f"{cmd}: {r.stdout[-1500:]}{r.stderr[-500:]}")
        finally:
            shutil.rmtree(out, ignore_errors=True)


if __name__ == "__main__":
    unittest.main()
