import hashlib, os
from pathlib import Path
import sys, tempfile, unittest, zipfile
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import audit_web_export as audit

class PackAuditTests(unittest.TestCase):
    def test_reject_unsafe_members(self):
        for name in ('','/absolute','../escape','a/../b','a\\b','C:/file','./file'):
            with self.assertRaises(ValueError):audit.relative(name)

    def test_windows_isolated_user_path_satisfies_driver_guard(self):
        before=dict(os.environ)
        with tempfile.TemporaryDirectory() as temp:
            base=Path(temp);env=audit.audit_environment(base,'nt')
            self.assertEqual(Path(env['APPDATA']),Path(env['XDG_DATA_HOME']))
            self.assertTrue(Path(env['APPDATA']).name.endswith('-smoke-data'))
            self.assertEqual(dict(os.environ),before)
            with self.assertRaises(FileExistsError):audit.audit_environment(base,'nt')

    def complete_log(self):
        return (audit.COMPLETE_SCOPE + '\n'
                + audit.PRESERVED_COVERAGE + f' {audit.EXPECTED_PRESERVED_CHECKS} checks; actual runtime\n'
                + audit.UNIFIED_COVERAGE + f' {audit.EXPECTED_UNIFIED_CHECKS} checks; actual runtime\n'
                + f'PASS: {audit.EXPECTED_CHECKS} exported-pack checks; 0 failures\n')

    def test_complete_schema13_pack_log_required(self):
        complete = self.complete_log()
        self.assertEqual(audit.completed_pack_checks(complete, 0), audit.EXPECTED_CHECKS)
        invalid = [
            (complete, 1),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3215 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '2725 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '1516 exported-pack'), 0),
            (complete.replace('exported-pack', 'source-rehearsal'), 0),
            (complete.replace('scope: complete', 'scope: archive-only'), 0),
            (complete + audit.COMPLETE_SCOPE + '\n', 0),
            ('SOURCE REHEARSAL: pending package assertions\n' + complete, 0),
            ('SCRIPT ERROR: interrupted assertion\n' + complete, 0),
            ('ERROR: interrupted assertion\n' + complete, 0),
            (complete + f'PASS: {audit.EXPECTED_CHECKS} exported-pack checks; 0 failures\n', 0),
            (complete.replace('; 0 failures', '; 1 failures'), 0),
            (complete.replace('PASS:', 'FAIL:'), 0),
            (complete+complete, 0),
        ]
        for marker, count in ((audit.PRESERVED_COVERAGE,audit.EXPECTED_PRESERVED_CHECKS),
                              (audit.UNIFIED_COVERAGE,audit.EXPECTED_UNIFIED_CHECKS)):
            line=marker+f' {count} checks; actual runtime\n'
            invalid.extend([
                (complete.replace(line,''),0),
                (complete.replace(marker,'Old adapter only:'),0),
                (complete.replace(line,marker+' 1 checks; partial runtime\n'),0),
                (complete.replace(line,marker+f' {count+1} checks; unreviewed extension\n'),0),
                (complete+line,0),
                (complete+marker+' malformed duplicate\n',0),
                (complete.replace(line,marker+f' {count} checks\n'),0),
            ])
        invalid.extend((complete+marker+' 490 checks; obsolete\n',0) for marker in audit.OLD_COVERAGE)
        for text, code in invalid:
            with self.subTest(text=text,code=code):
                self.assertIsNone(audit.completed_pack_checks(text,code))

    def test_runtime_version_count_and_new_scope_stay_pinned(self):
        from unittest.mock import patch
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        self.assertGreater(audit.EXPECTED_UNIFIED_CHECKS,0)
        self.assertGreater(audit.EXPECTED_PRESERVED_CHECKS,0)
        self.assertGreater(audit.EXPECTED_CHECKS,audit.EXPECTED_UNIFIED_CHECKS+audit.EXPECTED_PRESERVED_CHECKS)
        self.assertNotEqual(audit.EXPECTED_CHECKS,3215)
        self.assertIn('== "0.0.22"',driver)
        self.assertIn('title.text=="0.0.22"',driver)
        self.assertNotIn('"0.0.21"',driver)
        self.assertIn('await _test_unified_pack()\n\tawait _finish_run(rehearsal)',driver)
        self.assertNotIn('game._battle_action(',driver)
        self.assertNotIn('res://tests/unified_ui_test_driver.gd',driver)
        with patch.object(audit,'EXPECTED_UNIFIED_CHECKS',0):
            self.assertIsNone(audit.completed_pack_checks(self.complete_log(),0))

    def test_frozen_historical_readers_are_byte_exact(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(audit.sha(root/'tests/fixtures/v019_game_state.gd.txt'), audit.LEGACY)
        self.assertEqual(audit.sha(root/'tests/fixtures/v020_game_state.gd.txt'), audit.SCHEMA11)
        self.assertEqual(audit.sha(root/'tests/fixtures/v022_game_state.gd.txt'), audit.SCHEMA12)
        self.assertEqual(audit.sha(root/'tests/fixtures/v017_game_state.gd.txt'), audit.SCHEMA9)

    def test_exact_site_archive_and_mutation_rejection(self):
        with tempfile.TemporaryDirectory() as temp:
            base=Path(temp);site=base/'site';(site/'licenses').mkdir(parents=True)
            content={'index.pck':b'pack fixture','licenses/test.txt':b'license fixture'}
            report={'site_files':{},'archive':{'file':'bundle.zip'}}
            with zipfile.ZipFile(base/'bundle.zip','w') as bundle:
                for name,data in content.items():
                    (site/name).write_bytes(data);bundle.writestr('Hero-Web/'+name,data)
                    report['site_files'][name]={'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest()}
            report['archive']['sha256']=audit.sha(base/'bundle.zip');audit.verify_site(base,report)
            (site/'index.pck').write_bytes(b'changed')
            with self.assertRaises(RuntimeError):audit.verify_site(base,report)
            (site/'index.pck').write_bytes(content['index.pck']);(site/'extra').write_bytes(b'new')
            with self.assertRaises(RuntimeError):audit.verify_site(base,report)

    def test_source_manifest_remains_exact_and_cannot_escape(self):
        with tempfile.TemporaryDirectory() as temp:
            base=Path(temp);root=base/'root';build=base/'build';root.mkdir();build.mkdir()
            for name in ('project.godot','export_presets.cfg'):(root/name).write_bytes(name.encode())
            (root/'scripts').mkdir();(root/'scripts/main.gd').write_bytes(b'current runtime')
            entries={p.relative_to(root).as_posix():audit.sha(p) for p in root.rglob('*') if p.is_file()}
            text=''.join(digest+'  '+name+'\n' for name,digest in entries.items())
            manifest=build/'SOURCE-SHA256SUMS.txt';manifest.write_text(text)
            report={'source_entries':len(entries),'source_unchanged':True}
            self.assertEqual(audit.verify_source_manifest(build,report,root),audit.sha(manifest))
            for malformed in (text+text,text+'bad line\n','0'*64+'  ../escape\n'):
                manifest.write_text(malformed)
                with self.assertRaises((RuntimeError,ValueError)):audit.verify_source_manifest(build,report,root)
            manifest.write_text(text);(root/'scripts/main.gd').write_bytes(b'changed')
            with self.assertRaises(RuntimeError):audit.verify_source_manifest(build,report,root)

if __name__=='__main__':unittest.main()
