"""Portable static/unit checks only; never launch an engine or access Windows."""
import ast
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest

HERE=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('capture_only',HERE/'capture_imported_windows.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)

class CaptureChecks(unittest.TestCase):
    def test_python_ast(self): ast.parse((HERE/'capture_imported_windows.py').read_text())
    def test_frozen_manifest(self): self.assertEqual(m.sha(HERE/'source-sha256.json'),m.MANIFEST_SHA)
    def test_source_sidecars_and_cache_are_distinct(self):
        original={'scripts/a.gd':'a','assets/a.png':'b'}
        generated={p:{'bytes':1,'sha256':'0'*64} for p in ['scripts/a.gd.uid','assets/a.png.import','.godot/imported/a.ctex']}
        effective,cache=m.validate_generated(original,generated)
        self.assertEqual(len(effective),4);self.assertEqual(list(cache),['.godot/imported/a.ctex'])
    def test_generated_cannot_replace_original(self):
        with self.assertRaises(RuntimeError):m.validate_generated({'a':'a'},{'a':{'bytes':1,'sha256':'0'*64}})
    def test_unsafe_generated_paths(self):
        for p in ['.godot/../bad','.godot//bad','.godot/C:stream','other.gd','/abs','bad\\path']:
            with self.subTest(path=p),self.assertRaises(RuntimeError):m.validate_generated({}, {p:{'bytes':1,'sha256':'0'*64}})
    def test_empty_existing_user_is_allowed(self):
        with tempfile.TemporaryDirectory() as d:
            self.assertTrue(m.inspect_empty_user(Path(d))['directory_exists'])
    def test_shader_cache_is_separate(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'shader_cache').mkdir();(p/'shader_cache'/'engine.bin').write_bytes(b'cache')
            result=m.inspect_empty_user(p)
            self.assertEqual(result['application_files'],{});self.assertEqual(len(result['engine_shader_cache']),1)
    def test_existing_application_data_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);(p/'hero_save.json').write_text('{}')
            with self.assertRaises(RuntimeError):m.inspect_empty_user(p)
    def test_direct_gui_identity_without_marker_changes(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);engine=p/'Godot.exe';engine.write_bytes(b'not executed');marker=p/'_sc_';marker.write_bytes(b'preserve')
            report={'engine':str(engine),'engine_sha256':m.sha(engine)}
            self.assertEqual(m.validate_engine(report)[2],'direct_gui');self.assertEqual(marker.read_bytes(),b'preserve')
            report['engine_sha256']='0'*64
            with self.assertRaises(RuntimeError):m.validate_engine(report)
    def test_optional_wrapper_binding(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d);engine=p/'Godot.exe';engine.write_bytes(b'not executed');wrapper=p/'Godot.console.exe';wrapper.write_bytes(b'not executed wrapper')
            self.assertEqual(m.validate_engine({'engine':str(engine),'engine_sha256':m.sha(engine)},str(wrapper),m.sha(wrapper))[2],'console_wrapper')
    def test_no_import_stage_or_marker_manipulation(self):
        text=(HERE/'capture_imported_windows.py').read_text()
        self.assertNotIn("'--editor'",text);self.assertNotIn("'--import'",text);self.assertNotIn('shutil.',text)
        self.assertIn('full_process_tree_gate',text)
    def test_pre_main_guards_and_route_tuple_retained(self):
        text=(HERE/'first_render.gd').read_text()
        self.assertNotIn('preload(',text)
        self.assertLess(text.index('Missing owned profile claim'),text.index('load("res://scripts/game_state.gd")'))
        for marker in ['mist_rain_gauge','app.world.journal_guidance_snapshot == snap','app.hud.journal_guidance_snapshot == snap','folio().guidance_snapshot == snap','prelaunch_application_files','project_cache_at_pre_main']:
            self.assertIn(marker,text)
    def test_inventory_errors_are_fail_closed(self):
        text=(HERE/'first_render.gd').read_text()
        self.assertIn('directory.include_hidden = true',text)
        self.assertIn('directory.list_dir_begin() != OK',text)
        self.assertIn('digest.length() != 64 or not digest.is_valid_hex_number(false)',text)
        self.assertIn('not io_failed and evidence.after_state == before',text)
        self.assertIn('Explicitly observed absence, not an open failure',text)
    def test_error_scan(self):
        for line in ['SCRIPT ERROR: x',' ERROR: x','Parse Error: x']:
            self.assertTrue(m.ERROR_LINE.search(line))

if __name__=='__main__':unittest.main(verbosity=2)
