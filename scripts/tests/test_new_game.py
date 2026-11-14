import contextlib
import io
import shutil
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
        self.assertTrue((out / ".github/workflows/check-code.yml").is_file())
        self.assertTrue((out / ".github/workflows/release-to-closed-testing.yml").is_file())
        dart = "".join(
            f.read_text()
            for d in [out / "lib", out / "test", out / "integration_test"]
            for f in d.rglob("*.dart")
        )
        self.assertIn("package:my_game/", dart)

    def test_web_shell_is_generated_for_the_game(self):
        out = self.tmp / "game"
        self.gen(out)
        idx = (out / "web/index.html").read_text()
        self.assertIn("<title>My Game</title>", idx)
        self.assertIn('<meta name="theme-color" content="#112233">', idx)
        self.assertIn('property="og:title" content="My Game"', idx)
        self.assertIn('id="loading"', idx)
        self.assertIn('content="noindex, nofollow"', idx)
        self.assertNotIn("test copy", idx.lower())
        self.assertNotIn("Get the Android app", idx)
        man = (out / "web/manifest.json").read_text()
        self.assertIn('"name": "My Game"', man)
        self.assertNotIn("test copy", man.lower())
        self.assertTrue((out / "scripts/web_shell.py").is_file())
        # idempotent
        import subprocess
        r = subprocess.run([sys.executable, str(out / "scripts/web_shell.py"), str(out), "--check"])
        self.assertEqual(r.returncode, 0)

    def test_features_and_docs_are_carried(self):
        out = self.tmp / "game"
        self.gen(out)
        self.assertTrue((out / "lib/ui/game_over_panel.dart").is_file())
        self.assertTrue((out / "lib/core/purchase/parent_gate_guard.dart").is_file())
        self.assertIn("coins_4000", (out / "products.yaml").read_text())
        self.assertIn("# My Game: game spec\n", (out / "docs/SPEC.md").read_text())
        new_game.check_features(out)
        (out / "lib/ui/parent_gate.dart").unlink()
        with self.assertRaises(new_game.GenError):
            new_game.check_features(out)

    def test_no_leftovers_or_artifacts(self):
        out = self.tmp / "game"
        self.gen(out)
        for f in out.rglob("*"):
            self.assertNotIn("flutter_game_template", f.name)
            if f.is_file() and f.name != "engine_lock.py":
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


class ProfileTest(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.tmp = Path(self._tmp.name)
        self.registry = self.tmp / "apps.yaml"
        self.registry.write_text("apps: []\n", encoding="utf-8")

    def tearDown(self):
        self._tmp.cleanup()

    def gen(self, name="g", **kw):
        out = self.tmp / name
        a = dict(ARGS)
        a.update(kw.pop("over", {}))
        new_game.generate(a["game_id"], a["name"], a["package"], a["color"], out,
                          registry=self.registry, **kw)
        return out

    def test_defaults_are_puzzle_adult_ci_off(self):
        out = self.gen()
        self.assertTrue((out / "lib/game/rules").is_dir())
        self.assertTrue((out / "lib/ui/game_screen.dart").is_file())
        self.assertIn("audience: adult", (out / "app.config.yaml").read_text())
        self.assertIn(new_game.CI_GUARD, (out / ".github/workflows/check-code.yml").read_text())

    def test_craft_child_strips_puzzle_and_sets_config(self):
        out = self.gen(profile="craft", audience="child")
        for rel in new_game.PUZZLE_ONLY_PATHS:
            self.assertFalse((out / rel).exists(), rel)
        self.assertTrue((out / "lib/game/tips.dart").is_file())
        self.assertTrue((out / "lib/ui/share_card.dart").is_file())
        home = (out / "lib/ui/home_screen.dart").read_text()
        self.assertNotIn("game_screen", home)
        self.assertIn("TestIds.homeHub", home)
        self.assertIn("homeHub", (out / "lib/ui/test_ids.dart").read_text())
        cfg = (out / "app.config.yaml").read_text()
        for line in ("audience: child", "  child_directed: true", "  max_ad_content_rating: G",
                     "  rewarded_enabled: false", "  enabled: true # learning games"):
            self.assertIn(line, cfg)
        self.assertIn("  coin_price: 200", cfg)
        self.assertIn("  stars:\n    enabled: true", cfg)
        new_game.check_features(out, "craft")

    def test_mind_hub_has_no_learning_content(self):
        cfg = (self.gen(profile="mind", audience="adult") / "app.config.yaml").read_text()
        self.assertIn("  enabled: false # learning games", cfg)

    def test_craft_bundles_the_packs_folder(self):
        for audience in ("child", "teen"):
            out = self.gen(name=f"c-{audience}", profile="craft", audience=audience)
            pubspec = (out / "pubspec.yaml").read_text()
            self.assertEqual(pubspec.count("    - assets/content/packs/\n"), 1)
            self.assertIn("    - assets/content/\n", pubspec)
            self.assertIn("assets/content/packs/.gitkeep", (out / "assets/LICENSES.md").read_text())
            self.assertTrue((out / "assets/content/packs").is_dir())

    def test_hubs_and_puzzle_do_not_list_the_packs_folder(self):
        for kw in (dict(profile="mind", audience="adult"), dict()):
            out = self.gen(name="h", **kw)
            self.assertNotIn("assets/content/packs/", (out / "pubspec.yaml").read_text())
            self.assertFalse((out / "assets/content/packs").exists())
            shutil.rmtree(out)

    def test_craft_teen(self):
        cfg = (self.gen(profile="craft", audience="teen") / "app.config.yaml").read_text()
        self.assertIn("audience: teen", cfg)
        self.assertIn("  child_directed: true", cfg)
        self.assertIn("  max_ad_content_rating: PG", cfg)
        self.assertIn("  rewarded_enabled: false", cfg)

    def check_design(self, out, design_id, family, font_files, other_font, has_art):
        """Only this game's design files are copied; every file is licensed; pubspec lists them."""
        self.assertFalse((out / "design").exists())
        d = out / "assets/design"
        self.assertTrue((d / "tokens.json").is_file())
        self.assertEqual(sorted(p.name for p in d.iterdir() if p.is_dir()), sorted(["icons", design_id]))
        self.assertTrue((d / design_id / "tokens.json").is_file())
        self.assertEqual((d / design_id / "art").is_dir(), has_art)
        self.assertTrue((d / "icons" / "coin.svg").is_file())
        for f in font_files:
            self.assertTrue((out / "assets/fonts" / f).is_file(), f)
        self.assertFalse((out / "assets/fonts" / other_font).exists())
        pub = (out / "pubspec.yaml").read_text()
        self.assertIn("    - assets/design/\n", pub)
        self.assertIn(f"    - assets/design/{design_id}/\n", pub)
        self.assertIn(f"    - family: {family}\n", pub)
        self.assertIn(f"  design: {design_id}\n", (out / "app.config.yaml").read_text())
        lic = (out / "assets/LICENSES.md").read_text()
        for f in (out / "assets").rglob("*"):
            if f.is_file() and f.name != "LICENSES.md":
                self.assertIn(str(f.relative_to(out)), lic)
        self.assertIn("SIL OFL 1.1", lic)
        # no person-like names in what was copied
        for f in d.rglob("*.svg"):
            for bad in ("person", "user", "face", "human", "avatar"):
                self.assertNotIn(bad, f.name)

    def test_craft_copies_its_design_files(self):
        out = self.gen(profile="craft", audience="child", over={"game_id": "craft_lowteen"})
        self.check_design(out, "craft_lowteen", "Nunito", ["Nunito-Variable.ttf"],
                          "PlusJakartaSans-Bold.ttf", True)
        self.assertFalse((out / "assets/design/craft_preteen").exists())
        # variable font: one file, no weight entries
        self.assertNotIn("weight: 400", (out / "pubspec.yaml").read_text())

    def test_mind_copies_its_design_files(self):
        out = self.gen(profile="mind", audience="adult", over={"game_id": "mind_1"})
        self.check_design(out, "mind_1", "Plus Jakarta Sans",
                          ["PlusJakartaSans-Regular.ttf", "PlusJakartaSans-Bold.ttf",
                           "PlusJakartaSans-ExtraBold.ttf"], "Nunito-Variable.ttf", True)
        pub = (out / "pubspec.yaml").read_text()
        for w in ("400", "700", "800"):
            self.assertIn(f"weight: {w}", pub)

    def test_plain_puzzle_has_no_design_unless_asked(self):
        out = self.gen()
        self.assertFalse((out / "design").exists())
        self.assertFalse((out / "assets/design").exists())
        self.assertNotIn("\n  design:", (out / "app.config.yaml").read_text())
        out2 = self.gen("g2", design="mind_9")
        self.assertTrue((out2 / "assets/design/mind_9/tokens.json").is_file())

    def test_sample_ids_get_the_profile_default_design(self):
        """CI samples (sample_craft_child ...) are not app ids: the profile and audience pick the look."""
        for profile, audience, want in (("craft", "child", "craft_lowteen"), ("craft", "teen", "craft_highteen"),
                                        ("mind", "adult", "mind_1")):
            out = self.gen(f"s_{want}", profile=profile, audience=audience)
            self.assertTrue((out / f"assets/design/{want}/tokens.json").is_file(), want)
            for rel in ("test/ui/theme/design_theme_test.dart", "test/ui/kit/kit_test.dart",
                        "test/ui/themed_screens_test.dart"):
                self.assertTrue((out / rel).is_file(), f"{want}: {rel}")

    def test_plain_puzzle_drops_the_design_tests(self):
        out = self.gen()
        for rel in ("test/ui/theme/design_theme_test.dart", "test/ui/kit/kit_test.dart",
                    "test/ui/themed_screens_test.dart"):
            self.assertFalse((out / rel).exists(), rel)
        for f in (out / "test").rglob("*_test.dart"):
            self.assertNotIn("kit/kit_test.dart", f.read_text(), str(f))
        out2 = self.gen("g3", design="mind_9")
        self.assertTrue((out2 / "test/ui/kit/kit_test.dart").is_file())

    def test_unknown_design_refused(self):
        with self.assertRaises(new_game.GenError):
            self.gen(design="nope")

    def test_mind_adult(self):
        cfg = (self.gen(profile="mind", audience="adult") / "app.config.yaml").read_text()
        self.assertIn("audience: adult", cfg)
        self.assertIn("  child_directed: false", cfg)
        self.assertIn("  max_ad_content_rating: PG", cfg)
        self.assertIn("  rewarded_enabled: true", cfg)
        self.assertIn("  coin_price: 300", cfg)
        self.assertIn("  stars:\n    enabled: false", cfg)
        self.assertIn("  enabled: false # learning games", cfg)

    def test_profile_defaults_for_audience(self):
        self.assertIn("audience: child",
                      (self.gen("a", profile="craft") / "app.config.yaml").read_text())
        self.assertIn("audience: adult",
                      (self.gen("b", profile="mind") / "app.config.yaml").read_text())

    def test_bad_combinations_refused(self):
        for kw in (dict(profile="mind", audience="child"), dict(profile="craft", audience="adult"),
                   dict(profile="x"), dict(audience="kid"), dict(ci="maybe"),
                   dict(repo="no-slash")):
            with self.assertRaises(new_game.GenError, msg=str(kw)):
                self.gen(**kw)
            self.assertFalse((self.tmp / "g").exists())

    def test_ci_guard_default_and_on(self):
        guarded = (self.gen("a") / ".github/workflows/check-code.yml").read_text()
        self.assertIn("  check:\n    name: analyze, format, tests, safety checks\n    if: "
                      "${{ vars.CI_ENABLED == 'true' }}\n", guarded)
        plain = (self.gen("b", ci="on") / ".github/workflows/check-code.yml").read_text()
        self.assertNotIn("CI_ENABLED", plain)
        self.assertEqual(plain, (new_game.TEMPLATE_DIR / ".github/workflows/check-code.yml").read_text())

    def test_template_callers_point_at_existing_shared_workflows(self):
        import re
        callers = sorted((new_game.TEMPLATE_DIR / ".github/workflows").glob("*.yml"))
        self.assertEqual(4, len(callers))
        for f in callers:
            uses = re.findall(r"uses: ya-spark/game-factory/\.github/workflows/(\S+)@main", f.read_text())
            self.assertEqual(1, len(uses), f.name)
            self.assertTrue((new_game.REPO_ROOT / ".github/workflows" / uses[0]).is_file(), uses[0])

    def test_ci_yaml_is_valid(self):
        try:
            import yaml  # type: ignore
        except ImportError:
            self.skipTest("PyYAML not installed")
        for ci in ("on", "off"):
            wf = yaml.safe_load((self.gen(ci, ci=ci) / ".github/workflows/check-code.yml").read_text())
            self.assertIn("check", wf["jobs"])
            self.assertEqual("if" in wf["jobs"]["check"], ci == "off")

    def test_template_ci_is_unchanged_by_generation(self):
        before = (new_game.TEMPLATE_DIR / ".github/workflows/check-code.yml").read_text()
        self.gen()
        self.assertEqual(before, (new_game.TEMPLATE_DIR / ".github/workflows/check-code.yml").read_text())

    def test_repo_override_in_registry(self):
        self.gen("a", register=True, repo="someone/custom-name") if False else None
        out = self.tmp / "a"
        new_game.generate("my_game", "My Game", "com.yaspark.mygame", "#112233", out,
                          do_register=True, registry=self.registry, repo="someone/custom-name")
        self.assertIn("    repo: someone/custom-name\n", self.registry.read_text())

    def test_engine_lock_is_written_and_checks(self):
        out = self.gen(profile="craft")
        self.assertTrue((out / "engine.lock").is_file())
        spec = new_game.importlib.util.spec_from_file_location("el", out / "scripts/engine_lock.py")
        el = new_game.importlib.util.module_from_spec(spec)
        spec.loader.exec_module(el)
        self.assertEqual(el.check(out), 0)
        (out / "lib/engine/engine.dart").write_text("// edited\n")
        with contextlib.redirect_stderr(io.StringIO()):
            self.assertEqual(el.check(out), 1)

    def test_engine_hash_is_package_independent(self):
        a = self.gen("a")
        b = self.gen("b", over=dict(game_id="other_game", package="com.yaspark.other"))
        self.assertEqual((a / "engine.lock").read_text(), (b / "engine.lock").read_text())
        self.assertEqual((a / "engine.lock").read_text(),
                         (new_game.TEMPLATE_DIR / "engine.lock").read_text())


if __name__ == "__main__":
    unittest.main()
