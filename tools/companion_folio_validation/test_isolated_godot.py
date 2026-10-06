"""Only Python fixtures run here. This suite never starts Godot or changes source."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import isolated_godot as launcher

EVIDENCE = Path(__file__).resolve().parent / 'unit-evidence'
EVIDENCE.mkdir(exist_ok=True)


class IsolationTests(unittest.TestCase):
    def setUp(self):
        # Deliberately retain every test fixture and log; no deletion or source writes.
        self.folder = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-', dir=EVIDENCE))

    def profile(self):
        root = self.folder / 'qa'
        return root, launcher.new_profile(root)

    def test_refuse_relative_traversal_and_symlink_paths(self):
        target = self.folder / 'actual'
        target.mkdir()
        link = self.folder / 'link'
        link.symlink_to(target, target_is_directory=True)
        for path in ('relative', self.folder / '..' / 'escape', link, link / 'new'):
            with self.subTest(path=path), self.assertRaises(ValueError):
                launcher.absolute_unlinked(path)

    def test_fresh_profile_is_private_and_exclusive(self):
        root, env = self.profile()
        launcher.check_profile(root, env)
        self.assertEqual(env['PYTHONDONTWRITEBYTECODE'], '1')
        self.assertEqual(env['HOME'], str(root / 'home'))
        self.assertEqual(env['XDG_DATA_HOME'], str(root / 'data'))
        self.assertEqual(env['HERO_FOLIO_QA_USER_DIR'], str(root / launcher.USER_SUFFIX))
        self.assertEqual(env['HERO_FOLIO_QA_REPORT'], str(root / 'results/test-result.json'))
        self.assertEqual((root / '.hero-folio-qa-owner').stat().st_uid, os.getuid())
        with self.assertRaises(FileExistsError):
            launcher.new_profile(root)

    def test_refuse_nonempty_user_data_including_hidden_files(self):
        root, env = self.profile()
        (root / launcher.USER_SUFFIX / '.old-save').write_text('preserve me')
        with self.assertRaisesRegex(ValueError, 'no longer empty'):
            launcher.check_profile(root, env)
        self.assertEqual((root / launcher.USER_SUFFIX / '.old-save').read_text(), 'preserve me')

    def test_refuse_changed_token_owner_and_permissions(self):
        root, env = self.profile()
        with patch.object(launcher.os, 'getuid', return_value=os.getuid() + 10000):
            with self.assertRaisesRegex(ValueError, 'ownership'):
                launcher.check_profile(root, env)
        (root / '.hero-folio-qa-owner').write_text('wrong')
        with self.assertRaisesRegex(ValueError, 'token changed'):
            launcher.check_profile(root, env)
        (root / '.hero-folio-qa-owner').write_text(env['HERO_FOLIO_QA_TOKEN'])
        root.chmod(0o755)
        with self.assertRaisesRegex(ValueError, 'permissions'):
            launcher.check_profile(root, env)

    def test_snapshot_rejects_escape_link_and_nonfile(self):
        (self.folder / 'link').symlink_to(self.folder / 'missing')
        for names in (['../outside'], ['/outside'], ['link'], ['.']):
            with self.subTest(names=names), self.assertRaises((ValueError, OSError)):
                launcher.snapshot(self.folder, names)

    def test_snapshot_detects_original_bytes_and_runtime_mutation(self):
        path = self.folder / 'original.gd'
        path.write_text('first')
        before = launcher.snapshot(self.folder, [path.name])
        digest = launcher.runtime_digest(self.folder, [path.name])
        path.write_text('second')
        self.assertNotEqual(before, launcher.snapshot(self.folder, [path.name]))
        self.assertNotEqual(digest, launcher.runtime_digest(self.folder, [path.name]))

    def test_generated_cache_and_new_uids_are_separate(self):
        (self.folder / '.godot').mkdir()
        (self.folder / '.godot/cache.bin').write_bytes(b'cache')
        (self.folder / 'original.gd.uid').write_text('uid://retained')
        (self.folder / 'new.gd.uid').write_text('uid://new')
        result = launcher.generated(self.folder, ['original.gd.uid'])
        self.assertEqual(set(result['godot_cache']), {'.godot/cache.bin'})
        self.assertEqual(set(result['untracked_uids']), {'new.gd.uid'})

    def test_refuse_linked_cache_root(self):
        (self.folder / '.godot').symlink_to(self.folder / 'elsewhere')
        with self.assertRaisesRegex(ValueError, 'Symlink'):
            launcher.generated(self.folder, [])

    def test_invalid_timeout_never_creates_child_or_log(self):
        for seconds in (0, -1, float('nan'), float('inf')):
            with self.assertRaises(ValueError):
                launcher.run_owned([sys.executable, '-c', 'raise Exception()'], os.environ.copy(), self.folder / 'not-created.log', seconds, self.folder)
        self.assertFalse((self.folder / 'not-created.log').exists())

    def test_child_exit_and_unicode_output_are_preserved(self):
        log = self.folder / 'console.log'
        with patch.object(launcher.os, 'killpg', wraps=os.killpg) as kill:
            code = launcher.run_owned([sys.executable, '-c', "print('渡灯录 evidence'); raise SystemExit(7)"], os.environ.copy(), log, 5, self.folder)
            kill.assert_not_called()
        self.assertEqual(code, 7)
        self.assertIn('渡灯录 evidence', log.read_text())

    def test_storage_floor_stops_owned_child_and_preserves_reason(self):
        log = self.folder / 'console.log'
        with patch.object(launcher.shutil, 'disk_usage', return_value=SimpleNamespace(free=1024**3)):
            code = launcher.run_owned([sys.executable, '-c', 'import time; time.sleep(30)'], os.environ.copy(), log, 5, self.folder)
        self.assertEqual(code, 125)
        self.assertIn('storage fell below 2 GiB', log.read_text())

    def test_timeout_stops_only_owned_group_and_keeps_evidence(self):
        sentinel = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
        code = "import subprocess,sys,time; p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)']); print(p.pid,flush=True); print('partial evidence',flush=True); time.sleep(30)"
        log = self.folder / 'console.log'
        try:
            started = time.monotonic()
            result = launcher.run_owned([sys.executable, '-c', code], os.environ.copy(), log, 0.5, self.folder)
            self.assertEqual(result, 124)
            self.assertLess(time.monotonic() - started, 3)
            self.assertIsNone(sentinel.poll(), 'unrelated owned fixture must remain alive')
            lines = log.read_text().splitlines()
            self.assertIn('partial evidence', lines)
            state = Path('/proc') / lines[0] / 'stat'
            self.assertTrue(not state.exists() or state.read_text().split(') ')[1].startswith('Z'), 'descendant is still running')
        finally:
            sentinel.kill()
            sentinel.wait(timeout=5)

    def mocked_launch(self, action):
        source = self.folder / 'source'
        source.mkdir()
        names = [f'input-{number}.txt' for number in range(382)]
        for name in names:
            (source / name).write_text('fixed original')
        (source / 'tests').mkdir()
        (source / 'tests/recovery_20261006_source_binding.json').write_text(json.dumps({'runtime_sha256': launcher.snapshot(source, names)}))
        manifest = self.folder / 'runtime-inputs.json'
        manifest.write_text(json.dumps({'runtime_sha256': launcher.snapshot(source, names)}))
        engine = self.folder / 'engine-fixture'
        engine.write_text('never executed')
        root = self.folder / 'qa'
        def fake_git(command, **kwargs):
            return b'fixture-commit\nfixture-tree\n' if 'rev-parse' in command else ('\0'.join(names) + '\0').encode()
        with patch.multiple(launcher, ENGINE=engine, ENGINE_SHA=launcher.sha(engine), RUNTIME_SHA=launcher.runtime_digest(source, names), RUNTIME_INPUTS=manifest, RUNTIME_INPUTS_SHA=launcher.sha(manifest)), patch.object(launcher.subprocess, 'check_output', side_effect=fake_git), patch.object(launcher, 'run_owned', side_effect=action) as run:
            code = launcher.main(['import', '--source', str(source), '--qa-root', str(root)])
        return code, json.loads((root / 'results/launcher-result.json').read_text()), run.call_count

    def test_guard_error_with_zero_exit_prevents_import(self):
        def fail_guard(command, env, log, timeout, cwd):
            log.write_text('HERO_PROFILE_GUARD_OK\n\x1b[31mSCRIPT ERROR: fixture failure\x1b[0m\n')
            return 0
        code, report, calls = self.mocked_launch(fail_guard)
        self.assertEqual(code, 1)
        self.assertFalse(report['success'])
        self.assertEqual(calls, 1)
        self.assertEqual(report['phases'][0]['phase'], 'guard')
        self.assertIn('SCRIPT ERROR', report['phases'][0]['error_lines'][0])
        self.assertEqual(report['source_commit'], 'fixture-commit')
        self.assertEqual(report['source_tree'], 'fixture-tree')
        self.assertEqual(report['tool_sha256']['launcher'], launcher.sha(Path(launcher.__file__)))

    def test_changed_original_rejects_clean_guard_and_import(self):
        def mutate_during_import(command, env, log, timeout, cwd):
            if '--editor' in command:
                (cwd / 'input-0.txt').write_text('changed during mocked import')
                log.write_text('import exited cleanly\n')
            else:
                log.write_text('HERO_PROFILE_GUARD_OK\n')
            return 0
        code, report, calls = self.mocked_launch(mutate_during_import)
        self.assertEqual(calls, 2)
        self.assertEqual(code, 1)
        self.assertFalse(report['success'])
        self.assertEqual(report['changed_originals'], ['input-0.txt'])
        self.assertIn('Original tracked bytes', report['integrity_failure'])

    def test_external_guard_contains_no_load_or_preload(self):
        guard = Path(launcher.__file__).with_name('profile_guard.gd').read_text()
        self.assertNotRegex(guard, r'\b(?:preload|load)\s*\(')


if __name__ == '__main__':
    unittest.main()
