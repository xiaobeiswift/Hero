import ast,copy,json,unittest
from pathlib import Path
HERE=Path(__file__).resolve().parent
FIXTURE=json.loads((HERE/'actual_receipt_schema.json').read_text())['receipt']
def guard(path,receipt):
    tree=ast.parse(path.read_text())
    nodes=[n for n in ast.walk(tree) if isinstance(n,ast.Call) and isinstance(n.func,ast.Name) and n.func.id=='need' and len(n.args)==2 and isinstance(n.args[1],ast.Constant) and n.args[1].value=='Import receipt does not establish the unchanged, cleanly imported runtime']
    assert len(nodes)==1
    expression=ast.Expression(nodes[0].args[0]);ast.fix_missing_locations(expression)
    allowed=(ast.Expression,ast.BoolOp,ast.And,ast.Compare,ast.Is,ast.Eq,ast.Subscript,ast.Name,ast.Constant,ast.List,ast.Load)
    assert all(isinstance(n,allowed) for n in ast.walk(expression))
    assert all(n.id=='receipt' for n in ast.walk(expression) if isinstance(n,ast.Name))
    return eval(compile(expression,'exact_helper_receipt_guard','eval'),{'__builtins__':{}},{'receipt':receipt})
class ActualReceiptSchemaChecks(unittest.TestCase):
    def test_published_guard_reproduces_observed_keyerror(self):
        with self.assertRaisesRegex(KeyError,'error_lines'):guard(HERE/'published-helper.py.txt',FIXTURE)
    def test_actual_nested_schema_passes_corrected_real_guard(self):
        self.assertNotIn('error_lines',FIXTURE)
        self.assertTrue(guard(HERE/'capture_imported_windows.py',FIXTURE))
    def test_nested_errors_cannot_be_shadowed_by_empty_top_level(self):
        r=copy.deepcopy(FIXTURE);r['import']['error_lines']=['ERROR: actual'];r['error_lines']=[]
        self.assertFalse(guard(HERE/'capture_imported_windows.py',r))
    def test_missing_nested_field_stays_fail_closed(self):
        r=copy.deepcopy(FIXTURE);del r['import']['error_lines'];r['error_lines']=[]
        with self.assertRaises(KeyError):guard(HERE/'capture_imported_windows.py',r)
    def test_failed_import_exit_rejected(self):
        r=copy.deepcopy(FIXTURE);r['import']['exit_code']=1
        self.assertFalse(guard(HERE/'capture_imported_windows.py',r))
    def test_original_changes_rejected(self):
        r=copy.deepcopy(FIXTURE);r['original_file_changes']=['scripts/main.gd']
        self.assertFalse(guard(HERE/'capture_imported_windows.py',r))
    def test_failed_status_and_changed_marker_rejected(self):
        for key in ['passed','original_engine_and_marker_unchanged']:
            r=copy.deepcopy(FIXTURE);r[key]=False
            with self.subTest(key=key):self.assertFalse(guard(HERE/'capture_imported_windows.py',r))
if __name__=='__main__':unittest.main(verbosity=2)
