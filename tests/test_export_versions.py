"""Bundle labels must follow the frozen project, without mutating signed outputs."""
import hashlib
import importlib.util
from pathlib import Path
import plistlib
import re
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location("export_versions", Path(__file__).resolve().parents[1] / "tools/export_desktop.py")
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class ExportVersionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hero-export-version-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        (self.root / "project.godot").write_text('; Godot project\nconfig_version=5\n[application]\nconfig/version="0.0.17"\n')
        self.presets()

    def presets(self, short="0.0.17", build="0.0.17"):
        (self.root / "export_presets.cfg").write_text('[preset.2]\nname="macOS Universal"\n[preset.2.options]\napplication/short_version="' + short + '"\napplication/version="' + build + '"\n')

    def bundle(self, short="0.0.17", build="0.0.17", duplicate=False):
        path = self.root / "Hero.zip"
        with zipfile.ZipFile(path, "w") as archive:
            payload = plistlib.dumps({"CFBundleShortVersionString": short, "CFBundleVersion": build})
            archive.writestr("Hero.app/Contents/Info.plist", payload)
            if duplicate:
                archive.writestr("Other.app/Contents/Info.plist", payload)
        return path

    def test_matching_source_is_read_only(self):
        before = {p.name: p.read_bytes() for p in self.root.iterdir()}
        self.assertEqual(EXPORT.validate_macos_version(self.root), "0.0.17")
        self.assertEqual(before, {p.name: p.read_bytes() for p in self.root.iterdir()})

    def test_each_stale_setting_rejects(self):
        for short, build in [("0.0.8", "0.0.17"), ("0.0.17", "0.0.8")]:
            with self.subTest(short=short, build=build):
                self.presets(short, build)
                with self.assertRaisesRegex(RuntimeError, "must match project version"):
                    EXPORT.validate_macos_version(self.root)

    def test_missing_and_malformed_project_version_reject(self):
        for value in ['', 'config/version=0.0.17\n', 'config/version=17\n']:
            with self.subTest(value=value):
                (self.root / "project.godot").write_text('[application]\n' + value)
                with self.assertRaises(RuntimeError): EXPORT.validate_macos_version(self.root)

    def test_missing_preset_rejects(self):
        (self.root / "export_presets.cfg").write_text('[preset.0]\nname="Linux x86_64"\n')
        with self.assertRaisesRegex(RuntimeError, "exactly one macOS"):
            EXPORT.validate_macos_version(self.root)

    def test_actual_bundle_versions_are_checked_without_mutation(self):
        path = self.bundle(); before = hashlib.sha256(path.read_bytes()).digest()
        self.assertEqual(EXPORT.verify_macos_bundle_version(path, "0.0.17"), {"CFBundleShortVersionString": "0.0.17", "CFBundleVersion": "0.0.17"})
        self.assertEqual(before, hashlib.sha256(path.read_bytes()).digest())

    def test_each_wrong_exported_value_rejects(self):
        for short, build in [("0.0.8", "0.0.17"), ("0.0.17", "0.0.8"), ("", "0.0.17")]:
            with self.subTest(short=short, build=build):
                with self.assertRaisesRegex(RuntimeError, "bundle version must be"):
                    EXPORT.verify_macos_bundle_version(self.bundle(short, build), "0.0.17")

    def test_ambiguous_bundle_rejects(self):
        with self.assertRaisesRegex(RuntimeError, "Expected one"):
            EXPORT.verify_macos_bundle_version(self.bundle(duplicate=True), "0.0.17")

    def test_current_repository_metadata_matches_project(self):
        root = Path(__file__).resolve().parents[1]
        expected = re.search(r'^config/version="([^\"]+)"', (root / "project.godot").read_text(), re.MULTILINE).group(1)
        self.assertEqual(EXPORT.validate_macos_version(root), expected)


if __name__ == "__main__": unittest.main()
