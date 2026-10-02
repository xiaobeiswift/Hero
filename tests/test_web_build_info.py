"""Build-time checks only; these do not assert actual WebGL gameplay."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("web_build_info", ROOT / "tools/web_build_info.py")
INFO = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(INFO)


class WebBuildInfoTests(unittest.TestCase):
    def test_runtime_project_is_the_version_source(self):
        self.assertEqual(INFO.project_version('[application]\nconfig/version="0.0.19"\n[display]\n'), '0.0.19')
        configured = next(line.split('"')[1] for line in (ROOT / 'project.godot').read_text().splitlines() if line.startswith('config/version='))
        self.assertEqual(INFO.read_project_version(ROOT / 'project.godot'), configured)
        for text in ('', '[application]\n', '[display]\nconfig/version="0.0.19"', '[application]\nconfig/version="bad"', '[application]\nconfig/version="1.0.0"\nconfig/version="1.0.1"'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                INFO.project_version(text)

    def test_stamp_and_deployment_identity_agree(self):
        page = '<html><body>' + INFO.BADGE + '</body></html>'
        built = INFO.stamp(page, '0.0.19', 2)
        self.assertEqual(INFO.validate(built, '0.0.19', 2), {'game_version': '0.0.19', 'web_revision': 2, 'caption': '0.0.19 · Web 2'})
        self.assertNotIn('构建信息待生成', built)
        self.assertIn('data-game-version="0.0.19"', built)
        self.assertIn('data-web-revision="2"', built)

    def test_missing_duplicate_or_restamped_badge_rejects(self):
        for page in ('', INFO.BADGE * 2, INFO.stamp(INFO.BADGE, '0.0.19', 1)):
            with self.subTest(page=page), self.assertRaises(ValueError):
                INFO.stamp(page, '0.0.19', 2)

    def test_invalid_revision_and_unsafe_version_reject(self):
        for revision in (0, -1, True, 1.5, '2', None):
            with self.subTest(revision=revision), self.assertRaises(ValueError):
                INFO.stamp(INFO.BADGE, '0.0.19', revision)
        for version in ('', '19', '1.0.0" onclick="bad', '<script>', None):
            with self.subTest(version=version), self.assertRaises(ValueError):
                INFO.stamp(INFO.BADGE, version, 2)

    def test_stale_revision_runtime_or_caption_rejects(self):
        built = INFO.stamp(INFO.BADGE, '0.0.19', 2)
        for changed in (built.replace('Web 2', 'Web 1'), built.replace('data-web-revision="2"', 'data-web-revision="1"'), built.replace('data-game-version="0.0.19"', 'data-game-version="0.0.20"'), built + built):
            with self.subTest(html=changed), self.assertRaises(ValueError):
                INFO.validate(changed, '0.0.19', 2)

    def test_real_shell_marker_is_unique(self):
        shell = (ROOT / 'web/hero_shell.html').read_text()
        self.assertEqual(shell.count(INFO.BADGE), 1)
        rendered = INFO.stamp(shell, '0.0.19', 2)
        self.assertEqual(INFO.validate(rendered, '0.0.19', 2)['caption'], '0.0.19 · Web 2')


if __name__ == '__main__':
    unittest.main()
