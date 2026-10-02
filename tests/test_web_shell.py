"""Static checks for the custom Godot Web export shell; no engine or browser."""

from html.parser import HTMLParser
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


SHELL = Path(__file__).resolve().parents[1] / "web" / "hero_shell.html"


class ShellParser(HTMLParser):
    def __init__(self, text):
        super().__init__(convert_charrefs=True)
        self.elements = []
        self.scripts = []
        self.styles = []
        self._script = None
        self._style = None
        self.feed(text)

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        self.elements.append((tag, attrs))
        if tag == "script":
            self._script = {"attrs": attrs, "text": ""}
            self.scripts.append(self._script)
        elif tag == "style":
            self._style = []
            self.styles.append(self._style)

    def handle_data(self, text):
        if self._script is not None:
            self._script["text"] += text
        if self._style is not None:
            self._style.append(text)

    def handle_endtag(self, tag):
        if tag == "script":
            self._script = None
        elif tag == "style":
            self._style = None


class WebShellTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SHELL.read_text(encoding="utf-8")
        cls.parsed = ShellParser(cls.text)
        cls.js = "\n".join(s["text"] for s in cls.parsed.scripts)

    def test_preserves_official_export_placeholders(self):
        expected = {
            "$GODOT_PROJECT_NAME", "$GODOT_SPLASH_COLOR", "$GODOT_HEAD_INCLUDE",
            "$GODOT_SPLASH_CLASSES", "$GODOT_SPLASH", "$GODOT_URL",
            "$GODOT_CONFIG", "$GODOT_THREADS_ENABLED",
        }
        self.assertEqual(set(re.findall(r"\$GODOT_[A-Z_]+", self.text)), expected)
        sources = [s["attrs"]["src"] for s in self.parsed.scripts if "src" in s["attrs"]]
        self.assertEqual(sources, ["$GODOT_URL"])
        self.assertRegex(self.js, r"new\s+Engine\(GODOT_CONFIG\)")
        self.assertRegex(self.js, r"Engine\.getMissingFeatures\(\{")
        self.assertRegex(self.js, r"threads:\s*GODOT_THREADS_ENABLED")

    def test_dependencies_are_only_generated_local_resources(self):
        urls = []
        for tag, attrs in self.parsed.elements:
            self.assertNotIn(tag, {"iframe", "object", "embed", "form"})
            for key in ("src", "href", "action", "poster", "srcset"):
                if key in attrs:
                    urls.append(attrs[key])
        self.assertCountEqual(urls, ["$GODOT_SPLASH", "$GODOT_URL"])
        self.assertNotRegex(self.text, r"(?i)(?:https?:)?//[\w.-]+(?:[/:]|\.[a-z])")
        self.assertNotRegex("".join("".join(style) for style in self.parsed.styles), r"(?i)@import|url\s*\(")
        self.assertNotRegex(self.js, r"\b(?:fetch|XMLHttpRequest|WebSocket|EventSource|sendBeacon)\b")

    def test_no_pwa_navigation_traps_or_key_interception(self):
        self.assertNotRegex(self.js, r"\b(?:serviceWorker|installServiceWorker|beforeunload|onbeforeunload|onkeydown|onkeyup)\b")
        self.assertNotRegex(self.js, r"addEventListener\(\s*['\"](?:keydown|keyup|keypress|unload|pagehide)['\"]")
        self.assertNotRegex(self.js, r"\b(?:location|history)\s*\.")
        self.assertNotRegex(self.js, r"\bpreventDefault\s*\(")

    def test_script_uses_safe_dom_and_existing_elements(self):
        ids = [attrs["id"] for _, attrs in self.parsed.elements if "id" in attrs]
        self.assertEqual(len(ids), len(set(ids)), "Duplicate element IDs")
        references = re.findall(r"getElementById\(['\"]([^'\"]+)['\"]\)", self.js)
        self.assertTrue(set(references).issubset(ids))
        self.assertNotRegex(self.js, r"\b(?:eval|Function)\s*\(|\.(?:innerHTML|outerHTML)\b|document\.write")
        for _, attrs in self.parsed.elements:
            self.assertFalse(any(name.lower().startswith("on") for name in attrs), "Inline event handler")
        self.assertIn("document.createTextNode(line)", self.js)

    def test_start_is_user_activated_and_guarded(self):
        buttons = [(tag, attrs) for tag, attrs in self.parsed.elements if attrs.get("id") == "status-start"]
        self.assertEqual(len(buttons), 1)
        self.assertEqual(buttons[0][0], "button")
        self.assertEqual(buttons[0][1].get("type"), "button")
        self.assertRegex(self.js, r"startButton\.addEventListener\(['\"]click['\"],\s*startGame,\s*\{\s*once:\s*true\s*\}\)")
        self.assertEqual(len(re.findall(r"engine\.startGame\s*\(", self.js)), 1)
        self.assertRegex(self.js, r"function startGame\(\)\s*\{\s*if \(started \|\| !initializing\)")
        self.assertIn("started = true;", self.js)
        self.assertIn("displayFailureNotice", self.js)
        self.assertIn("'onProgress'", self.js)

    def test_storage_status_is_boolean_text_only_and_persistent(self):
        self.assertRegex(self.js, r"window\.HeroWeb\s*=\s*Object\.freeze\(\{")
        self.assertRegex(self.js, r"setStorageAvailable:\s*function\s*\(available\)")
        self.assertRegex(self.js, r"typeof available !== ['\"]boolean['\"]")
        self.assertRegex(self.js, r"storageNotice\.dataset\.persistence\s*=\s*available\s*\?")
        self.assertRegex(self.js, r"storageNotice\.textContent\s*=\s*available\s*\?")
        self.assertNotRegex(self.js, r"storageNotice\.(?:remove|removeChild|replaceWith)\s*\(")
        notice = next(attrs for _, attrs in self.parsed.elements if attrs.get("id") == "storage-notice")
        self.assertEqual(notice.get("data-persistence"), "unknown")
        self.assertEqual(notice.get("role"), "status")
        self.assertEqual(notice.get("aria-live"), "polite")

    def test_javascript_parses_after_export_substitution(self):
        node = shutil.which("node")
        if node is None:
            self.skipTest("Node is unavailable; JavaScript syntax check not run")
        generated = self.js.replace("$GODOT_CONFIG", '{"executable":"index","args":[]}')
        generated = generated.replace("$GODOT_THREADS_ENABLED", "false")
        self.assertNotRegex(generated, r"\$GODOT_[A-Z_]+")
        with tempfile.TemporaryDirectory(prefix="hero-shell-syntax-") as directory:
            script = Path(directory) / "shell.js"
            script.write_text(generated, encoding="utf-8")
            result = subprocess.run([node, "--check", str(script)], capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
