"""Static and isolated JS checks for the Web shell; no engine or browser."""

from html.parser import HTMLParser
from pathlib import Path
import json
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

    def test_actual_shell_startup_branches_with_dom_stubs(self):
        """Execute the exported shell logic; this is not a WebGL/browser test."""
        node = shutil.which("node")
        if node is None:
            self.skipTest("Node is unavailable; shell branch execution not run")
        generated = self.js.replace("$GODOT_CONFIG", '{"executable":"index","args":[]}')
        generated = generated.replace("$GODOT_THREADS_ENABLED", "false")
        runner = r"""
const vm = require('node:vm');
const shell = SHELL_SOURCE;
async function run(missing, mode = 'ready') {
    const nodes = {};
    for (const id of ['canvas', 'storage-notice', 'build-notice', 'status', 'status-progress', 'status-notice', 'status-caption', 'status-start']) {
        nodes[id] = {
            style: {}, dataset: {}, textContent: '', children: [], events: {}, removed: false,
            get lastChild() { return this.children.at(-1); },
            appendChild(child) { this.children.push(child); },
            removeChild(child) { this.children.splice(this.children.indexOf(child), 1); },
            remove() { this.removed = true; }, focus() { this.focused = true; },
            removeAttribute() {}, addEventListener(name, callback) { this.events[name] = callback; },
        };
    }
    nodes['build-notice'].dataset = {gameVersion: '0.0.19', webRevision: '2'};
    const pageWindow = {};
    let constructed = 0, started = 0;
    class Engine {
        static getMissingFeatures() { return missing; }
        constructor() { constructed++; }
        startGame() {
            started++;
            if (mode === 'reject') return Promise.reject(new Error('index.pck download failed'));
            if (mode === 'throw') throw new Error('engine initialization failed');
            return Promise.resolve();
        }
    }
    vm.runInNewContext(shell, {
        Engine: mode === 'missing-script' ? undefined : Engine, Error,
        window: pageWindow, console: { error() {} },
        document: {
            getElementById(id) { return nodes[id]; },
            createTextNode(text) { return {text}; }, createElement() { return {text: '\n'}; },
        },
    });
    const beforeClick = started;
    if (mode !== 'ready' && nodes['status-start'].events.click) nodes['status-start'].events.click();
    await new Promise(setImmediate);
    return {
        caption: nodes['status-caption'].textContent,
        notice: nodes['status-notice'].children.map(child => child.text).join(''),
        noticeDisplay: nodes['status-notice'].style.display,
        startDisplay: nodes['status-start'].style.display,
        overlayRemoved: nodes.status.removed, canvasFocused: !!nodes.canvas.focused,
        storageRemoved: nodes['storage-notice'].removed,
        buildRemoved: nodes['build-notice'].removed,
        buildInfo: JSON.parse(pageWindow.HeroWeb.getBuildInfo()),
        constructed, beforeClick, started,
    };
}
(async () => console.log(JSON.stringify({
    graphics: await run(['WebGL2 - Check web browser configuration and hardware support']),
    other: await run(['WebAssembly']),
    script: await run([], 'missing-script'),
    download: await run([], 'reject'),
    thrown: await run([], 'throw'),
    ready: await run([]),
    started: await run([], 'success'),
})))();
""".replace("SHELL_SOURCE", json.dumps(generated))
        result = subprocess.run([node, "-e", runner], capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        cases = json.loads(result.stdout)
        graphics = cases["graphics"]
        self.assertIn("无法提供 WebGL 2 图形功能", graphics["caption"])
        self.assertIn("支持 WebGL 2 的桌面浏览器", graphics["notice"])
        self.assertIn("WebGL2 - Check web browser configuration", graphics["notice"])
        for name in ("graphics", "other", "script"):
            with self.subTest(branch=name):
                self.assertEqual(cases[name]["constructed"], 0)
                self.assertEqual(cases[name]["started"], 0)
                self.assertEqual(cases[name]["startDisplay"], "none")
                self.assertEqual(cases[name]["noticeDisplay"], "block")
                self.assertFalse(cases[name]["storageRemoved"])
        self.assertNotIn("WebGL", cases["other"]["caption"])
        self.assertIn("WebAssembly", cases["other"]["notice"])
        self.assertIn("启动脚本未能加载", cases["script"]["notice"])
        for name in ("graphics", "other", "download", "thrown"):
            with self.subTest(branch=name):
                self.assertNotIn("上传", cases[name]["caption"])
        for name, error in (("download", "index.pck download failed"), ("thrown", "engine initialization failed")):
            with self.subTest(branch=name):
                self.assertIn(error, cases[name]["notice"])
                self.assertEqual(cases[name]["started"], 1)
                self.assertEqual(cases[name]["noticeDisplay"], "block")
                self.assertFalse(cases[name]["overlayRemoved"])
        self.assertEqual(cases["ready"]["beforeClick"], 0)
        self.assertEqual(cases["ready"]["startDisplay"], "inline-block")
        self.assertEqual(cases["started"]["beforeClick"], 0)
        self.assertEqual(cases["started"]["started"], 1)
        self.assertTrue(cases["started"]["overlayRemoved"])
        self.assertTrue(cases["started"]["canvasFocused"])
        self.assertFalse(cases["started"]["storageRemoved"])
        for result in cases.values():
            self.assertFalse(result["buildRemoved"])
            self.assertEqual(result["buildInfo"], {"game_version": "0.0.19", "web_revision": "2"})

    def test_version_badge_is_outside_loading_overlay_and_controls(self):
        self.assertLess(self.text.index('id="build-notice"'), self.text.index('<div id="status">'))
        self.assertIn('padding: 0 156px 0 8px;', self.text)
        style = re.search(r'#build-notice\s*\{([^}]+)\}', self.text).group(1)
        for rule in ('position: fixed', 'top: 0', 'height: 20px', 'pointer-events: none'):
            self.assertIn(rule, style)
        self.assertNotRegex(self.js, r"buildNotice\.(?:remove|removeChild|replaceWith)\s*\(")


if __name__ == "__main__":
    unittest.main()
