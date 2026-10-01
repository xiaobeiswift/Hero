"""Small synthetic archives exercise byte preservation and fail-closed path handling."""
import importlib.util
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
import zipfile

SPEC = importlib.util.spec_from_file_location("verify_export_archives", Path(__file__).resolve().parents[1] / "tools/verify_export_archives.py")
VERIFY = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(VERIFY)


class ArchiveVerificationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="hero-archive-test-")
        self.addCleanup(self.temp.cleanup)
        self.build = Path(self.temp.name) / "new-build"
        self.build.mkdir()
        self.report = {"build_status": "complete", "source_git_commit": "fixture", "source_manifest_sha256": "fixture-manifest", "platform_work_directory": "transient", "platforms": {}, "archives": {}}
        for target in ["linux", "windows", "macos"]:
            directory = self.build / "transient" / target
            directory.mkdir(parents=True)
            (directory / "README.txt").write_text("Retained notice")
            if target == "macos":
                output = directory / "Hero.zip"
                with zipfile.ZipFile(output, "w") as z:
                    z.writestr("Hero.app/Contents/MacOS/Hero", b"mach-o-fixture")
                    z.writestr("Hero.app/Contents/Resources/Hero.pck", b"mac-pack")
                (self.build / "transient/macos-audit.pck").write_bytes(b"mac-pack")
                archive = self.build / "Hero-fixture-macos-universal.zip"
                archive.write_bytes(output.read_bytes())
                with zipfile.ZipFile(archive, "a") as z:
                    z.write(directory / "README.txt", "README.txt")
            else:
                output = directory / ("Hero.x86_64" if target == "linux" else "Hero.exe")
                output.write_bytes(b"engine-fixture")
                (directory / "Hero.pck").write_bytes(b"project-fixture")
                if target == "linux":
                    archive = self.build / "Hero-fixture-linux-x86_64.tar.gz"
                    with tarfile.open(archive, "w:gz") as z:
                        z.add(directory, arcname="Hero")
                else:
                    archive = self.build / "Hero-fixture-windows-x86_64.zip"
                    with zipfile.ZipFile(archive, "w") as z:
                        for path in directory.iterdir():
                            z.write(path, "Hero/" + path.name)
            self.report["platforms"][target] = {"export": "passed", "binary": output.relative_to(self.build).as_posix()}
            self.report["archives"][archive.name] = {"sha256": VERIFY.digest(archive), "bytes": archive.stat().st_size}
        self.write_report()

    def write_report(self):
        (self.build / "BUILD-REPORT.json").write_text(json.dumps(self.report))

    def test_all_three_platforms_are_read_only_and_include_pack_bytes(self):
        before = {p.relative_to(self.build): VERIFY.digest(p) for p in self.build.rglob("*") if p.is_file()}
        result = VERIFY.verify_build(self.build)
        self.assertEqual([r["members_compared"] for r in result["archives"]], [3, 3, 4])
        self.assertEqual(result["source_git_commit"], "fixture")
        self.assertEqual(before, {p.relative_to(self.build): VERIFY.digest(p) for p in self.build.rglob("*") if p.is_file()})

    def test_changed_unpacked_pack_is_rejected(self):
        (self.build / "transient/linux/Hero.pck").write_bytes(b"changed")
        with self.assertRaisesRegex(RuntimeError, "member differs"):
            VERIFY.verify_build(self.build)

    def test_changed_archive_is_rejected(self):
        archive = self.build / "Hero-fixture-windows-x86_64.zip"
        archive.write_bytes(archive.read_bytes() + b"corruption")
        with self.assertRaisesRegex(RuntimeError, "differs from build report"):
            VERIFY.verify_build(self.build)

    def test_missing_pack_is_rejected_even_if_binary_exists(self):
        (self.build / "transient/linux/Hero.pck").unlink()
        with self.assertRaisesRegex(RuntimeError, "Expected regular"):
            VERIFY.verify_build(self.build)

    def test_macos_audit_must_equal_shipped_pack(self):
        (self.build / "transient/macos-audit.pck").write_bytes(b"other-pack")
        with self.assertRaisesRegex(RuntimeError, "audit PCK differs"):
            VERIFY.verify_build(self.build)

    def test_traversal_in_report_is_rejected(self):
        self.report["platforms"]["linux"]["binary"] = "../outside"
        self.write_report()
        with self.assertRaisesRegex(RuntimeError, "Unsafe build path"):
            VERIFY.verify_build(self.build)

    def test_symlink_cannot_redirect_binary_read(self):
        binary = self.build / "transient/linux/Hero.x86_64"
        binary.unlink()
        binary.symlink_to(self.build / "transient/windows/Hero.exe")
        with self.assertRaisesRegex(RuntimeError, "Expected regular"):
            VERIFY.verify_build(self.build)

    def test_unfinished_export_is_rejected(self):
        self.report["build_status"] = "incomplete"
        self.write_report()
        with self.assertRaisesRegex(RuntimeError, "not complete"):
            VERIFY.verify_build(self.build)


if __name__ == "__main__":
    unittest.main()
