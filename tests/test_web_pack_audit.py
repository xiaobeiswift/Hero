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
                + audit.EXPLORATION_COVERAGE + f' {audit.EXPECTED_EXPLORATION_CHECKS} checks; actual runtime\n'
                + audit.CONDITION_COVERAGE + f' {audit.EXPECTED_CONDITION_CHECKS} checks; actual runtime\n'
                + audit.TRANSFER_COVERAGE + f' {audit.EXPECTED_TRANSFER_CHECKS} checks; actual runtime\n'
                + audit.CONSIGNEE_COVERAGE + f' {audit.EXPECTED_CONSIGNEE_CHECKS} checks; actual runtime\n'
                + audit.POLISH_COVERAGE + f' {audit.EXPECTED_POLISH_CHECKS} checks; actual runtime\n'
                + audit.CAPSTONE_COVERAGE + f' {audit.EXPECTED_CAPSTONE_CHECKS} checks; actual runtime\n'
                + audit.FITTING_COVERAGE + f' {audit.EXPECTED_FITTING_CHECKS} checks; actual runtime\n'
                + audit.JOURNAL_COVERAGE + f' {audit.EXPECTED_JOURNAL_CHECKS} checks; actual runtime\n'
                + f'PASS: {audit.EXPECTED_CHECKS} exported-pack checks; 0 failures\n')

    def test_complete_schema16_pack_log_required(self):
        complete = self.complete_log()
        self.assertEqual(audit.completed_pack_checks(complete, 0), audit.EXPECTED_CHECKS)
        invalid = [
            (complete, 1),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3215 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3350 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3345 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3159 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '3154 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '2810 exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', str(audit.EXPECTED_SOURCE_CHECKS)+' exported-pack'), 0),
            (complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack', '2799 exported-pack'), 0),
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
                              (audit.UNIFIED_COVERAGE,audit.EXPECTED_UNIFIED_CHECKS),
                              (audit.EXPLORATION_COVERAGE,audit.EXPECTED_EXPLORATION_CHECKS),
                              (audit.CONDITION_COVERAGE,audit.EXPECTED_CONDITION_CHECKS),
                              (audit.TRANSFER_COVERAGE,audit.EXPECTED_TRANSFER_CHECKS),
                              (audit.CONSIGNEE_COVERAGE,audit.EXPECTED_CONSIGNEE_CHECKS),
                              (audit.POLISH_COVERAGE,audit.EXPECTED_POLISH_CHECKS),
                              (audit.CAPSTONE_COVERAGE,audit.EXPECTED_CAPSTONE_CHECKS),
                              (audit.FITTING_COVERAGE,audit.EXPECTED_FITTING_CHECKS),
                              (audit.JOURNAL_COVERAGE,audit.EXPECTED_JOURNAL_CHECKS)):
            line=marker+f' {count} checks; actual runtime\n'
            invalid.extend([
                (complete.replace(line,''),0),
                (complete.replace(marker,'Old adapter only:'),0),
                (complete.replace(line,marker+' 1 checks; partial runtime\n'),0),
                (complete.replace(line,marker+' 0 checks; absent runtime\n'),0),
                (complete.replace(line,marker+f' {count+1} checks; unreviewed extension\n'),0),
                (complete+line,0),
                (complete+marker+' malformed duplicate\n',0),
                (complete.replace(line,marker+f' {count} checks\n'),0),
                (complete.replace(line,marker+f' +{count} checks; invalid count\n'),0),
                (complete.replace(line,marker+f' 0{count} checks; invalid count\n'),0),
                (complete.replace(line,marker+f' {count}.0 checks; invalid count\n'),0),
                (complete+marker.removesuffix(':')+' missing delimiter\n',0),
                (complete.replace(line,marker.removesuffix(':')+f' {count} checks; malformed marker\n'),0),
            ])
        invalid.extend((complete+marker+' 490 checks; obsolete\n',0) for marker in audit.OLD_COVERAGE)
        for text, code in invalid:
            with self.subTest(text=text,code=code):
                self.assertIsNone(audit.completed_pack_checks(text,code))

    def test_runtime_version_count_and_new_scope_stay_pinned(self):
        from unittest.mock import patch
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        self.assertEqual(audit.EXPECTED_PRESERVED_CHECKS,1471)
        self.assertEqual(audit.EXPECTED_UNIFIED_CHECKS,1247)
        self.assertEqual(audit.EXPECTED_EXPLORATION_CHECKS,349)
        self.assertEqual(audit.EXPECTED_CONDITION_CHECKS,191)
        self.assertEqual(audit.EXPECTED_TRANSFER_CHECKS,363)
        self.assertEqual(audit.EXPECTED_CONSIGNEE_CHECKS,1036)
        self.assertEqual(audit.EXPECTED_POLISH_CHECKS,460)
        self.assertEqual(audit.EXPECTED_CAPSTONE_CHECKS,1179)
        self.assertEqual(audit.EXPECTED_FITTING_CHECKS,12369)
        self.assertEqual(audit.EXPECTED_JOURNAL_CHECKS,2832)
        self.assertEqual(audit.EXPECTED_SOURCE_CHECKS,18752+audit.EXPECTED_JOURNAL_CHECKS)
        self.assertEqual(audit.EXPECTED_CHECKS,18757+audit.EXPECTED_JOURNAL_CHECKS)
        self.assertEqual(audit.EXPECTED_CHECKS,92+audit.EXPECTED_PRESERVED_CHECKS+audit.EXPECTED_UNIFIED_CHECKS+audit.EXPECTED_EXPLORATION_CHECKS+audit.EXPECTED_CONDITION_CHECKS+audit.EXPECTED_TRANSFER_CHECKS+audit.EXPECTED_CONSIGNEE_CHECKS+audit.EXPECTED_POLISH_CHECKS+audit.EXPECTED_CAPSTONE_CHECKS+audit.EXPECTED_FITTING_CHECKS+audit.EXPECTED_JOURNAL_CHECKS)
        self.assertEqual(audit.EXPECTED_SOURCE_CHECKS,audit.EXPECTED_CHECKS-5)
        self.assertGreater(audit.EXPECTED_UNIFIED_CHECKS,0)
        self.assertGreater(audit.EXPECTED_PRESERVED_CHECKS,0)
        self.assertGreater(audit.EXPECTED_CHECKS,audit.EXPECTED_UNIFIED_CHECKS+audit.EXPECTED_PRESERVED_CHECKS)
        self.assertNotEqual(audit.EXPECTED_CHECKS,3215)
        self.assertIn('== "0.0.32"',driver)
        self.assertIn('title.text=="0.0.32"',driver)
        self.assertNotIn('"0.0.21"',driver)
        self.assertIn('await _test_unified_pack()\n\tawait _test_condition_pack()\n\tawait _test_transfer_pack()\n\tawait _test_consignee_pack()\n\tawait _test_heting_polish_pack()\n\tawait _test_capstone_pack()\n\tawait _test_fitting_pack()\n\tawait _test_journal_pack()\n\tawait _finish_run(rehearsal)',driver)
        self.assertNotIn('game._battle_action(',driver)
        self.assertNotIn('res://tests/unified_ui_test_driver.gd',driver)
        for name in ('EXPECTED_UNIFIED_CHECKS','EXPECTED_PRESERVED_CHECKS','EXPECTED_EXPLORATION_CHECKS','EXPECTED_CONDITION_CHECKS','EXPECTED_TRANSFER_CHECKS','EXPECTED_CONSIGNEE_CHECKS','EXPECTED_POLISH_CHECKS','EXPECTED_CAPSTONE_CHECKS','EXPECTED_FITTING_CHECKS','EXPECTED_JOURNAL_CHECKS'):
            with patch.object(audit,name,0):
                self.assertIsNone(audit.completed_pack_checks(self.complete_log(),0))

    def test_malformed_extra_summary_and_indented_errors_fail_closed(self):
        complete=self.complete_log()
        for extra in ('PASS: malformed duplicate', 'FAIL: aborted before summary',
                      ' PASS: malformed duplicate', '\tERROR: resource failed',
                      '  SCRIPT ERROR: interrupted assertion',
                      ' '+audit.COMPLETE_SCOPE,
                      ' '+audit.EXPLORATION_COVERAGE+' malformed duplicate',
                      ' '+audit.CONDITION_COVERAGE+' malformed duplicate',
                      ' '+audit.TRANSFER_COVERAGE+' malformed duplicate',
                      ' '+audit.CONSIGNEE_COVERAGE+' malformed duplicate',
                      ' '+audit.POLISH_COVERAGE+' malformed duplicate',
                      ' '+audit.CAPSTONE_COVERAGE+' malformed duplicate',
                      ' '+audit.FITTING_COVERAGE+' malformed duplicate',
                      ' '+audit.JOURNAL_COVERAGE+' malformed duplicate'):
            with self.subTest(extra=extra):
                self.assertIsNone(audit.completed_pack_checks(complete+extra+'\n',0))

    def test_exploration_scope_cannot_impersonate_full_pack(self):
        complete=self.complete_log()
        for scope in ('exploration-only','preserved-only','unified-only','condition-only','transfer-only','consignee-only','polish-only','capstone-only','fitting-only','journal-only'):
            self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: '+scope),0))
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        self.assertIn('await _test_exploration_pack()\n\tawait _test_unified_pack()',driver)
        self.assertIn('not _exploration_prerequisites()',driver)
        self.assertIn('HashingContext.HASH_SHA256',driver)
        self.assertIn('_test_qin_idle_pack(qin, all_hashes)',driver)
        self.assertIn('painted_qin_idle.png',driver)
        self.assertIn('qin.idle_texture_for(direction)',driver)
        self.assertIn('texture.atlas != qin.texture_for(direction,0).atlas',driver)
        self.assertNotIn('res://tests/party_exploration_fixture.gd',driver)
        self.assertIn('not _condition_prerequisites()',driver)
        self.assertIn('await _test_condition_pack()',driver)
        self.assertIn(audit.CONDITION_COVERAGE,driver)
        self.assertIn('res://scripts/exploration_companion_condition.gd',driver)
        self.assertIn('InputEventMouseButton.new()',driver)
        self.assertNotIn('res://tests/companion_condition',driver)

    def test_reject_inconsistent_gate_configuration(self):
        from unittest.mock import patch
        complete=self.complete_log()
        for field,value in (('EXPECTED_SOURCE_CHECKS',audit.EXPECTED_SOURCE_CHECKS+1),
                            ('EXPECTED_CHECKS',audit.EXPECTED_CHECKS+1),
                            ('EXPECTED_CONDITION_CHECKS',audit.EXPECTED_CONDITION_CHECKS+1),
                            ('EXPECTED_TRANSFER_CHECKS',audit.EXPECTED_TRANSFER_CHECKS+1),
                            ('EXPECTED_CONSIGNEE_CHECKS',audit.EXPECTED_CONSIGNEE_CHECKS+1),
                            ('EXPECTED_POLISH_CHECKS',audit.EXPECTED_POLISH_CHECKS+1),
                            ('EXPECTED_CAPSTONE_CHECKS',audit.EXPECTED_CAPSTONE_CHECKS+1),
                            ('EXPECTED_FITTING_CHECKS',audit.EXPECTED_FITTING_CHECKS+1),
                            ('EXPECTED_JOURNAL_CHECKS',audit.EXPECTED_JOURNAL_CHECKS+1),
                            ('EXPECTED_PRESERVED_CHECKS',audit.EXPECTED_PRESERVED_CHECKS+1),
                            ('EXPECTED_UNIFIED_CHECKS',audit.EXPECTED_UNIFIED_CHECKS+1)):
            with self.subTest(field=field),patch.object(audit,field,value):
                self.assertIsNone(audit.completed_pack_checks(complete,0))

    def test_transfer_is_actual_packed_runtime_with_preinstantiation_gate(self):
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        prerequisite=driver.index('not _transfer_prerequisites()')
        self.assertLess(prerequisite,driver.index('game = scene.instantiate()'))
        self.assertIn(audit.TRANSFER_COVERAGE,driver)
        for module in ('local_save_transfer','browser_save_transfer','save_transfer_ui'):
            self.assertIn('"'+module+'"',driver)
            self.assertNotIn('preload("res://scripts/'+module+'.gd")',driver)
        for actual in ('inspect_save_bytes(bytes)','helper.export_slot(slot,backup)',
                       'helper.preview_import(bytes,slot)','helper.commit_import(first.token)',
                       'script.source_code = """extends "res://scripts/local_save_transfer.gd"',
                       'TransferPackBrowser.new()', 'panel.dispose()',
                       'game.battle_art.hit("flee", {"valid":true})',
                       'game.web_save_transfer_enabled = true',
                       'not game.web_save_transfer_enabled',
                       'await _key(KEY_ESCAPE)'):
            self.assertIn(actual,driver)
        self.assertNotIn('res://tests/save_transfer',driver)
        self.assertNotIn('res://tests/local_save_transfer',driver)
        self.assertIn('no browser download or durability claim',driver)

    def test_transfer_rehearsal_and_old_web25_cannot_impersonate_pack(self):
        complete=self.complete_log()
        old='\n'.join(line for line in complete.splitlines() if not line.startswith(audit.TRANSFER_COVERAGE))+'\n'
        old=old.replace(str(audit.EXPECTED_CHECKS)+' exported-pack','3350 exported-pack')
        self.assertIsNone(audit.completed_pack_checks(old,0))
        for line in ('PASS: 404 source-rehearsal checks; 0 failures',
                     f'PASS: {audit.EXPECTED_SOURCE_CHECKS} source-rehearsal checks; 0 failures',
                     'FAIL: current package prerequisites; 43 checks; 1 failures; no game instantiated'):
            self.assertIsNone(audit.completed_pack_checks(line+'\n',0))

    def test_polish_runtime_is_separate_actual_and_bounded(self):
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        self.assertIn(audit.POLISH_COVERAGE,driver)
        self.assertIn('await _test_consignee_pack()\n\tawait _test_heting_polish_pack()\n\tawait _test_capstone_pack()\n\tawait _test_fitting_pack()\n\tawait _test_journal_pack()\n\tawait _finish_run(rehearsal)',driver)
        for actual in ('scenery.prepare()', 'scenery.draw(self,floor_mesh,encounter,.375)',
                       'mesh.surface_get_arrays(0)', 'art._make_floor()',
                       'harbor._route_label(probe,item.p,item.text,item.size,item.width,HORIZONTAL_ALIGNMENT_CENTER)',
                       'font.get_texture_image(0,cache_size,texture_index)',
                       'font.render_glyph(0,cache_size,glyph)', 'unique_labels.size() == 4 and labels.size() == 5',
                       'game.state.SAVE_VERSION == 16 and not game.web_save_transfer_enabled',
                       'no native framebuffer or browser pixel acceptance'):
            self.assertIn(actual,driver)
        for fixture in ('warehouse_backdrop_polish_test','heting_route_label_test'):
            self.assertNotIn('res://tests/'+fixture,driver)
        self.assertNotIn('FileAccess.get_file_as_string("res://scripts/heting_region.gd")',driver)

    def test_old_web27_or_partial_polish_cannot_impersonate_current_pack(self):
        complete=self.complete_log()
        line=audit.POLISH_COVERAGE+f' {audit.EXPECTED_POLISH_CHECKS} checks; actual runtime\n'
        for old_total in (4735,4730):
            old=complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack',str(old_total)+' exported-pack')
            self.assertIsNone(audit.completed_pack_checks(old,0))
            self.assertIsNone(audit.completed_pack_checks(old.replace(line,''),0))
        for replacement in ('',audit.POLISH_COVERAGE+' 0 checks; no polish\n',
                            audit.POLISH_COVERAGE+' 1 checks; partial polish\n'):
            self.assertIsNone(audit.completed_pack_checks(complete.replace(line,replacement),0))
        self.assertIsNone(audit.completed_pack_checks(complete+line,0))
        self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: polish-only'),0))

    def test_frozen_historical_readers_are_byte_exact(self):
        root = Path(__file__).resolve().parents[1]
        self.assertEqual(audit.sha(root/'tests/fixtures/v019_game_state.gd.txt'), audit.LEGACY)
        self.assertEqual(audit.sha(root/'tests/fixtures/v020_game_state.gd.txt'), audit.SCHEMA11)
        self.assertEqual(audit.sha(root/'tests/fixtures/v022_game_state.gd.txt'), audit.SCHEMA12)
        self.assertEqual(audit.sha(root/'tests/fixtures/v017_game_state.gd.txt'), audit.SCHEMA9)
        self.assertEqual(audit.sha(root/'tests/fixtures/v025_game_state.gd.txt'), audit.SCHEMA13)
        self.assertEqual(audit.verify_legacy_fixtures(root/'tests/fixtures/legacy_saves'), audit.LEGACY_FIXTURES)

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

    def test_consignee_preinstantiation_gate_and_genuine_migration(self):
        root=Path(__file__).resolve().parents[1]
        driver=(root/'tools/smoke_export.gd').read_text(encoding='utf-8')
        for gate in ('not _consignee_prerequisites()', 'not _consignee_legacy_prerequisite(rehearsal)'):
            self.assertLess(driver.index(gate),driver.index('game = scene.instantiate()'))
        for value in ('--schema13-reader=','--legacy-save-fixtures=',audit.SCHEMA13,audit.LEGACY_FIXTURES,
                      'schema13_reader.SAVE_VERSION == 13','schema13_reader.load_game(path) == ERR_FILE_UNRECOGNIZED',
                      'schema13_reader.to_dict(),genuine.player','inspected.state.to_dict()[key] == neutral[key]',
                      'for version: int in range(1,14)',audit.CONSIGNEE_COVERAGE):
            self.assertIn(value,driver)
        self.assertIn('for kind: String in encounters.IDS.slice(0,10)',driver)
        self.assertIn('const CONSIGNEE_FIELDS:',driver)
        self.assertNotIn('res://tests/heting_consignee_',driver)
        for value in ('game.consignee_story.link_label(site)', 'await _key(KEY_E)',
                      'panel.unit_plates.consignee_guard.pressed.emit()', 'await _key(KEY_TAB)',
                      's.coins == coins+60', '_receipt_xp() == xp+120',
                      'store.load_backup(probe,1)', '_receipt_block_save()'):
            self.assertIn(value,driver)

    def test_old_web26_and_partial_chapter_cannot_impersonate_current_pack(self):
        complete=self.complete_log()
        for count in (3692,3687,3350,1107):
            old=complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack',str(count)+' exported-pack')
            self.assertIsNone(audit.completed_pack_checks(old,0))
        old='\\n'.join(line for line in complete.splitlines() if not line.startswith(audit.CONSIGNEE_COVERAGE))+'\\n'
        self.assertIsNone(audit.completed_pack_checks(old,0))
        self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: consignee-only'),0))

    def test_legacy_fixture_bytes_are_fail_closed_and_read_only(self):
        import shutil
        root=Path(__file__).resolve().parents[1]
        with tempfile.TemporaryDirectory() as temp:
            target=Path(temp)/'legacy'
            shutil.copytree(root/'tests/fixtures/legacy_saves',target)
            before={p.name:audit.sha(p) for p in target.iterdir()}
            self.assertEqual(audit.verify_legacy_fixtures(target),audit.LEGACY_FIXTURES)
            self.assertEqual(before,{p.name:audit.sha(p) for p in target.iterdir()})
            (target/'schema_13_default.json').write_text('{}')
            with self.assertRaises(RuntimeError):audit.verify_legacy_fixtures(target)
            shutil.copy2(root/'tests/fixtures/legacy_saves/schema_13_default.json',target/'schema_13_default.json')
            (target/'provenance.json').write_text('{}')
            with self.assertRaises(RuntimeError):audit.verify_legacy_fixtures(target)

    def test_audit_inputs_bind_tools_readers_and_fixtures(self):
        root=Path(__file__).resolve().parents[1]
        inputs=audit.audit_inputs()
        self.assertEqual(len(inputs),33)
        self.assertEqual(inputs['tools/smoke_export.gd'],audit.sha(root/'tools/smoke_export.gd'))
        self.assertEqual(inputs['tests/fixtures/v025_game_state.gd.txt'],audit.SCHEMA13)
        self.assertEqual(inputs['tests/fixtures/legacy_saves/provenance.json'],audit.LEGACY_FIXTURES)
        wrapper=(root/'tools/audit_web_export.py').read_text(encoding='utf-8')
        pack_main=wrapper[wrapper.index('def main():'):]
        self.assertLess(pack_main.index('inputs=audit_inputs()'),pack_main.index('result=subprocess.run'))
        self.assertGreater(pack_main.index('audit_inputs()!=inputs'),pack_main.index('result=subprocess.run'))


    def test_capstone_preinstantiation_gate_and_authentic_old_controls(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        for gate in ('not _capstone_prerequisites()', 'not _capstone_legacy_prerequisite(rehearsal)'):
            self.assertLess(driver.index(gate),driver.index('game = scene.instantiate()'))
        for value in ('--schema14-reader=', '--schema14-save=', audit.SCHEMA14,audit.SCHEMA14_SAVE,
                      'schema14_reader.SAVE_VERSION == 14', 'schema14_reader.save_game(path)',
                      'schema14_reader.load_game(path) == ERR_FILE_UNRECOGNIZED',
                      'schema13_reader.load_game(path) == ERR_FILE_UNRECOGNIZED',
                      'for version: int in [13,14,15]', 'for key: String in canonical',
                      'for version: int in range(1,15)', audit.CAPSTONE_COVERAGE,
                      'game.capstone_story.get_script()', 's._valid_capstone_terminal(forged)',
                      'snapshot.enemies[0].max_hp == 620', 's.coins == coins+80', '_receipt_xp() == xp+160',
                      'game.world.capstone_goal == goal', 'portraits.attach(probe,', 'art.draw(self,',
                      'source PNG', 'current dependencies, not full-old-runtime'):
            self.assertIn(value,driver)
        self.assertNotIn('res://tests/capstone_',driver)
        self.assertNotIn('"version":14,"player":model.new().to_dict()',driver)
        self.assertEqual(audit.sha(audit.ROOT/'tests/fixtures/v028_game_state.gd.txt'),audit.SCHEMA14)
        pins=audit.verify_capstone_inputs()
        self.assertEqual(pins['tests/fixtures/capstone/schema_14_default.json'],audit.SCHEMA14_SAVE)

    def test_capstone_absent_partial_duplicate_or_wrong_counts_fail_closed(self):
        complete=self.complete_log()
        marker=audit.CAPSTONE_COVERAGE
        line=marker+f' {audit.EXPECTED_CAPSTONE_CHECKS} checks; actual runtime\n'
        for replacement in ('', marker+' 0 checks; absent\n', marker+' 1 checks; partial\n',
                            marker+f' {audit.EXPECTED_CAPSTONE_CHECKS+1} checks; wrong\n',
                            'Schema14 capstone chapter exact-runtime coverage: 1 checks; wrong\n',
                            marker+f' {audit.EXPECTED_CAPSTONE_CHECKS} checks\n'):
            self.assertIsNone(audit.completed_pack_checks(complete.replace(line,replacement),0))
        self.assertIsNone(audit.completed_pack_checks(complete+line,0))
        self.assertIsNone(audit.completed_pack_checks(complete+marker+' malformed duplicate\n',0))
        self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: capstone-only'),0))
        for count in (5195,5190):
            self.assertIsNone(audit.completed_pack_checks(complete.replace(str(audit.EXPECTED_CHECKS)+' exported-pack',str(count)+' exported-pack'),0))

    def test_source_rehearsal_requires_exact_five_pending_and_all_nine_partitions(self):
        complete=self.complete_log()
        rehearsal=audit.SOURCE_PENDING+'\n'+complete.replace(
            f'PASS: {audit.EXPECTED_CHECKS} exported-pack',f'PASS: {audit.EXPECTED_SOURCE_CHECKS} source-rehearsal')
        self.assertEqual(audit.completed_source_checks(rehearsal,0),audit.EXPECTED_SOURCE_CHECKS)
        self.assertIsNone(audit.completed_pack_checks(rehearsal,0))
        for bad in (rehearsal.replace('exactly5','exactly4'),rehearsal.replace(audit.SOURCE_PENDING,''),
                    rehearsal+audit.SOURCE_PENDING+'\n',rehearsal.replace('PENDING','PASS'),
                    rehearsal.replace('scope: complete','scope: capstone-only'),
                    rehearsal+'ERROR: failed\n',rehearsal+'PASS: extra\n'):
            self.assertIsNone(audit.completed_source_checks(bad,0))
        self.assertIsNone(audit.completed_source_checks(rehearsal,1))

    def test_provenance_is_real_pack_input_and_all_source_pins_are_immutable(self):
        import shutil
        files=('combat-v4-review.json','combat-v4-measurements.json','portrait-v1-review.json')
        filters=[line for line in (audit.ROOT/'export_presets.cfg').read_text().splitlines() if line.startswith('include_filter=')]
        self.assertEqual(len(filters),4)
        for line in filters:
            for name in files:self.assertIn('assets/generated/characters/liang_provenance/'+name,line)
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            for name in audit.verify_capstone_inputs():
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(audit.ROOT/name,target)
            self.assertEqual(audit.verify_capstone_inputs(root),audit.verify_capstone_inputs())
            for name in audit.verify_capstone_inputs():
                target=root/name;old=target.read_bytes();target.write_bytes(old+b'changed')
                with self.assertRaises(RuntimeError):audit.verify_capstone_inputs(root)
                target.write_bytes(old)
        inputs=audit.audit_inputs()
        self.assertEqual(inputs['tests/fixtures/v028_game_state.gd.txt'],audit.SCHEMA14)
        self.assertEqual(inputs['tests/fixtures/capstone/schema_14_default.json'],audit.SCHEMA14_SAVE)
        wrapper=(audit.ROOT/'tools/audit_web_export.py').read_text()
        self.assertIn('directory.mkdir(parents=True,exist_ok=False)',wrapper)
        self.assertIn("'pending_pack_only_checks':5",wrapper)
        self.assertIn('before=source_snapshot()',wrapper)
        self.assertIn('after=source_snapshot()',wrapper)
        self.assertIn("'provisional':bool(changed)",wrapper)

if __name__=='__main__':unittest.main()
