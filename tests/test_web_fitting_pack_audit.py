"""Independent fail-closed unit gates. Synthetic parser numbers are not runtime counts."""
import contextlib
import importlib.util
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import audit_web_export as audit


class FittingPackAuditTests(unittest.TestCase):
    # Deliberately tiny synthetic grammar fixture, unrelated to measured gameplay.
    COUNTERS=('PRESERVED','UNIFIED','EXPLORATION','CONDITION','TRANSFER','CONSIGNEE','POLISH','CAPSTONE','FITTING','JOURNAL')

    @contextlib.contextmanager
    def synthetic_counts(self):
        with contextlib.ExitStack() as stack:
            for index,name in enumerate(self.COUNTERS,1):
                stack.enter_context(patch.object(audit,'EXPECTED_'+name+'_CHECKS',index))
            total=92+sum(range(1,11))
            stack.enter_context(patch.object(audit,'EXPECTED_CHECKS',total))
            stack.enter_context(patch.object(audit,'EXPECTED_SOURCE_CHECKS',total-5))
            yield

    def complete(self):
        rows=[audit.COMPLETE_SCOPE]
        for name in self.COUNTERS:
            rows.append(getattr(audit,name+'_COVERAGE')+' '+str(getattr(audit,'EXPECTED_'+name+'_CHECKS'))+' checks; synthetic parser fixture only')
        rows.append(f'PASS: {audit.EXPECTED_CHECKS} exported-pack checks; 0 failures')
        return '\n'.join(rows)+'\n'

    def test_ten_partitions_all_required_without_relabelling(self):
        with self.synthetic_counts():
            text=self.complete()
            self.assertEqual(audit.completed_pack_checks(text,0),audit.EXPECTED_CHECKS)
            for name in self.COUNTERS:
                marker=getattr(audit,name+'_COVERAGE')
                line=next(line for line in text.splitlines() if line.startswith(marker))+'\n'
                for altered in ('',marker+' 0 checks; missing\n',marker+' 999 checks; wrong\n',
                                marker+' 1.0 checks; wrong\n',marker+' +1 checks; wrong\n',
                                marker+' 01 checks; wrong\n',marker+' malformed\n'):
                    self.assertIsNone(audit.completed_pack_checks(text.replace(line,altered),0))
                for extra in (line,marker+' malformed duplicate\n','  '+marker+' malformed duplicate\n'):
                    self.assertIsNone(audit.completed_pack_checks(text+extra,0))
            self.assertEqual(audit.CONSIGNEE_COVERAGE,'Schema14 consignee chapter exact-runtime coverage:')
            self.assertEqual(audit.CAPSTONE_COVERAGE,'Schema15 capstone chapter exact-runtime coverage:')
            self.assertEqual(audit.FITTING_COVERAGE,'Schema16 equipment fitting exact-runtime coverage:')

    def test_full_gate_rejects_partial_prior_source_and_error_logs(self):
        with self.synthetic_counts():
            complete=self.complete()
            for scope in ('fitting-only','capstone-only','transfer-only','preserved-only','consignee-only','unified-only','polish-only','condition-only','exploration-only','journal-only'):
                self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: '+scope),0))
            for count in (6374,6369,5195,5190,1516):
                self.assertIsNone(audit.completed_pack_checks(complete.replace(f'PASS: {audit.EXPECTED_CHECKS}',f'PASS: {count}'),0))
            for extra in ('ERROR: failure',' SCRIPT ERROR: incomplete','PASS: extra','FAIL: partial',audit.COMPLETE_SCOPE):
                self.assertIsNone(audit.completed_pack_checks(complete+extra+'\n',0))
            self.assertIsNone(audit.completed_pack_checks(complete,1))
            self.assertIsNone(audit.completed_pack_checks(audit.SOURCE_PENDING+'\n'+complete,0))

    def test_source_has_precisely_five_pending_and_same_ten_runtime_partitions(self):
        with self.synthetic_counts():
            complete=self.complete()
            source=audit.SOURCE_PENDING+'\n'+complete.replace(f'PASS: {audit.EXPECTED_CHECKS} exported-pack',f'PASS: {audit.EXPECTED_SOURCE_CHECKS} source-rehearsal')
            self.assertEqual(audit.completed_source_checks(source,0),audit.EXPECTED_SOURCE_CHECKS)
            self.assertIsNone(audit.completed_pack_checks(source,0))
            for altered in (source.replace('exactly5','exactly6'),source.replace('exactly5','exactly4'),source+audit.SOURCE_PENDING+'\n',source.replace('scope: complete','scope: fitting-only')):
                self.assertIsNone(audit.completed_source_checks(altered,0))
            with patch.object(audit,'EXPECTED_SOURCE_CHECKS',audit.EXPECTED_SOURCE_CHECKS+1):
                self.assertIsNone(audit.completed_source_checks(source,0))

    def test_unmeasured_or_inconsistent_configuration_cannot_pass(self):
        with self.synthetic_counts():
            complete=self.complete()
            for name in self.COUNTERS:
                field='EXPECTED_'+name+'_CHECKS'
                for value in (0,-1,getattr(audit,field)+1):
                    with patch.object(audit,field,value): self.assertIsNone(audit.completed_pack_checks(complete,0))
            for field in ('EXPECTED_CHECKS','EXPECTED_SOURCE_CHECKS'):
                with patch.object(audit,field,0): self.assertIsNone(audit.completed_pack_checks(complete,0))

    def test_frozen15_fixture_provenance_and_original_model_are_byte_exact(self):
        pins=audit.verify_fitting_inputs()
        self.assertEqual(pins['tests/fixtures/v029_game_state.gd.txt'],audit.SCHEMA15)
        self.assertEqual(pins['tests/fixtures/weapon_fitting/schema_15_default.json'],audit.SCHEMA15_SAVE)
        self.assertEqual(pins['tests/fixtures/weapon_fitting/legacy_automatic.gd.txt'],audit.FITTING_LEGACY_MODEL)
        self.assertEqual(audit.sha(audit.ROOT/'tests/fixtures/weapon_fitting/provenance.json'),audit.FITTING_PROVENANCE)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            for name in pins:
                target=root/name;target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(audit.ROOT/name,target)
            before={name:audit.sha(root/name) for name in pins}
            self.assertEqual(audit.verify_fitting_inputs(root),pins)
            self.assertEqual(before,{name:audit.sha(root/name) for name in pins})
            for name in pins:
                target=root/name;original=target.read_bytes();target.write_bytes(original+b'changed')
                with self.assertRaises(RuntimeError): audit.verify_fitting_inputs(root)
                target.write_bytes(original)
            target=root/'tests/fixtures/weapon_fitting/schema_15_default.json'
            target.unlink()
            with self.assertRaises(RuntimeError): audit.verify_fitting_inputs(root)

    def test_driver_requires_genuine15_before_main_and_distinct_subjects(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        for gate in ('not _fitting_prerequisites()','not _fitting_legacy_prerequisite(rehearsal)'):
            self.assertLess(driver.index(gate),driver.index('game = scene.instantiate()'))
        for expected in (audit.SCHEMA15,audit.SCHEMA15_SAVE,audit.FITTING_PROVENANCE,audit.FITTING_LEGACY_MODEL,
                         '--schema15-reader=','--schema15-save=','--fitting-legacy-model=',
                         'schema15_reader.SAVE_VERSION == 15','schema14_reader.save_game(path)',
                         'schema15_reader.save_game(path)','schema13_reader.load_game(path) == ERR_FILE_UNRECOGNIZED',
                         'schema14_reader.load_game(path) == ERR_FILE_UNRECOGNIZED',
                         'schema15_reader.load_game(output) == ERR_FILE_UNRECOGNIZED',
                         'model.new().save_game(output)','"--schema16-subject="',
                         'for version: int in [13,14,15]',
                         '(genuine14.player if version == 14 else genuine15.player)',
                         'rules.INTRODUCED_VERSION == 15 and rules.MAX_SUPPORTED_VERSION == 16',
                         'if version < 14:', 'if version < 15:', 'if version < 16: data.erase("weapon_fitting")'):
            self.assertIn(expected,driver)
        self.assertNotIn('model.new().save_game(path) == OK and JSON.parse_string(FileAccess.get_file_as_string(path)).version == 15',driver)
        self.assertNotIn('"version":15,"player":model.new().to_dict()',driver)

    def test_actual_controller_main_processing_and_full_real_state_are_not_mocked(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        fitting=driver[driver.index('func _fitting_prerequisites()'):]
        for actual in ('res://scripts/weapon_fitting_ui.gd','game.get_script() == load("res://scripts/main.gd")',
                       'game.state.get_script().resource_path == "res://scripts/game_state.gd"',
                       'InputEventMouseButton.new()','Input.parse_input_event(event)',
                       'game._process(.016)','game.is_processing()','game.set_process(true)',
                       'game.state.position = game.world.player_pos + Vector2(-9,0)',
                       'game.state.to_dict() == before.persistent','_fitting_disk() == before.files',
                       'FittingAction_confirm','FittingAction_retry_save','FittingAction_start',
                       'game.PartyUI.open_fitting(game,panel,"plain","ordinary")',
                       'game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)',
                       'session.fitting_trial_snapshot()','enemy:attack','round_end',
                       '_fitting_semantic(left) == _fitting_semantic(right)'):
            self.assertIn(actual,fitting)
        self.assertNotIn('game.set_process(false)',fitting)
        self.assertNotIn('extends "res://scripts/game_state.gd"',fitting)
        self.assertNotIn('res://tests/weapon_fitting_ui_test',fitting)
        self.assertIn('await _test_capstone_pack()\n\tawait _test_fitting_pack()\n\tawait _test_journal_pack()\n\tawait _finish_run(rehearsal)',driver)

    def test_external_inputs_remain_bound_before_and_after(self):
        inputs=audit.audit_inputs()
        for name,digest in audit.verify_fitting_inputs().items():
            self.assertEqual(inputs[name],digest)
        wrapper=(audit.ROOT/'tools/audit_web_export.py').read_text(encoding='utf-8')
        for value in ("'fitting_checks':EXPECTED_FITTING_CHECKS if passed else None", "'save_schema':16", "'schema16_subject_sha256'",'complete-old15 process on this subject is a separate later gate'):
            self.assertIn(value,wrapper)


if __name__=='__main__': unittest.main()
