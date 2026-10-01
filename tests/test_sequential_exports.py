"""New-build temporary output retirement must retain verifiable final bytes."""
import importlib.util
import json
import os
from pathlib import Path
import types
import unittest
from unittest.mock import patch
import test_export_archives as fixtures
VERIFY = fixtures.VERIFY

SPEC = importlib.util.spec_from_file_location("export_desktop", Path(__file__).resolve().parents[1] / "tools/export_desktop.py")
EXPORT = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(EXPORT)


class SequentialExportTests(unittest.TestCase):
    write_report = fixtures.ArchiveVerificationTests.write_report
    def setUp(self):
        fixtures.ArchiveVerificationTests.setUp(self)
        self.report["sequential_platforms"] = True
        (self.build / "TRANSIENT-OWNER.json").write_text(json.dumps({"process_id": os.getpid(), "build": str(self.build.resolve())}))
        self.logs = self.build / "logs"; self.logs.mkdir()
        (self.build / "source").mkdir(); (self.build / "source/project.godot").write_text("retained source")
        self.write_report()

    def retire(self, target):
        EXPORT.retire_verified_platform(self.build, target, self.report, os.environ.copy(), self.logs)

    def test_platform_can_be_verified_before_overall_completion(self):
        self.report["build_status"] = "incomplete"; self.write_report()
        row = VERIFY.verify_build(self.build, "windows")["archives"][0]
        self.assertTrue(row["member_manifest"]["live_output_verified"])
        self.assertEqual(len(row["member_manifest"]["members"]), 3)
        with self.assertRaisesRegex(RuntimeError, "not complete"): VERIFY.verify_build(self.build)

    def test_two_retirements_preserve_all_final_archives_and_linux(self):
        before = {p.name: VERIFY.digest(p) for p in self.build.iterdir() if p.name.endswith((".zip", ".tar.gz"))}
        self.retire("macos"); self.retire("windows")
        self.assertFalse((self.build / "transient/macos").exists())
        self.assertFalse((self.build / "transient/windows").exists())
        self.assertFalse((self.build / "transient/macos-audit.pck").exists())
        self.assertTrue((self.build / "transient/linux/Hero.x86_64").is_file())
        self.assertEqual((self.build / "source/project.godot").read_text(), "retained source")
        self.assertEqual(before, {p.name: VERIFY.digest(p) for p in self.build.iterdir() if p.name.endswith((".zip", ".tar.gz"))})
        self.assertEqual([x["members_compared"] for x in VERIFY.verify_build(self.build)["archives"]], [3, 3, 4])

    def test_linux_is_never_automatically_retired(self):
        with self.assertRaisesRegex(RuntimeError, "restricted"): self.retire("linux")
        self.assertTrue((self.build / "transient/linux/Hero.pck").exists())

    def test_old_process_or_unmarked_build_is_not_retired(self):
        (self.build / "TRANSIENT-OWNER.json").write_text(json.dumps({"process_id": -1, "build": str(self.build.resolve())}))
        with self.assertRaisesRegex(RuntimeError, "restricted"): self.retire("windows")
        self.assertTrue((self.build / "transient/windows/Hero.pck").exists())

    def test_archive_mismatch_blocks_retirement(self):
        (self.build / "transient/windows/Hero.pck").write_bytes(b"changed")
        with self.assertRaises(RuntimeError): self.retire("windows")
        self.assertTrue((self.build / "transient/windows/Hero.pck").exists())
        self.assertFalse((self.build / "ARCHIVE-MEMBERS-windows.json").exists())

    def test_retained_record_tampering_is_rejected(self):
        self.retire("windows")
        record = self.build / "ARCHIVE-MEMBERS-windows.json"
        record.write_text(record.read_text() + " ")
        with self.assertRaisesRegex(RuntimeError, "manifest digest differs"): VERIFY.verify_build(self.build)

    def test_record_cannot_be_reused_for_different_source(self):
        self.retire("windows"); self.report["source_git_commit"] = "different"; self.write_report()
        with self.assertRaisesRegex(RuntimeError, "provenance differs"): VERIFY.verify_build(self.build)

    def test_recorded_members_are_checked_against_actual_archive(self):
        self.retire("windows")
        path = self.build / "ARCHIVE-MEMBERS-windows.json"; record = json.loads(path.read_text())
        record["members"]["Hero/Hero.pck"]["sha256"] = "changed"
        path.write_text(json.dumps(record)); self.report["platforms"]["windows"]["retired_member_manifest_sha256"] = VERIFY.digest(path); self.write_report()
        with self.assertRaisesRegex(RuntimeError, "members differ"): VERIFY.verify_build(self.build)

    def test_missing_retained_record_is_rejected(self):
        self.retire("macos"); (self.build / "ARCHIVE-MEMBERS-macos.json").unlink()
        with self.assertRaisesRegex(RuntimeError, "Expected regular"): VERIFY.verify_build(self.build)

    def test_space_gate_reports_shortfall_without_mutation(self):
        before = sorted(str(p) for p in self.build.rglob("*"))
        with patch.object(EXPORT.shutil, "disk_usage", return_value=types.SimpleNamespace(free=10)):
            with self.assertRaisesRegex(RuntimeError, "shortfall 15"): EXPORT.require_space(self.build, 25, "fixture")
        self.assertEqual(before, sorted(str(p) for p in self.build.rglob("*")))


if __name__ == "__main__": unittest.main()
