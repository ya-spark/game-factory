import contextlib
import io
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import new_game  # noqa: E402

ARGS = dict(game_id="my_game", name="My Game", package="com.yaspark.mygame", color="#112233")


class ValidationTest(unittest.TestCase):
    def test_bad_ids(self):
        for bad in ["MyGame", "my-game", "1game", "", "my game", "class", "flutter_game_template"]:
            with self.assertRaises(new_game.GenError, msg=bad):
                new_game.validate_id(bad)

    def test_bad_packages(self):
        for bad in ["mygame", "Com.yaspark.x", "com.1abc.x", "com..x", "com.yaspark.class",
                    "com.yaspark.flutter_game_template", "com.yaspark-x.y", ""]:
            with self.assertRaises(new_game.GenError, msg=bad):
                new_game.validate_package(bad)

    def test_bad_colors(self):
        for bad in ["112233", "#12345", "#GGGGGG", "red", "#1122334"]:
            with self.assertRaises(new_game.GenError, msg=bad):
                new_game.validate_color(bad)

    def test_bad_names(self):
        for bad in ["", "  ", 'a"b', "a#b", "a\nb"]:
            with self.assertRaises(new_game.GenError, msg=bad):
                new_game.validate_name(bad)

    def test_good(self):
        new_game.validate_id("my_game2")
        new_game.validate_package("com.yaspark.my_game")
        new_game.validate_color("#aBc123")
        new_game.validate_name("My Game: Deluxe")

    def test_cli_returns_error_code(self):
        with tempfile.TemporaryDirectory() as t, contextlib.redirect_stderr(io.StringIO()):
            rc = new_game.main(["--id", "Bad", "--name", "X", "--package", "com.a.b",
                                "--seed-color", "#000000", "--out", str(Path(t) / "o")])
        self.assertEqual(rc, 1)


class GenerateTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.registry = self.tmp / "apps.yaml"
        self.registry.write_text("# header\napps: []\n", encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def gen(self, out, register=False, **over):
        a = {**ARGS, **over}
        return new_game.generate(a["game_id"], a["name"], a["package"], a["color"], out,
                                 register, registry=self.registry)

    def test_successful_generation(self):
        out = self.tmp / "game"
        self.gen(out)
        cfg = (out / "app.config.yaml").read_text()
        self.assertIn("  id: my_game\n", cfg)
        self.assertIn('  display_name: "My Game"\n', cfg)
        self.assertIn("  package_name: com.yaspark.mygame\n", cfg)
        self.assertIn('  seed_color: "#112233"\n', cfg)
        self.assertIn("app_id: PLACEHOLDER_ADMOB_APP_ID", cfg)
        self.assertIn("app_id: PLACEHOLDER_PLAY_GAMES_APP_ID", cfg)
        self.assertIn("ca-app-pub-3940256099942544~3347511713", cfg)
        self.assertTrue((out / "pubspec.yaml").read_text().startswith("name: my_game\n"))
        self.assertIn('namespace = "com.yaspark.mygame"',
                      (out / "android/app/build.gradle.kts").read_text())
        kt = out / "android/app/src/main/kotlin/com/yaspark/mygame/MainActivity.kt"
        self.assertTrue(kt.is_file())
        self.assertIn("package com.yaspark.mygame", kt.read_text())
        self.assertFalse((out / "android/app/src/main/kotlin/com/example").exists())
        self.assertTrue((out / ".github/workflows/ci.yml").is_file())
        self.assertTrue((out / ".github/workflows/release.yml").is_file())
        dart = "".join(
            f.read_text()
            for d in [out / "lib", out / "test", out / "integration_test"]
            for f in d.rglob("*.dart")
        )
        self.assertIn("package:my_game/", dart)

    def test_no_leftovers_or_artifacts(self):
        out = self.tmp / "game"
        self.gen(out)
        for f in out.rglob("*"):
            self.assertNotIn("flutter_game_template", f.name)
            if f.is_file():
                try:
                    self.assertNotIn("flutter_game_template", f.read_text(encoding="utf-8"), f)
                except UnicodeDecodeError:
                    pass
            self.assertNotIn(f.name, {".dart_tool", ".idea", "local.properties"})
            self.assertFalse(f.name.endswith(".iml"))
        self.assertFalse((out / "build").exists())

    def test_refuses_non_empty_out(self):
        out = self.tmp / "game"
        out.mkdir()
        (out / "x.txt").write_text("hi")
        with self.assertRaises(new_game.GenError):
            self.gen(out)
        self.assertEqual([p.name for p in out.iterdir()], ["x.txt"])

    def test_allows_existing_empty_out(self):
        out = self.tmp / "game"
        out.mkdir()
        self.gen(out)
        self.assertTrue((out / "pubspec.yaml").is_file())

    def test_register_and_duplicate(self):
        self.gen(self.tmp / "g1", register=True)
        text = self.registry.read_text()
        self.assertNotIn("apps: []", text)
        self.assertIn("apps:\n  - id: my_game\n    repo: ya-spark/game-my-game\n"
                      "    package: com.yaspark.mygame\n    status: draft\n", text)
        with self.assertRaises(new_game.GenError):
            self.gen(self.tmp / "g2", register=True)
        self.assertFalse((self.tmp / "g2").exists())
        self.assertEqual(self.registry.read_text(), text)
        # second distinct game appends in list form
        self.gen(self.tmp / "g3", register=True, game_id="other_game",
                 package="com.yaspark.other")
        text = self.registry.read_text()
        self.assertEqual(text.count("  - id: "), 2)
        self.assertIn("ya-spark/game-other-game", text)
        ids, pkgs = new_game.registry_ids(text)
        self.assertEqual(ids, {"my_game", "other_game"})

    def test_duplicate_package_refused(self):
        self.gen(self.tmp / "g1", register=True)
        with self.assertRaises(new_game.GenError):
            self.gen(self.tmp / "g2", register=True, game_id="another")

    def test_without_register_leaves_registry(self):
        before = self.registry.read_text()
        self.gen(self.tmp / "g")
        self.assertEqual(self.registry.read_text(), before)


if __name__ == "__main__":
    unittest.main()
