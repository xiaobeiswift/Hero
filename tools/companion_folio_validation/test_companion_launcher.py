"""Independent launcher mocks only. No Godot process or native image evidence."""
from contextlib import ExitStack
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch
import zlib

import isolated_godot as proposed
import isolated_godot_reviewed as original

EVIDENCE = Path(__file__).parent / 'mock-native-evidence'
EVIDENCE.mkdir(exist_ok=True)


def png(size):
    def chunk(kind, data):
        return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data))
    w, h = size
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 2, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress((b'\0' + b'\0\0\0' * w) * h)) + chunk(b'IEND', b''))


PNG_BYTES = {size: png(size) for size in [(1280, 800), (960, 600)]}


class NativeProposalTests(unittest.TestCase):
    def setUp(self):
        self.folder = Path(tempfile.mkdtemp(prefix=self._testMethodName + '-', dir=EVIDENCE))
        self.source = self.folder / 'source'
        self.source.mkdir()
        (self.source / 'tests').mkdir()
        self.names = [f'input-{i}.txt' for i in range(380)] + ['test.gd', proposed.NATIVE_HELPER]
        for name in self.names:
            (self.source / name).write_text('Mock source. Never executed.\n')
        self.manifest = self.folder / 'runtime-inputs.json'
        self.manifest.write_text(json.dumps({'runtime_sha256': proposed.snapshot(self.source, self.names)}))
        self.bound_runtime = proposed.runtime_digest(self.source, self.names)
        self.bound_manifest = proposed.sha(self.manifest)
        (self.source / 'tests/recovery_20261006_source_binding.json').write_text(json.dumps({'runtime_sha256': proposed.snapshot(self.source, self.names)}))
        self.engine = self.folder / 'engine-fixture'
        self.engine.write_text('Mock engine file. Never executed.\n')
        self.driver = self.folder / 'driver.gd'
        self.driver.write_text('Mock native driver. Never executed.\n')
        self.commands = []

    def git(self, command, **_kwargs):
        return b'mock-commit\nmock-tree\n' if 'rev-parse' in command else ('\0'.join(self.names) + '\0').encode()

    def run(self, result=None):
        # Preserve unittest.TestCase.run; this wrapper disambiguates fake execution.
        return super().run(result)

    def mock_action(self, command, env, log, _timeout, _cwd):
        self.commands.append((command, env.copy()))
        if '--headless' in command:
            log.write_text('HERO_PROFILE_GUARD_OK\n')
            return 0
        root = Path(env['HERO_FOLIO_QA_OWNED_ROOT'])
        binding = json.loads((root / 'results/native-binding.json').read_text())
        frames = root / 'results/native-frames'
        frames.mkdir()
        captures = []
        for i in range(10):
            size = (1280, 800) if i % 2 == 0 else (960, 600)
            path = frames / f'mock-{i:02}.png'
            path.write_bytes(PNG_BYTES[size])
            captures.append({'path': str(path), 'sha256': proposed.sha(path), 'bytes': path.stat().st_size,
                             'pixel_dimensions': list(size), 'requested_window': list(size), 'actual_window': list(size), 'display_server': 'x11'})
        data = {'status': 'pass', 'historical_evidence_recreated': False, 'failures': [], 'binding': binding, 'captures': captures}
        if hasattr(self, 'mutate'):
            self.mutate(root, data)
        Path(env['HERO_FOLIO_QA_REPORT']).write_text(json.dumps(data))
        log.write_text('PASS: NEW companion folio native capture, 10 PNGs / MOCK ONLY\n')
        return 0

    def launch(self, module=proposed, mode='native', action=None, label='qa', extra=None):
        root = self.folder / label
        argv = [mode, '--source', str(self.source), '--qa-root', str(root)]
        if mode != 'import':
            argv += ['--script', str(self.driver) if mode == 'native' else 'test.gd']
        argv += extra or []
        with ExitStack() as stack:
            stack.enter_context(patch.multiple(module, ENGINE=self.engine, ENGINE_SHA=module.sha(self.engine), RUNTIME_SHA=self.bound_runtime))
            if module is proposed:
                stack.enter_context(patch.multiple(module, RUNTIME_INPUTS=self.manifest, RUNTIME_INPUTS_SHA=self.bound_manifest))
            stack.enter_context(patch.object(module.subprocess, 'check_output', side_effect=self.git))
            stack.enter_context(patch.object(module, 'run_owned', side_effect=action or self.mock_action))
            stack.enter_context(patch.dict(os.environ, {'DISPLAY': ':mock-existing-display'}))
            code = module.main(argv)
        return code, json.loads((root / 'results/launcher-result.json').read_text()), root

    def test_mock_success_native_command_and_binding(self):
        code, report, root = self.launch()
        self.assertEqual(code, 0)
        self.assertEqual(report['native_capture_count'], 10)
        self.assertEqual([p['phase'] for p in report['phases']], ['guard', 'native'])
        guard, native = self.commands
        self.assertIn('--headless', guard[0])
        self.assertNotIn('--headless', native[0])
        for option, value in [('--display-driver', 'x11'), ('--rendering-method', 'gl_compatibility'), ('--audio-driver', 'Dummy'), ('--resolution', '1280x800'), ('--fixed-fps', '30')]:
            self.assertEqual(native[0][native[0].index(option) + 1], value)
        self.assertEqual(native[1]['DISPLAY'], ':mock-existing-display')
        self.assertEqual(native[1]['HOME'], str(root / 'home'))
        self.assertEqual(native[1]['HERO_FOLIO_QA_USER_DIR'], str(root / proposed.USER_SUFFIX))
        self.assertEqual((root / '.hero-folio-qa-owner').read_text(), native[1]['HERO_FOLIO_QA_TOKEN'])
        self.assertEqual((root / 'native-driver.gd').read_bytes(), self.driver.read_bytes())
        binding = json.loads((root / 'results/native-binding.json').read_text())
        self.assertEqual(binding['suite'], 'companion_folio_native_capture')
        self.assertEqual(binding['helper_sha256'], proposed.sha(self.source / proposed.NATIVE_HELPER))
        self.assertEqual(report['runtime_inputs_sha256'], self.bound_manifest)
        for name in ['tracked-before.json', 'tracked-after.json', 'generated-before.json', 'generated-after.json']:
            self.assertTrue((root / 'results' / name).is_file())

    def test_missing_display_refuses_before_root(self):
        root = self.folder / 'qa'
        with patch.multiple(proposed, RUNTIME_SHA=self.bound_runtime, RUNTIME_INPUTS_SHA=self.bound_manifest), patch.dict(os.environ, {'DISPLAY': ''}), patch.object(proposed, 'run_owned') as child:
            with self.assertRaisesRegex(ValueError, 'already available'):
                proposed.main(['native', '--source', str(self.source), '--qa-root', str(root), '--script', str(self.driver)])
            child.assert_not_called()
        self.assertFalse(root.exists())

    def test_source_driver_refused_before_any_child(self):
        self.driver = self.source / 'test.gd'
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('external .gd', report['failure'])

    def test_native_arguments_remain_disallowed(self):
        with self.assertRaisesRegex(ValueError, 'test-only'):
            self.launch(extra=['--test-arg', 'irrelevant'])

    def test_recheck_empty_profile_between_guard_and_native(self):
        def action(command, env, log, timeout, cwd):
            self.commands.append(command)
            (Path(env['HERO_FOLIO_QA_USER_DIR']) / 'existing-save').write_text('preserve')
            log.write_text('HERO_PROFILE_GUARD_OK\n')
            return 0
        code, report, root = self.launch(action=action)
        self.assertEqual(code, 1)
        self.assertEqual(len(self.commands), 1)
        self.assertIn('no longer empty', report['failure'])
        self.assertEqual((root / proposed.USER_SUFFIX / 'existing-save').read_text(), 'preserve')

    def test_import_and_test_commands_unchanged(self):
        for mode in ['import', 'test']:
            normalized = []
            for label, module in [('original', original), ('proposed', proposed)]:
                self.commands = []
                code, report, root = self.launch(module, mode, label=mode + '-' + label, extra=['--test-arg', '{results}/proof.json'] if mode == 'test' else [])
                self.assertEqual(code, 0)
                normalized.append([str(p['command']).replace(str(root), '{qa}') for p in report['phases']])
                self.assertTrue(all('--headless' in p['command'] for p in report['phases']))
            self.assertEqual(normalized[0], normalized[1])

    def reject(self, mutate, fragment):
        self.mutate = mutate
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertFalse(report['success'])
        failure = report.get('failure', '') + report.get('native_integrity_failure', '') + report.get('integrity_failure', '')
        self.assertIn(fragment, failure)

    def test_reject_wrong_frame_count(self):
        self.reject(lambda _r, d: d['captures'].pop(), 'frame count')

    def test_reject_duplicate_path(self):
        self.reject(lambda _r, d: d['captures'].__setitem__(1, d['captures'][0].copy()), 'Duplicate')

    def test_reject_wrong_hash(self):
        self.reject(lambda _r, d: d['captures'][0].update(sha256='0' * 64), 'bytes/hash')

    def test_reject_physical_size_mismatch(self):
        self.reject(lambda _r, d: d['captures'][0].update(actual_window=[960, 600]), 'physical size')

    def test_reject_headless_claim(self):
        self.reject(lambda _r, d: d['captures'][0].update(display_server='headless'), 'Headless')

    def test_reject_extra_frame_file(self):
        self.reject(lambda r, _d: (r / 'results/native-frames/extra.txt').write_text('unexpected'), 'Unexpected native frame')

    def test_reject_result_binding_mutation(self):
        self.reject(lambda _r, d: d['binding'].update(source_commit='wrong'), 'binding mismatch')

    def test_reject_copied_driver_mutation(self):
        self.reject(lambda r, _d: (r / 'native-driver.gd').write_text('changed'), 'Native driver changed')

    def test_reject_original_driver_mutation(self):
        self.reject(lambda _r, _d: self.driver.write_text('changed'), 'Native driver changed')

    def test_reject_binding_file_mutation(self):
        self.reject(lambda r, _d: (r / 'results/native-binding.json').write_text('{}'), 'Native binding changed')

    def test_reject_png_symlink_and_preserve_target(self):
        target = self.folder / 'preserved.png'
        target.write_bytes(PNG_BYTES[(1280, 800)])
        def replace(_root, data):
            path = Path(data['captures'][0]['path'])
            path.rename(path.with_suffix('.original'))
            path.symlink_to(target)
        self.reject(replace, 'Symlink')
        self.assertEqual(target.read_bytes(), PNG_BYTES[(1280, 800)])


    def test_unbound_placeholder_refuses_before_any_profile_or_child(self):
        root = self.folder / 'qa'
        with patch.multiple(proposed, RUNTIME_SHA=None, RUNTIME_INPUTS_SHA=None), patch.object(proposed, 'run_owned') as child:
            with self.assertRaisesRegex(ValueError, 'UNBOUND'):
                proposed.main(['native', '--source', str(self.source), '--qa-root', str(root), '--script', str(self.driver)])
            child.assert_not_called()
        self.assertFalse(root.exists())

    def test_reject_six_four_size_distribution(self):
        def mutate(_root, data):
            capture = data['captures'][-1]
            path = Path(capture['path'])
            path.write_bytes(PNG_BYTES[(1280, 800)])
            capture.update(sha256=proposed.sha(path), bytes=path.stat().st_size,
                           pixel_dimensions=[1280, 800], requested_window=[1280, 800], actual_window=[1280, 800])
        self.reject(mutate, 'Exactly five frames')

    def test_reject_historical_sixteen_count(self):
        self.reject(lambda _r, data: data['captures'].extend([data['captures'][0].copy() for _ in range(6)]), 'frame count')

    def test_reject_historical_marker(self):
        def action(command, env, log, timeout, cwd):
            code = self.mock_action(command, env, log, timeout, cwd)
            if '--headless' not in command:
                log.write_text('PASS: NEW recovery native capture, 16 PNGs / MOCK ONLY\n')
            return code
        code, report, _root = self.launch(action=action)
        self.assertEqual(code, 1)
        self.assertIn('success marker missing', report['failure'])

    def test_reject_manifest_file_hash_mismatch_before_child(self):
        self.manifest.write_text(self.manifest.read_text() + ' ')
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('manifest SHA256 mismatch', report['failure'])

    def test_reject_manifest_entry_count_before_child(self):
        data = json.loads(self.manifest.read_text())
        data['runtime_sha256'].pop(self.names[0])
        self.manifest.write_text(json.dumps(data))
        self.bound_manifest = proposed.sha(self.manifest)
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('exactly 382 tracked paths', report['failure'])

    def test_reject_manifest_wrong_entry_hash_before_child(self):
        data = json.loads(self.manifest.read_text())
        data['runtime_sha256'][self.names[0]] = '0' * 64
        self.manifest.write_text(json.dumps(data))
        self.bound_manifest = proposed.sha(self.manifest)
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('runtime binding mismatch', report['failure'])

    def test_reject_wrong_candidate_digest_before_child(self):
        self.bound_runtime = '0' * 64
        code, report, _root = self.launch()
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('runtime binding mismatch', report['failure'])

    def test_reject_manifest_change_during_native_run(self):
        self.reject(lambda _r, _data: self.manifest.write_text('{}'), 'Runtime manifest changed during run')

    def test_reject_runtime_original_change_during_native_run(self):
        self.reject(lambda _r, _data: (self.source / self.names[0]).write_text('changed'), 'Original tracked bytes')

    def test_test_script_must_remain_tracked(self):
        self.names.remove('test.gd')
        code, report, _root = self.launch(mode='test')
        self.assertEqual(code, 1)
        self.assertEqual(self.commands, [])
        self.assertIn('tracked relative .gd', report['failure'])

    def test_existing_qa_root_is_not_overwritten(self):
        root = self.folder / 'qa'
        root.mkdir()
        evidence = root / 'keep.txt'
        evidence.write_text('keep')
        with self.assertRaises(FileExistsError):
            self.launch()
        self.assertEqual(self.commands, [])
        self.assertEqual(evidence.read_text(), 'keep')

    def test_reviewed_containment_and_process_functions_are_identical(self):
        import ast
        reviewed = ast.parse(Path(original.__file__).read_text())
        adapted = ast.parse(Path(proposed.__file__).read_text())
        for name in ['require', 'absolute_unlinked', 'sha', 'snapshot', 'runtime_digest', 'new_profile', 'run_owned', 'check_profile', 'generated']:
            before = next(n for n in reviewed.body if isinstance(n, ast.FunctionDef) and n.name == name)
            after = next(n for n in adapted.body if isinstance(n, ast.FunctionDef) and n.name == name)
            self.assertEqual(ast.dump(before), ast.dump(after), name)


if __name__ == '__main__':
    unittest.main(verbosity=2)
