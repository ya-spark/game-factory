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


if __name__ == "__main__":
    unittest.main()
