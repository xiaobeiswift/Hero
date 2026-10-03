#!/usr/bin/env python3
"""Capture only from an already imported, receipt-bound Hero runtime on Windows.
No editor/import stage, install, network, setting or self-contained-marker change.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time
import uuid

HERE = Path(__file__).resolve().parent
PUBLIC_COMMIT = '87c4c3f3f9a5c39c39118e0202177b46f35ebae1'
LOCAL_REFERENCE = 'e6bd39027c9a4d86d82bc385024e3a7b28d945e8'
TREE = '84d995012e92e20bac1db1abe28e78eef5c67904'
MANIFEST_SHA = 'b02494ed1bd254e6ad022421659eac67638ece8518fb2bcb29178233dd045a66'
PROJECT_NAME = 'Hero · 渡灯录'
EXPECTED_ENGINE = {'major':4, 'minor':6, 'patch':3, 'status':'stable', 'build':'official', 'hash':'7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3'}
ERROR_LINE = re.compile(r'(?m)^\s*(?:SCRIPT ERROR:|ERROR:|Parse Error:|Error:)')

def need(ok, message):
    if not ok:
        raise RuntimeError(message)

def sha(path):
    with Path(path).open('rb') as file:
        return hashlib.file_digest(file, 'sha256').hexdigest()

def dump(path, value):
    Path(path).write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')

def absolute(value):
    path = Path(value)
    need(path.is_absolute() and '..' not in path.parts, f'Absolute non-traversing path required: {value}')
    return path.absolute()

def reparse_free(path):
    for item in (path, *path.parents):
        try:
            info = item.lstat()
        except FileNotFoundError:
            continue
        need(not stat.S_ISLNK(info.st_mode) and not (getattr(info, 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT), f'Reparse point refused: {item}')

def inventory(source):
    result = {}
    for base, dirs, files in os.walk(source, followlinks=False):
        for name in dirs + files:
            reparse_free(Path(base) / name)
        dirs[:] = [name for name in sorted(dirs) if name not in ('.git', '.godot')]
        for name in sorted(files):
            path = Path(base) / name
            if path.name != '.git':
                result[path.relative_to(source).as_posix()] = sha(path)
    return result

def validate_generated(original, generated):
    need(isinstance(generated, dict), 'Generated inventory must be a relative-path object')
    sidecars = {}; cache = {}
    for path, entry in generated.items():
        need(isinstance(path, str) and "\\" not in path and not path.startswith('/') and ':' not in path and not any(v in ('', '.', '..') for v in path.split('/')), 'Unsafe generated path')
        need(path not in original and isinstance(entry, dict), 'Generated receipt cannot replace an original source path')
        need(isinstance(entry.get('bytes'), int) and entry['bytes'] >= 0 and re.fullmatch(r'[0-9a-f]{64}', entry.get('sha256','')), f'Invalid generated identity: {path}')
        if path.startswith('.godot/'):
            cache[path] = entry['sha256']
        else:
            need((path.endswith('.uid') and path[:-4].endswith('.gd') and path[:-4] in original)
                 or (path.endswith('.import') and path[:-7] in original), f'Not paired importer metadata: {path}')
            sidecars[path] = entry['sha256']
    return original | sidecars, cache

def validate_engine(profile, wrapper_path=None, wrapper_sha=None):
    binary = absolute(profile['engine']); reparse_free(binary)
    need(binary.is_file() and sha(binary) == profile['engine_sha256'], 'Existing engine bytes differ from reviewed profile receipt')
    if wrapper_path is None:
        need(wrapper_sha is None, 'Wrapper hash without wrapper path')
        return binary, binary, 'direct_gui'
    launch = absolute(wrapper_path); reparse_free(launch)
    suffix = next((v for v in ('.console.exe', '_console.exe') if launch.name.lower().endswith(v)), None)
    need(suffix is not None and binary == launch.with_name(launch.name[:-len(suffix)] + '.exe'), 'Optional wrapper does not map to the receipt-bound sibling engine')
    need(launch.is_file() and wrapper_sha is not None and sha(launch) == wrapper_sha, 'Optional wrapper bytes differ from explicit pin')
    return launch, binary, 'console_wrapper'

def inspect_empty_user(path):
    reparse_free(path)
    if not os.path.lexists(path):
        return {'directory_exists':False, 'application_files':{}, 'engine_shader_cache':{}}
    need(path.is_dir(), 'User data path is not a directory')
    for child in path.iterdir():
        reparse_free(child)
        need(child.name == 'shader_cache' and child.is_dir(), f'Existing application data or unexpected user entry: {child.name}')
    cache = {}
    cache_root = path/'shader_cache'
    if cache_root.is_dir():
        for base, dirs, files in os.walk(cache_root, followlinks=False):
            for name in dirs + files: reparse_free(Path(base)/name)
            for name in files:
                item = Path(base)/name; cache[item.relative_to(path).as_posix()] = sha(item)
    return {'directory_exists':True, 'application_files':{}, 'engine_shader_cache':cache}

def validate_profile(receipt):
    base = absolute(receipt['profile']); reparse_free(base)
    need(base.is_dir(), 'Reviewed profile root does not exist')
    all_values = receipt['process_local_environment']
    required = {'APPDATA','LOCALAPPDATA','HOME','USERPROFILE','XDG_DATA_HOME','XDG_CONFIG_HOME','XDG_CACHE_HOME','TEMP','TMP'}
    need(required <= set(all_values) and set(all_values) <= required | {'HERO_OWNED_DATA_ROOT','HERO_CHECK_TIMEOUT_SECONDS'}, 'Profile receipt has missing or unexpected environment fields')
    values = {key:all_values[key] for key in required}
    for key, value in values.items():
        path = absolute(value); reparse_free(path)
        need(path.is_dir() and path.is_relative_to(base), f'{key} escapes or is missing from owned profile')
    isolation = receipt['isolation']; user = absolute(isolation['actual_user_root'])
    need(user == Path(values['APPDATA'])/'Godot'/'app_userdata'/PROJECT_NAME, 'Observed Windows user-data path differs from APPDATA layout')
    need(receipt['guard_exit_code'] == 0 and receipt['main_loaded'] is False and receipt['capture_run'] is False and isolation['main_loaded'] is False and isolation['passed'] is True, 'Receipt is not a successful pre-Main/pre-capture isolation guard')
    need(isolation['user_files'] == [] and isolation['user_folders'] == [], 'Reviewed profile was not empty at the guard')
    need(absolute(isolation['expected_owned_data']) == Path(values['APPDATA']) and absolute(isolation['data_dir']) == Path(values['APPDATA']) and absolute(isolation['config_dir']) == Path(values['APPDATA']) and absolute(isolation['cache_dir']) == Path(values['LOCALAPPDATA']), 'Observed Godot data/config/cache isolation differs from bound environment')
    for key in ('APPDATA','LOCALAPPDATA'):
        if os.environ.get(key):
            protected = Path(os.environ[key]).resolve(strict=False)/'Godot'
            need(not base.is_relative_to(protected) and not protected.is_relative_to(base), 'Owned scope overlaps real Godot data/config/cache')
    need(not os.path.lexists(base/'.hero-first-capture-started'), 'Capture profile was already claimed by a prior attempt')
    observation = inspect_empty_user(user)
    env = os.environ.copy(); env.update(all_values)
    env['HOMEDRIVE'] = base.drive; env['HOMEPATH'] = str(Path(values['HOME']))[len(base.drive):]
    return env, values, user, base, observation

def run_engine(command, source, out, env, timeout):
    dump(out/'capture.command.json', {'argv':command, 'timeout_seconds':timeout, 'direct_gui_process_tree_guarantee':False})
    start = time.monotonic()
    with (out/'capture.stdout.log').open('wb') as stdout, (out/'capture.stderr.log').open('wb') as stderr:
        process = subprocess.Popen(command, cwd=source, env=env, stdout=stdout, stderr=stderr)
        try:
            code = process.wait(timeout=timeout)
        except subprocess.TimeoutExpired:
            process.kill()  # Only our launched process; never a name-based/global kill.
            try:
                code = process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                code = None
            dump(out/'capture.exit.json', {'timed_out':True, 'pid':process.pid, 'returncode':code, 'launched_process_exit_confirmed':code is not None, 'full_process_tree_termination_verified':False})
            raise RuntimeError('Native capture timed out; raw logs retained; no process-tree or visual pass')
    logs = '\n'.join(path.read_text(encoding='utf-8', errors='replace') for path in out.glob('capture.*.log'))
    errors = len(ERROR_LINE.findall(logs))
    dump(out/'capture.exit.json', {'timed_out':False, 'returncode':code, 'seconds':time.monotonic()-start, 'error_line_count':errors, 'full_process_tree_termination_verified':False})
    need(code == 0 and errors == 0, f'Capture failed: exit {code}, {errors} error lines; raw logs retained')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True)
    for name in ('import-receipt','profile-receipt','generated-inventory','original-inventory'):
        parser.add_argument('--'+name, required=True)
        parser.add_argument('--'+name+'-sha256', required=True)
    parser.add_argument('--console-wrapper')
    parser.add_argument('--console-wrapper-sha256')
    parser.add_argument('--run-root', required=True, help='Absent authorized output path, separate from runtime and real Godot data')
    args = parser.parse_args()
    need(os.name == 'nt', 'Windows only; no engine was started')
    source, root = (absolute(p) for p in (args.source,args.run_root))
    for path in (source,root): reparse_free(path)
    records = {}; receipt_paths = {}
    for name in ('import_receipt','profile_receipt','generated_inventory','original_inventory'):
        path = absolute(getattr(args,name)); reparse_free(path)
        need(path.is_file() and sha(path) == getattr(args,name+'_sha256'), f'Caller-pinned {name} bytes differ')
        receipt_paths[name] = path; records[name] = json.loads(path.read_text(encoding='utf-8-sig'))
    receipt = records['import_receipt']; profile_receipt = records['profile_receipt']
    need(absolute(profile_receipt['source']) == source and profile_receipt['source_commit'] == PUBLIC_COMMIT and profile_receipt['source_tree'] == TREE, 'Profile receipt is not for the exact original runtime')
    need(receipt['passed'] is True and receipt['import']['exit_code'] == 0 and receipt['error_lines'] == [] and receipt['original_file_changes'] == [] and receipt['original_engine_and_marker_unchanged'] is True, 'Import receipt does not establish the unchanged, cleanly imported runtime')
    need(sha(HERE/'source-sha256.json') == MANIFEST_SHA, 'Frozen original manifest mismatch')
    env, values, user, profile_root, profile_observation = validate_profile(profile_receipt)
    launch, binary, engine_mode = validate_engine(profile_receipt,args.console_wrapper,args.console_wrapper_sha256)
    git = lambda *a: subprocess.check_output(['git',*a],cwd=source).decode('utf-8').strip()
    need(git('rev-parse','HEAD') == PUBLIC_COMMIT and git('rev-parse','HEAD^{tree}') == TREE, 'Runtime Git HEAD/tree mismatch')
    original = json.loads((HERE/'source-sha256.json').read_text(encoding='utf-8'))
    need(len(original) == 1639 and {p:v['sha256'] for p,v in records['original_inventory'].items()} == original, 'Reviewed original inventory differs from the frozen 1,639 files')
    generated = records['generated_inventory']
    need(receipt['generated_file_count'] == len(generated), 'Generated inventory count differs from import receipt')
    effective, cache_inputs = validate_generated(original, generated)
    for path, entry in (records['original_inventory'] | generated).items():
        actual = source/path; reparse_free(actual)
        need(actual.is_file() and actual.stat().st_size == entry['bytes'] and sha(actual) == entry['sha256'], 'Receipt-bound source/cache bytes differ: '+path)
    need(inventory(source) == effective, 'Original or generated metadata bytes differ from the supplied exact receipt')
    need((source/'.godot').is_dir(), 'Already imported runtime cache is missing; this helper will not import')
    reparse_free(source/'.godot')
    need(not os.path.lexists(root) and root.parent.is_dir(), 'Run root must be absent with an existing authorized parent')
    need(not root.is_relative_to(source) and not source.is_relative_to(root), 'Keep capture profile/output outside source')
    for key in ('APPDATA','LOCALAPPDATA'):
        if os.environ.get(key):
            protected = Path(os.environ[key]).resolve(strict=False)/'Godot'
            need(not root.is_relative_to(protected) and not protected.is_relative_to(root), f'Run root overlaps real {key}/Godot')
    markers = {str(binary.parent/name):sha(binary.parent/name) for name in ('_sc_', '._sc_') if (binary.parent/name).is_file()}
    bindings = {'launcher':Path(__file__), 'probe':HERE/'first_render.gd', 'manifest':HERE/'source-sha256.json', **receipt_paths, 'launch_executable':launch, 'engine_binary':binary}
    expected = {key:sha(path) for key,path in bindings.items()}
    root.mkdir(); out = root/'out'; out.mkdir()
    dump(out/'preflight.json', {'runtime_public_commit':PUBLIC_COMMIT, 'local_reference':LOCAL_REFERENCE, 'tree':TREE, 'original_count':len(original), 'generated_count':len(generated), 'generated_source_sidecar_count':len(effective)-len(original), 'generated_cache_input_count':len(cache_inputs), 'engine_mode':engine_mode, 'self_contained_markers_preserved':markers, 'profile_observation':profile_observation, 'external_binding':expected, 'scope':'Capture only; existing import is revalidated, never repeated'})
    def verify(label):
        current = {key:sha(path) for key,path in bindings.items()}
        dump(out/f'binding-{label}.json', current)
        need(current == expected, 'External identity changed during capture')
        need({str(binary.parent/name):sha(binary.parent/name) for name in ('_sc_', '._sc_') if (binary.parent/name).is_file()} == markers, 'Self-contained marker changed')
        reparse_free(source/'.godot')
        if label == 'before':
            for path, digest in cache_inputs.items():
                need(sha(source/path) == digest, 'Generated import cache changed before launch: '+path)
    try:
        need(not profile_root.is_relative_to(source) and not source.is_relative_to(profile_root), 'Owned profile overlaps runtime source')
        need(not root.is_relative_to(profile_root) and not profile_root.is_relative_to(root), 'Keep fresh output and reviewed capture profile separate')
        inspect_empty_user(user)
        nonce = uuid.uuid4().hex
        with (profile_root/'.hero-first-capture-started').open('x', encoding='utf-8') as claim:
            claim.write(nonce)
        dump(root/'owner.json', {'nonce':nonce, 'output':out.as_posix(), 'capture_environment':values, 'capture_userdata':user.as_posix(), 'capture_profile_root':profile_root.as_posix(), 'capture_fresh_verified_before_launch':True, 'capture_userdata_existed_empty':profile_observation['directory_exists'], 'prelaunch_application_files':{}})
        dump(out/'source-binding.json', {'retrieved_public_commit':PUBLIC_COMMIT, 'retrieved_tree':TREE, 'local_reference_commit':LOCAL_REFERENCE, 'all_original_1639_bytes_unchanged':True, 'generated_metadata':generated, 'generated_cache_before_launch':cache_inputs, 'effective_files':effective, 'external_binding':expected, 'execution_identity':'Original runtime plus supplied, revalidated importer metadata; not a clean commit tree'})
        env['HERO_FOLIO_OWNED'] = root.as_posix(); env['HERO_FOLIO_NONCE'] = nonce
        inspect_empty_user(user)
        command = [str(launch),'--path',str(source),'--audio-driver','Dummy','--log-file',str(out/'capture.godot.log'),'--rendering-method','gl_compatibility','--resolution','1280x800','--max-fps','30','--quit-after','300','--script',str(HERE/'first_render.gd')]
        verify('before')
        try:
            run_engine(command,source,out,env,180)
        finally:
            verify('after')
        report = json.loads((out/'capture.json').read_text(encoding='utf-8'))
        need(report['status'] == 'captured_pending_visual_review' and report['display_server'] != 'headless', 'No actual native capture report')
        need(all(report['engine'].get(k) == v for k,v in EXPECTED_ENGINE.items()), 'Unexpected running engine build')
        need(inventory(source) == effective, 'Runtime original/generated source metadata changed during capture')
        cache_after = {}
        for base, dirs, files in os.walk(source/'.godot', followlinks=False):
            for name in dirs + files: reparse_free(Path(base)/name)
            for name in files:
                path = Path(base)/name; cache_after[path.relative_to(source).as_posix()] = sha(path)
        dump(out/'project-cache-after.json', cache_after)
        need(sha(out/'first-native.png') == report['image_sha256'], 'PNG hash mismatch')
        dump(out/'result.json', {'status':'captured_pending_visual_review','engine_mode':engine_mode,'full_process_tree_gate':False,'full_regression':False,'contrast_complete':False,'import_repeated':False})
        print(f'Native image pending actual-pixel review: {out/"first-native.png"}')
        return 0
    except Exception as error:
        dump(out/'failure.json', {'status':'failed','exception':str(error),'engine_mode':engine_mode,'full_process_tree_gate':False})
        try:
            dump(out/'failure-source-files.json', inventory(source))
        except Exception as inventory_error:
            dump(out/'failure-inventory.json', {'error':str(inventory_error)})
        raise

if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print(f'CAPTURE_ONLY_STOP: {error}', file=sys.stderr)
        sys.exit(2)
