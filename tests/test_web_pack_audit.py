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

if __name__=='__main__':unittest.main()
