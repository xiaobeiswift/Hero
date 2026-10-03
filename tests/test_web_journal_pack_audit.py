"""Journal package gate grammar/pins only. Synthetic totals are not gameplay counts."""
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import audit_web_export as audit
import test_web_fitting_pack_audit as fitting_helpers


class JournalPackAuditTests(unittest.TestCase):
    def test_journal_is_a_distinct_mandatory_tenth_partition(self):
        helper=fitting_helpers.FittingPackAuditTests()
        with helper.synthetic_counts():
            complete=helper.complete()
            self.assertEqual(audit.completed_pack_checks(complete,0),audit.EXPECTED_CHECKS)
            marker=audit.JOURNAL_COVERAGE
            line=next(line for line in complete.splitlines() if line.startswith(marker))+'\n'
            for replacement in ('',line.replace('10 checks','0 checks'),line.replace('10 checks','9 checks'),
                                line.replace('10 checks','11 checks'),line.replace('10 checks','010 checks'),
                                line.replace('10 checks','+10 checks'),line.replace('10 checks','10.0 checks'),
                                line.replace('coverage:','coverage'),line.replace('Schema16','Schema17')):
                self.assertIsNone(audit.completed_pack_checks(complete.replace(line,replacement),0))
            for extra in (line,' '+line,marker+' malformed duplicate\n',marker.removesuffix(':')+' delimiter missing\n'):
                self.assertIsNone(audit.completed_pack_checks(complete+extra,0))
            self.assertEqual(marker,'Schema16 journal guidance exact-runtime coverage:')
            self.assertIsNone(audit.completed_pack_checks(complete.replace('scope: complete','scope: journal-only'),0))

    def test_journal_unmeasured_gate_cannot_be_bypassed_by_log_count(self):
        helper=fitting_helpers.FittingPackAuditTests()
        with helper.synthetic_counts():
            complete=helper.complete()
            for value in (0,-1,9,11):
                with patch.object(audit,'EXPECTED_JOURNAL_CHECKS',value):
                    self.assertIsNone(audit.completed_pack_checks(complete,0))
            for old in (18757,18752):
                self.assertIsNone(audit.completed_pack_checks(complete.replace(f'PASS: {audit.EXPECTED_CHECKS}',f'PASS: {old}'),0))

    def test_python_identity_helper_is_process_local_and_windows_safe(self):
        import os
        before=dict(os.environ)
        for platform in ('posix','nt'):
            with tempfile.TemporaryDirectory(prefix='journal path with spaces ') as directory:
                env=audit.audit_environment(Path(directory),platform)
                self.assertEqual(env['HERO_AUDIT_PYTHON'],sys.executable)
                self.assertTrue(Path(env['HERO_AUDIT_PYTHON']).is_file())
                self.assertEqual(dict(os.environ),before)
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        self.assertIn('OS.execute(python,PackedStringArray(["-c",code,ProjectSettings.globalize_path("user://")]),output)',driver)
        self.assertIn('if not python.is_empty() else -1',driver)
        self.assertIn('status == 0 and output.size() == 1',driver)
        self.assertIn('str(s.st_ino),str(s.st_mtime_ns)',driver)

    def test_original117_oracle_and_fourteen_differences_are_byte_pinned(self):
        pins=audit.verify_journal_inputs()
        self.assertEqual(pins,{'tests/journal_guidance_frozen_oracle.json':'38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443'})
        self.assertEqual({name:audit.audit_inputs()[name] for name in pins},pins)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);name=next(iter(pins));target=root/name
            target.parent.mkdir(parents=True);shutil.copy2(audit.ROOT/name,target)
            before=target.read_bytes();self.assertEqual(audit.verify_journal_inputs(root),pins)
            self.assertEqual(target.read_bytes(),before)
            target.write_bytes(before+b'\n')
            with self.assertRaises(RuntimeError): audit.verify_journal_inputs(root)
            target.unlink()
            with self.assertRaises(RuntimeError): audit.verify_journal_inputs(root)

    def test_oracle_gate_precedes_scene_and_is_external_in_both_modes(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        wrapper=(audit.ROOT/'tools/audit_web_export.py').read_text(encoding='utf-8')
        for gate in ('not _journal_prerequisites()','not _journal_oracle_prerequisite(rehearsal)'):
            self.assertLess(driver.index(gate),driver.index('game = scene.instantiate()'))
        self.assertEqual(wrapper.count("'--journal-oracle='+str(ROOT/'tests/journal_guidance_frozen_oracle.json')"),2)
        self.assertIn('path.is_absolute_path()',driver)
        self.assertIn('FileAccess.get_sha256(path) == JOURNAL_ORACLE_SHA256',driver)
        self.assertIn('visited.size() == 117 and changed == 14 and repairs.size() == 14',driver)
        self.assertNotIn('load("res://tests/journal_',driver)
        self.assertNotIn('preload("res://tests/journal_',driver)
        self.assertIn('audit_inputs()!=inputs',wrapper)
        self.assertIn('verify_journal_inputs()',wrapper)

    def test_original_partitions_and_legacy_checks_are_not_removed(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        for label in ('Packed journal retains pending invitation:',
                      'Packed journal preserves personal quest ending:',
                      'Packed journal records third chapter and chosen ending',
                      'Packed journal marks the personal story complete:',
                      'Packed journal retains learned technique and recovered lore',
                      'Actual journal includes chapter record and remains read-only'):
            self.assertIn(label,driver)
        for literal in ('工册已传给学徒','原稿与水令一同留存','先鸣渡船钟','✓ 把照护约','苇心残碑已拓录','留刻度，不留渡价'):
            self.assertIn(literal,driver)
        self.assertIn('JOURNAL LEGACY COVERAGE LEDGER',driver)
        self.assertIn('page.size.y==720 and chart.size==Vector2(780,330) and chart.position.y==255',driver)
        self.assertIn('paper.encloses(caption.get_rect())',driver)
        self.assertIn('Audit forced host replacement',driver)
        self.assertIn('panel._pending_generation == pending.pending',driver)
        self.assertIn('protected and not game.overlay.get_meta("save_transfer",false)',driver)
        self.assertIn('与唐栖商议同行',driver)
        self.assertIn('game.state.tangqi_stage == 3 and not game.state.tangqi_unlocked',driver)
        expected={'PRESERVED':1471,'UNIFIED':1247,'EXPLORATION':349,'CONDITION':191,
                  'TRANSFER':363,'CONSIGNEE':1036,'POLISH':460,'CAPSTONE':1179,'FITTING':12369}
        self.assertEqual({name:getattr(audit,'EXPECTED_'+name+'_CHECKS') for name in expected},expected)

    def test_capstone_prose_mapping_is_exact_and_bounded_to_frozen_rows(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        for literal in ('String(row.label).begins_with("capstone_") and int(row.state.capstone_stage) < 7',
                        'expected_hint == core+suffix',
                        'core == String(game.state.Capstone.goal(game.state).objective)',
                        'row.context.markers[expected].name',
                        'game.hint_label.text == core+rendered_suffix',
                        'game.journal_guidance_snapshot.next_action == expected_hint'):
            self.assertIn(literal,driver)
        oracle=json.loads((audit.ROOT/'tests/journal_guidance_frozen_oracle.json').read_text())
        count=0
        for row in oracle['rows']:
            if not row['label'].startswith('capstone_') or row['state']['capstone_stage']>=7: continue
            count+=1;old=row['frozen_observation']['hint'];target=row['frozen_observation']['target']
            core=old.split(' 先沿')[0]
            suffix=' 先沿'+row['context']['markers'][target]['name']+'行路。' if ' 先沿' in old else ''
            self.assertEqual(old,core+suffix)
        self.assertEqual(count,35)

    def test_actual_runtime_control_safety_and_no_new_migration_contract(self):
        driver=(audit.ROOT/'tools/smoke_export.gd').read_text(encoding='utf-8')
        journal=driver[driver.index('func _journal_prerequisites()'):]
        for literal in ('game.get_script() == load("res://scripts/main.gd")',
                        'game.state.get_script().resource_path == "res://scripts/game_state.gd"',
                        'game.state.SAVE_VERSION == 16','_journal_tuple(game.world.journal_guidance_snapshot)',
                        '_journal_tuple(game.hud.journal_guidance_snapshot)',
                        'chart.cart_route == value.cart_route','await _fitting_key(KEY_ENTER)',
                        'game.state.position = game.world.player_pos + Vector2(-9,0)',
                        '_receipt_variables(game.state) == before.state','_journal_disk() == before.files',
                        'region.can_step(route[index-1],route[index],game.state.heting_bridge,true)',
                        'game.save_slots.perform_load(1,false)','transfer.cancel_preview(preview.token)',
                        'transfer.commit_import(preview.token)','not game.web_save_transfer_enabled',
                        'same-State quickload resets session','cancelled actual manual-load prompt retains selection',
                        'failed quickload retains selection','storage-only import retains active journey',
                        'tracked_arc_id','journal_guidance','actual new journey resets transient selection',
                        'captured.is_valid()', 'stale replay requires previously captured still-live callback',
                        'panel.close(); game._show_map()', 'valid local target never carries unavailable default prose',
                        'genuinely unavailable route retains explanatory note and no marker'):
            self.assertIn(literal,journal)
        self.assertNotIn('game.set_process(false)',journal)
        self.assertNotIn('extends "res://scripts/game_state.gd"',journal)
        self.assertNotIn('"version":17',journal)
        self.assertIn('Web30 full-PCK compatibility separate',journal)


if __name__=='__main__': unittest.main()
