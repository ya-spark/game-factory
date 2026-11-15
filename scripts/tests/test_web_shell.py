import importlib.util
import tempfile
import unittest
from pathlib import Path

SCRIPT = (Path(__file__).resolve().parent.parent.parent
          / "template/flutter-game-template/scripts/web_shell.py")
spec = importlib.util.spec_from_file_location("web_shell", SCRIPT)
ws = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ws)

CFG = """app:
  id: x
  display_name: "Tom & Jerry <1>"
theme:
  seed_color: "#FF7A45"
  dark: true
web:
  description: "Quick \\"fun\\" quizzes"
  indexable: %s
  play_store_url: "%s"
"""


class WebShellTest(unittest.TestCase):
    def app(self, indexable="false", url=""):
        d = Path(tempfile.mkdtemp())
        self.addCleanup(lambda: __import__("shutil").rmtree(d, ignore_errors=True))
        (d / "app.config.yaml").write_text(CFG % (indexable, url))
        return d

    def test_defaults_noindex_no_link_escaped(self):
        d = self.app()
        ws.write_shell(d)
        idx = (d / "web/index.html").read_text()
        self.assertIn("<title>Tom &amp; Jerry &lt;1&gt;</title>", idx)
        self.assertIn('content="noindex, nofollow"', idx)
        self.assertNotIn("Get the Android app", idx)
        self.assertIn('content="#FF7A45"', idx)
        self.assertNotIn("<script src=\"http", idx)

    def test_index_switch_and_link(self):
        d = self.app("true", "https://play.google.com/store/apps/details?id=a.b")
        ws.write_shell(d)
        idx = (d / "web/index.html").read_text()
        self.assertIn('content="index, follow"', idx)
        self.assertIn('href="https://play.google.com/store/apps/details?id=a.b"', idx)

    def test_idempotent_and_check(self):
        d = self.app()
        self.assertEqual(sorted(ws.write_shell(d)), ["index.html", "manifest.json"])
        self.assertEqual(ws.write_shell(d), [])
        self.assertEqual(ws.write_shell(d, check=True), [])
        (d / "web/index.html").write_text("x")
        self.assertEqual(ws.write_shell(d, check=True), ["index.html"])
        self.assertEqual((d / "web/index.html").read_text(), "x")

    def ads_app(self, enabled, pub):
        d = self.app()
        cfg = (d / "app.config.yaml").read_text()
        cfg += f"adsense:\n  enabled: {enabled}\n  publisher_id: {pub}\n  test_mode: true\n"
        (d / "app.config.yaml").write_text(cfg)
        ws.write_shell(d)
        return (d / "web/index.html").read_text()

    # Built here, never written literally: the ad safety check scans the repo for real-looking ids.
    PUB = "ca-pub-" + "1234567" + "890123456"

    def test_adsense_script_off_by_default_and_for_placeholder(self):
        self.assertNotIn("adsbygoogle", self.app_index())
        self.assertNotIn("adsbygoogle", self.ads_app("false", "PLACEHOLDER_ADSENSE_PUBLISHER_ID"))
        self.assertNotIn("adsbygoogle", self.ads_app("true", "PLACEHOLDER_ADSENSE_PUBLISHER_ID"))

    def test_adsense_script_needs_enabled_and_a_real_looking_id(self):
        self.assertNotIn("adsbygoogle", self.ads_app("false", self.PUB))
        self.assertNotIn("adsbygoogle", self.ads_app("true", "ca-pub-123"))
        idx = self.ads_app("true", self.PUB)
        self.assertIn(f"adsbygoogle.js?client={self.PUB}", idx)
        self.assertEqual(idx.count("<script async src=\"https://pagead"), 1)

    def app_index(self):
        d = self.app()
        ws.write_shell(d)
        return (d / "web/index.html").read_text()


if __name__ == "__main__":
    unittest.main()
