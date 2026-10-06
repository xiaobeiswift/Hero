#!/usr/bin/env python3
"""Linux companion folio QA: an empty owned profile, then one bounded Godot action."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import re
import secrets
import shutil
import signal
import stat
import subprocess
import sys
import time

ENGINE = Path('/opt/godot/4.6.3/Godot_v4.6.3-stable_linux.x86_64')
ENGINE_SHA = 'f64d4ed19fc9df9440321653fcc80df8c6e365ba7b6de0a29e2cfa9fa71bfeb3'
# Parent binds these only after freezing the candidate runtime. Never use historical evidence.
RUNTIME_SHA = 'f490c4456a7cbf0719425da6039301149f7c90e937373201e1b7e3315590984c'
RUNTIME_INPUTS = Path(__file__).absolute().with_name('runtime-inputs.json')
RUNTIME_INPUTS_SHA = '85e3bf7a13ea60e91052831f5533fe2af463a0fd45a706545e35c8658b3de465'
NATIVE_HELPER = 'tests/companion_folio_behavior_test.gd'
USER_SUFFIX = 'data/godot/app_userdata/Hero · 渡灯录'


def require(ok, message):
    if not ok:
        raise ValueError(message)


def absolute_unlinked(value):
    path = Path(value)
    require(path.is_absolute() and '..' not in path.parts, f'Not an absolute clean path: {path}')
    require(all(not p.is_symlink() for p in (path, *path.parents)), f'Symlink path: {path}')
    return path


def sha(path):
    absolute_unlinked(path)
    require(stat.S_ISREG(path.stat().st_mode), f'Not a regular file: {path}')
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def snapshot(source, names):
    require(all(not Path(n).is_absolute() and '..' not in Path(n).parts for n in names), 'Unsafe source path')
    return {n: sha(source / n) for n in sorted(names)}


def runtime_digest(source, names):
    mapping = snapshot(source, names)
    return hashlib.sha256(json.dumps(mapping, sort_keys=True, separators=(',', ':')).encode()).hexdigest()


def new_profile(root):
    absolute_unlinked(root).mkdir(mode=0o700)  # Exclusive: never reuse an existing profile.
    require(root.stat().st_uid == os.getuid() and stat.S_IMODE(root.stat().st_mode) == 0o700, 'QA root is not private and caller-owned')
    env = os.environ.copy()
    for key, leaf in [('HOME', 'home'), ('XDG_DATA_HOME', 'data'), ('XDG_CONFIG_HOME', 'config'), ('XDG_CACHE_HOME', 'cache')]:
        (root / leaf).mkdir(mode=0o700)
        env[key] = str(root / leaf)
    for leaf in ('logs', 'results'):
        (root / leaf).mkdir(mode=0o700)
    (root / USER_SUFFIX).mkdir(mode=0o700, parents=True)
    env.update(PYTHONDONTWRITEBYTECODE='1', HERO_FOLIO_QA_OWNED_ROOT=str(root), HERO_FOLIO_QA_USER_DIR=str(root / USER_SUFFIX), HERO_FOLIO_QA_TOKEN=secrets.token_hex(32), HERO_FOLIO_QA_REPORT=str(root / 'results/test-result.json'))
    with (root / '.hero-folio-qa-owner').open('x') as stream:
        os.fchmod(stream.fileno(), 0o600)
        stream.write(env['HERO_FOLIO_QA_TOKEN'])
    return env


def run_owned(command, env, log, seconds, cwd):
    require(math.isfinite(seconds) and seconds > 0, 'Timeout must be finite and positive')
    with log.open('xb') as output:
        child = subprocess.Popen(command, env=env, cwd=cwd, stdout=output, stderr=subprocess.STDOUT, start_new_session=True)
        deadline = time.monotonic() + seconds
        try:
            while True:
                if min(shutil.disk_usage(p).free for p in (cwd, log.parent)) < 2 * 1024**3:
                    output.write(b'ERROR: QA storage fell below 2 GiB; stopping owned child\n')
                    code = 125
                    break
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    code = 124
                    break
                try:
                    code = child.wait(timeout=min(0.25, remaining))
                    break
                except subprocess.TimeoutExpired:
                    pass
        finally:
            # This group was created by this Popen; never search or kill other engines.
            if child.poll() is None:
                try:
                    os.killpg(child.pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            child.wait(timeout=5)
    return code


def check_profile(root, env):
    for path, mode in ((root, 0o700), (root / '.hero-folio-qa-owner', 0o600)):
        absolute_unlinked(path)
        require(path.stat().st_uid == os.getuid() and stat.S_IMODE(path.stat().st_mode) == mode, 'QA ownership or permissions changed')
    require((root / '.hero-folio-qa-owner').read_text() == env['HERO_FOLIO_QA_TOKEN'], 'QA token changed')
    userdata = absolute_unlinked(root / USER_SUFFIX)
    require(not any(userdata.iterdir()), 'User data is no longer empty before game code')


def generated(source, tracked):
    absolute_unlinked(source / '.godot')
    for path in (source / '.godot').rglob('*'):
        require(not path.is_symlink(), f'Linked generated path: {path}')
    return {kind: snapshot(source, [str(p.relative_to(source)) for p in paths if p.is_file() and str(p.relative_to(source)) not in tracked])
            for kind, paths in [('godot_cache', (source / '.godot').rglob('*')), ('untracked_uids', source.rglob('*.uid'))]}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('mode', choices=('import', 'test', 'native'))
    parser.add_argument('--source', required=True)
    parser.add_argument('--qa-root', required=True, help='Absolute, nonexistent directory; its parent must exist')
    parser.add_argument('--timeout', type=float, default=120)
    parser.add_argument('--guard-timeout', type=float, default=30)
    parser.add_argument('--script', help='Tracked relative .gd for test; absolute external .gd for native')
    parser.add_argument('--test-arg', action='append', default=[], help='Script argument; {results} expands to this QA results directory')
    args = parser.parse_args(argv)
    source, root = absolute_unlinked(args.source), absolute_unlinked(args.qa_root)
    require(all(isinstance(value, str) and re.fullmatch(r'[0-9a-f]{64}', value) for value in (RUNTIME_SHA, RUNTIME_INPUTS_SHA)), 'UNBOUND candidate runtime: parent must bind runtime-inputs.json and both digests before execution')
    require(sys.platform == 'linux', 'Linux only')
    require(source.is_dir() and root != source and source not in root.parents, 'QA root must be outside the source checkout')
    require(all(math.isfinite(n) and n > 0 for n in (args.timeout, args.guard_timeout)), 'Timeout must be finite and positive')
    require((args.mode in ('test', 'native')) == bool(args.script) and (args.mode == 'test' or not args.test_arg), 'Test/native modes require a script; test arguments remain test-only')
    if args.mode == 'native':
        require(bool(os.environ.get('DISPLAY')), 'Native mode needs an already available authorized cloud X11 display; no display is created or reconfigured')
    require(min(shutil.disk_usage(p).free for p in (source, root.parent)) >= 4 * 1024**3, 'Need 4 GiB free on source and QA filesystems')
    env = new_profile(root)
    report = {'success': False, 'source': str(source), 'qa_root': str(root), 'mode': args.mode, 'phases': []}
    before = None
    tracked = []
    runtime = []
    markers = {}
    native_script = None
    def save(name, data):
        (root / 'results' / name).write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    try:
        launcher_path = Path(__file__).absolute()
        report['tool_sha256'] = {name: sha(path) for name, path in [('launcher', launcher_path), ('guard', launcher_path.with_name('profile_guard.gd'))]}
        commit, tree = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD', 'HEAD^{tree}'], timeout=20).decode().splitlines()
        report.update(source_commit=commit, source_tree=tree)
        require(sha(ENGINE) == ENGINE_SHA, 'Engine SHA256 mismatch')
        markers = {n: sha(ENGINE.parent / n) if (ENGINE.parent / n).exists() else None for n in ('_sc_', '._sc_')}
        require(not any(markers.values()), 'Self-contained marker present; preserved unchanged, refusing isolated editor work')
        tracked = subprocess.check_output(['git', '-C', str(source), 'ls-files', '-z'], timeout=20).decode().rstrip('\0').split('\0')
        if args.mode == 'native':
            candidate = absolute_unlinked(args.script)
            require(candidate.is_file() and candidate.suffix == '.gd' and source not in candidate.parents, 'Native driver must be an unlinked external .gd file')
            report['tool_sha256']['native_driver_original'] = sha(candidate)
            native_script = root / 'native-driver.gd'
            with native_script.open('xb') as stream:
                stream.write(candidate.read_bytes())
            require(sha(native_script) == report['tool_sha256']['native_driver_original'], 'Native driver copy hash mismatch')
            report['native_driver_source'] = str(candidate)
        else:
            require(args.script is None or (args.script in tracked and args.script.endswith('.gd')), 'Test script must be a tracked relative .gd file')
        runtime_manifest = absolute_unlinked(RUNTIME_INPUTS)
        require(source not in runtime_manifest.parents, 'Runtime manifest must be external to source')
        require(sha(runtime_manifest) == RUNTIME_INPUTS_SHA, 'Runtime manifest SHA256 mismatch')
        runtime = json.loads(runtime_manifest.read_text())['runtime_sha256']
        require(isinstance(runtime, dict) and len(runtime) == 384 and set(runtime) <= set(tracked), 'Runtime manifest must contain exactly 384 tracked paths')
        require(snapshot(source, runtime) == runtime and runtime_digest(source, runtime) == RUNTIME_SHA, '384-file runtime binding mismatch')
        report.update(runtime_inputs=str(runtime_manifest), runtime_inputs_sha256=RUNTIME_INPUTS_SHA)
        before = snapshot(source, tracked)
        report.update(engine_sha256_before=ENGINE_SHA, runtime_sha256_before=RUNTIME_SHA, runtime_entries=len(runtime), tracked_originals=len(before), markers_before=markers)
        save('tracked-before.json', before)
        save('generated-before.json', generated(source, tracked))
        guard = root / 'profile_guard.gd'
        guard.write_bytes(Path(__file__).with_name('profile_guard.gd').read_bytes())
        phases = [('guard', ['--script', str(guard)], args.guard_timeout)]
        if args.mode == 'import':
            phases += [('import', ['--editor', '--import', '--quit'], args.timeout)]
        elif args.mode == 'test':
            phases += [('test', ['--script', args.script, '--', *[a.replace('{results}', str(root / 'results')) for a in args.test_arg]], args.timeout)]
        else:
            require(NATIVE_HELPER in tracked, 'Native helper must be a tracked source file')
            binding = {'suite': 'companion_folio_native_capture', 'helper_sha256': sha(source / NATIVE_HELPER),
                       'source': str(source), 'source_commit': commit, 'source_tree': tree,
                       'engine_sha256': ENGINE_SHA, 'runtime_sha256': RUNTIME_SHA,
                       'runtime_entries': len(runtime), 'driver_sha256': sha(native_script),
                       'tool_sha256': report['tool_sha256'], 'scope': 'new native scripted capture of prepared legal fixtures'}
            save('native-binding.json', binding)
            env['HERO_FOLIO_QA_NATIVE_BINDING'] = str(root / 'results/native-binding.json')
            env['HERO_FOLIO_QA_NATIVE_BINDING_SHA256'] = sha(root / 'results/native-binding.json')
            phases += [('native', ['--display-driver', 'x11', '--rendering-method', 'gl_compatibility',
                                  '--audio-driver', 'Dummy', '--resolution', '1280x800', '--fixed-fps', '30',
                                  '--script', str(native_script)], args.timeout)]
        for name, tail, timeout in phases:
            check_profile(root, env)
            engine_log, console_log = root / 'logs' / (name + '.engine.log'), root / 'logs' / (name + '.console.log')
            command = [str(ENGINE), *([] if name == 'native' else ['--headless']), '--path', str(source), '--log-file', str(engine_log), *tail]
            code = run_owned(command, env, console_log, timeout, source)
            output = '\n'.join(p.read_text(errors='replace') for p in (console_log, engine_log) if p.exists())
            lines = re.sub(r'\x1b\[[0-?]*[ -/]*[@-~]', '', output).splitlines()
            errors = [line for line in lines if re.search(r'\b(?:SCRIPT\s*ERROR|ERROR)\b', line)]
            report['phases'].append({'phase': name, 'command': command, 'exit_code': code, 'error_lines': errors})
            require(code == 0 and not errors, f'{name} failed; evidence preserved')
            if name == 'guard':
                require('HERO_PROFILE_GUARD_OK' in lines, 'Guard success marker missing')
            if name == 'native':
                require(any(line.startswith('PASS: NEW companion folio native capture, 10 PNGs / ') for line in lines), 'Native success marker missing')
                result_path = absolute_unlinked(root / 'results/test-result.json')
                result = json.loads(result_path.read_text())
                require(result.get('status') == 'pass' and result.get('historical_evidence_recreated') is False and not result.get('failures'), 'Native report did not pass')
                require(result.get('binding') == binding, 'Native report binding mismatch')
                captures = result.get('captures', [])
                require(len(captures) == 10, 'Native frame count mismatch')
                expected_paths = set()
                seen_sizes = {(1280, 800): 0, (960, 600): 0}
                for capture in captures:
                    target = absolute_unlinked(capture['path'])
                    require(target.parent == root / 'results/native-frames' and target.suffix == '.png', 'PNG outside owned native frame directory')
                    require(target not in expected_paths, 'Duplicate native PNG path')
                    expected_paths.add(target)
                    require(sha(target) == capture['sha256'] and target.stat().st_size == capture['bytes'], 'PNG bytes/hash mismatch')
                    header = target.read_bytes()[:24]
                    require(header[:8] == b'\x89PNG\r\n\x1a\n' and header[12:16] == b'IHDR', 'Invalid PNG header')
                    dimensions = [int.from_bytes(header[16:20], 'big'), int.from_bytes(header[20:24], 'big')]
                    require(dimensions == capture['pixel_dimensions'] == capture['requested_window'] == capture['actual_window'], 'PNG physical size mismatch')
                    require(dimensions in ([1280, 800], [960, 600]), 'Unexpected native dimensions')
                    seen_sizes[tuple(dimensions)] += 1
                    require(capture.get('display_server') != 'headless', 'Headless native claim')
                require(seen_sizes == {(1280, 800): 5, (960, 600): 5}, 'Exactly five frames at each physical size required')
                require(set((root / 'results/native-frames').iterdir()) == expected_paths, 'Unexpected native frame output')
                report['native_capture_count'] = len(captures)
                report['native_result_sha256'] = sha(result_path)
        report['success'] = True
    except (Exception, KeyboardInterrupt) as error:
        report['failure'] = str(error) or type(error).__name__
    finally:
        try:
            report['engine_sha256_after'] = sha(ENGINE)
            require(report['engine_sha256_after'] == ENGINE_SHA, 'Engine changed')
            require(markers == {n: sha(ENGINE.parent / n) if (ENGINE.parent / n).exists() else None for n in ('_sc_', '._sc_')}, 'Self-contained markers changed')
            if before is not None:
                after = snapshot(source, tracked)
                save('tracked-after.json', after)
                report['changed_originals'] = [n for n in before if before[n] != after[n]]
                report['runtime_sha256_after'] = runtime_digest(source, runtime)
                save('generated-after.json', generated(source, tracked))
                require(not report['changed_originals'] and report['runtime_sha256_after'] == RUNTIME_SHA, 'Original tracked bytes or runtime binding changed')
            require(sha(RUNTIME_INPUTS) == RUNTIME_INPUTS_SHA, 'Runtime manifest changed during run')
        except Exception as error:
            report['success'] = False
            report['integrity_failure'] = str(error)
        if args.mode == 'native' and native_script is not None:
            try:
                require(sha(native_script) == report['tool_sha256']['native_driver_original'] == sha(candidate), 'Native driver changed during run')
                if env.get('HERO_FOLIO_QA_NATIVE_BINDING_SHA256'):
                    require(sha(root / 'results/native-binding.json') == env['HERO_FOLIO_QA_NATIVE_BINDING_SHA256'], 'Native binding changed during run')
            except Exception as error:
                report['success'] = False
                report['native_integrity_failure'] = str(error)
        save('launcher-result.json', report)
    print(root / 'results' / 'launcher-result.json')
    return 0 if report['success'] else 1


if __name__ == '__main__':
    def cancel(_signal, _frame):
        raise KeyboardInterrupt()
    signal.signal(signal.SIGTERM, cancel)
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        sys.exit(str(error))
