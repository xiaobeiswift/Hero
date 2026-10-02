import importlib.util
import os
from pathlib import Path, PureWindowsPath, PurePosixPath
import signal
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch, Mock

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import export_web

class WebExportPortability(unittest.TestCase):
    def test_manifest_and_archive_names_are_platform_independent(self):
        for kind, base in ((PureWindowsPath,'C:/Hero project'),(PurePosixPath,'/tmp/Hero project')):
            root=kind(base)
            name=export_web.relative_name(root/'licenses/GODOT-LICENSE.txt',root)
            self.assertEqual(name,'licenses/GODOT-LICENSE.txt')
            self.assertEqual('Hero-Web/'+name,'Hero-Web/licenses/GODOT-LICENSE.txt')

    def test_project_relative_templates_are_pinned(self):
        text=(ROOT/'export_presets.cfg').read_text().split('[preset.3.options]',1)[1]
        self.assertIn('custom_template/release="res://builds/export-data/godot/export_templates/4.6.3.stable/web_nothreads_release.zip"',text)
        self.assertIn('variant/thread_support=false',text)
        self.assertIn('progressive_web_app/enabled=false',text)

    def test_windows_data_paths_are_process_local(self):
        before=dict(os.environ)
        with tempfile.TemporaryDirectory() as directory, patch.object(export_web,'ROOT',Path(directory)):
            build=Path(directory)/'build'
            env=export_web.isolated_environment(build,'nt')
            for key in ('APPDATA','LOCALAPPDATA','XDG_CONFIG_HOME','XDG_CACHE_HOME'):
                self.assertTrue(Path(env[key]).is_relative_to(build))
                self.assertTrue(Path(env[key]).is_dir())
            self.assertEqual(dict(os.environ),before)

    def test_posix_data_paths_are_process_local(self):
        with tempfile.TemporaryDirectory() as directory, patch.object(export_web,'ROOT',Path(directory)):
            build=Path(directory)/'build'
            env=export_web.isolated_environment(build,'posix')
            self.assertEqual(env.get('APPDATA'),os.environ.get('APPDATA'))
            self.assertEqual(Path(env['XDG_DATA_HOME']),Path(directory)/'builds/export-data')

    def test_windows_abort_uses_only_child_handle(self):
        child=Mock();child.poll.return_value=None
        with patch.object(export_web.os,'killpg',create=True) as group:
            export_web.stop_export(child,'nt')
        group.assert_not_called();child.kill.assert_called_once_with();child.wait.assert_called_once_with(timeout=10)

    def test_finished_child_is_not_signalled(self):
        child=Mock();child.poll.return_value=0
        export_web.stop_export(child,'nt')
        child.kill.assert_not_called();child.wait.assert_not_called()

    @unittest.skipUnless(os.name=='posix','Actual process-group check requires POSIX')
    def test_real_bounded_child_stops(self):
        child=subprocess.Popen([sys.executable,'-c','import time; time.sleep(30)'],start_new_session=True)
        try:
            export_web.stop_export(child)
            self.assertEqual(child.returncode,-signal.SIGKILL)
        finally:
            if child.poll() is None: child.kill();child.wait()

    def test_explicit_engine_path_is_documented_cli(self):
        result=subprocess.run([sys.executable,str(ROOT/'tools/export_web.py'),'--help'],capture_output=True,text=True)
        self.assertEqual(result.returncode,0)
        self.assertIn('--godot',result.stdout)

if __name__=='__main__': unittest.main()
