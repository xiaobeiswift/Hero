#!/usr/bin/env python3
"""Audit an exact Web PCK with pinned Godot and fresh, isolated local saves."""
from pathlib import Path, PurePosixPath
import argparse, hashlib, json, os, re, subprocess, sys, zipfile

ROOT=Path(__file__).resolve().parents[1]
ENGINE='4.6.3.stable.official.7d41c59c4'
LEGACY='e20c24c3cf7ac0cfc83f4a3ab453cad6f9e8c61e116f13d12b22576bd4d1b0a5'
SCHEMA11='fbd0cef61329356ba3f7fd17bf2fa861ddd149d4d565916711685e0c4c5aac30'
SCHEMA9='fd5d6da903a8d24a16ecd5774642c2e5e2bc792a084807734ba6caa95f972f4f'
SCHEMA12='7872904b27c52b2fe038b6f355a371ca8e9f90d1054c3be24a5dd912bea8a02a'
EXPECTED_CHECKS=2799  # Complete current source checks plus5 exact-PCK-only assertions.
EXPECTED_UNIFIED_CHECKS=1237
EXPECTED_PRESERVED_CHECKS=1471
COMPLETE_SCOPE='Audit scope: complete; prepared state/input only; no browser or physical desktop-close claim'
PRESERVED_COVERAGE='Preserved noncombat exact-runtime coverage:'
UNIFIED_COVERAGE='Schema13 unified automatic exact-runtime coverage:'
OLD_COVERAGE=('Schema12 four-actor exact-runtime coverage:', 'Schema12 sluice exact-runtime coverage:', 'Schema12 archive exact-runtime coverage:')

def sha(path):
    with Path(path).open('rb') as handle: return hashlib.file_digest(handle,'sha256').hexdigest()

def relative(name):
    path=PurePosixPath(name)
    if not name or '\\' in name or ':' in name or path.is_absolute() or any(p in ('..','.') for p in name.split('/')):
        raise ValueError('Unsafe manifest member')
    return path

def verify_site(build, report):
    files=report['site_files'];site=build/'site'
    actual={p.relative_to(site).as_posix() for p in site.rglob('*') if p.is_file()}
    if actual!=set(files): raise RuntimeError('Generated site membership changed')
    archive_name=relative(report['archive']['file'])
    if len(archive_name.parts)!=1: raise RuntimeError('Archive must be directly in build directory')
    archive=build/str(archive_name)
    if sha(archive)!=report['archive']['sha256']: raise RuntimeError('Archive changed')
    with zipfile.ZipFile(archive) as bundle:
        expected={'Hero-Web/'+name for name in files}
        if len(bundle.namelist())!=len(expected) or set(bundle.namelist())!=expected:
            raise RuntimeError('Archive membership changed')
        for name,meta in files.items():
            path=site/str(relative(name))
            if path.is_symlink() or path.stat().st_size!=meta['bytes'] or sha(path)!=meta['sha256']:
                raise RuntimeError('Generated site bytes changed: '+name)
            if hashlib.sha256(bundle.read('Hero-Web/'+name)).hexdigest()!=meta['sha256']:
                raise RuntimeError('Archive bytes changed: '+name)

def audit_environment(directory, platform=None):
    env=os.environ.copy();platform=os.name if platform is None else platform
    data=directory/'web-smoke-data';config=directory/'config';cache=directory/'cache'
    for path in (data,config,cache):path.mkdir(parents=True,exist_ok=False)
    env.update(XDG_DATA_HOME=data.as_posix(),XDG_CONFIG_HOME=config.as_posix(),XDG_CACHE_HOME=cache.as_posix())
    if platform=='nt':env.update(APPDATA=str(data),LOCALAPPDATA=str(cache))
    return env

def verify_source_manifest(build, report, root=None):
    root=ROOT if root is None else Path(root)
    manifest=build/'SOURCE-SHA256SUMS.txt'
    entries={}
    for line in manifest.read_text(encoding='utf-8').splitlines():
        match=re.fullmatch(r'([0-9a-f]{64})  (.+)',line)
        if match is None: raise RuntimeError('Malformed source manifest')
        digest,name=match.groups();relative(name)
        if name in entries: raise RuntimeError('Duplicate source manifest member')
        entries[name]=digest
    paths=[root/name for name in ('project.godot','export_presets.cfg')]
    for name in ('assets','scripts','scenes','licenses','web'):
        paths.extend(path for path in (root/name).rglob('*') if path.is_file())
    actual={path.relative_to(root).as_posix():sha(path) for path in paths}
    if not entries or entries!=actual or len(entries)!=report['source_entries'] or not report['source_unchanged']:
        raise RuntimeError('Export source manifest does not match frozen audit source')
    return sha(manifest)


def completed_pack_checks(text, exit_code):
    """Fail closed on pre-automatic, partial, rehearsal, duplicate or error logs."""
    if exit_code != 0 or min(EXPECTED_CHECKS,EXPECTED_UNIFIED_CHECKS,EXPECTED_PRESERVED_CHECKS)<=0:
        return None
    lines=text.splitlines()
    if [line for line in lines if line.startswith('Audit scope:')] != [COMPLETE_SCOPE]: return None
    if 'SOURCE REHEARSAL:' in text or any(marker in text for marker in OLD_COVERAGE): return None
    if any(line.startswith(('ERROR:', 'SCRIPT ERROR:')) for line in lines): return None
    for marker,expected in ((PRESERVED_COVERAGE,EXPECTED_PRESERVED_CHECKS),(UNIFIED_COVERAGE,EXPECTED_UNIFIED_CHECKS)):
        coverage=[line for line in lines if line.startswith(marker)]
        if len(coverage)!=1 or re.fullmatch(re.escape(marker)+r' '+str(expected)+r' checks;[^\n]+',coverage[0]) is None: return None
    summaries=re.findall(r'^(PASS|FAIL): (\d+) (exported-pack|source-rehearsal) checks; (\d+) failures$',text,re.MULTILINE)
    if summaries != [('PASS',str(EXPECTED_CHECKS),'exported-pack','0')]: return None
    return EXPECTED_CHECKS


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build',type=Path);parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
    args=parser.parse_args();build=args.build.resolve()
    report=json.loads((build/'BUILD-REPORT.json').read_text(encoding='utf-8'))
    verify_site(build,report)
    source_manifest_sha256=verify_source_manifest(build,report)
    legacy=ROOT/'tests/fixtures/v019_game_state.gd.txt'
    if sha(legacy)!=LEGACY:raise RuntimeError('Historical schema10 reader changed')
    schema11=ROOT/'tests/fixtures/v020_game_state.gd.txt'
    if sha(schema11)!=SCHEMA11:raise RuntimeError('Historical schema11 reader changed')
    schema9=ROOT/'tests/fixtures/v017_game_state.gd.txt'
    if sha(schema9)!=SCHEMA9:raise RuntimeError('Historical schema9 reader changed')
    schema12=ROOT/'tests/fixtures/v022_game_state.gd.txt'
    if sha(schema12)!=SCHEMA12:raise RuntimeError('Historical schema12 reader changed')
    directory=build/'exact-pack-audit'
    directory.mkdir()  # Refuse to overwrite previous audit evidence or test profiles.
    env=audit_environment(directory)
    version=subprocess.check_output([args.godot,'--headless','--version'],env=env,text=True).strip()
    if version!=ENGINE:raise RuntimeError('Unexpected Godot engine')
    log=directory/'PCK-AUDIT.log';driver=ROOT/'tools/smoke_export.gd'
    command=[sys.executable,str(ROOT/'tools/run_godot_check.py'),args.godot,'--headless','--audio-driver','Dummy',
             '--path',str(build/'site'),'--main-pack',str(build/'site/index.pck'),'--script',str(driver),
             '--','--legacy-reader='+legacy.as_posix(),'--schema11-reader='+schema11.as_posix(),'--schema12-reader='+schema12.as_posix(),'--schema9-reader='+schema9.as_posix()]
    with log.open('wb') as output:
        result=subprocess.run(command,env=env,cwd=build/'site',stdout=output,stderr=subprocess.STDOUT)
    text=log.read_text(encoding='utf-8',errors='replace')
    checks=completed_pack_checks(text,result.returncode)
    passed=checks is not None
    verify_site(build,report)
    if verify_source_manifest(build,report)!=source_manifest_sha256:raise RuntimeError('Source manifest changed during audit')
    evidence={'source_commit':report['source_commit'],'engine':version,'pck_sha256':sha(build/'site/index.pck'),
              'audit_sha256':sha(driver),'legacy_sha256':LEGACY,'schema11_reader_sha256':SCHEMA11,'schema9_reader_sha256':SCHEMA9,'schema12_reader_sha256':SCHEMA12,'source_manifest_sha256':source_manifest_sha256,'save_schema':13,'party_capacity':4,'log_sha256':sha(log),'exit_code':result.returncode,
              'passed':passed,'checks':checks,'preserved_checks':EXPECTED_PRESERVED_CHECKS if passed else None,'unified_checks':EXPECTED_UNIFIED_CHECKS if passed else None,'scope':'Exact Web PCK under native editor; not browser graphics/audio/persistence or physical window-close'}
    (directory/'PCK-AUDIT.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(evidence));return 0 if passed else 1

if __name__=='__main__':sys.exit(main())
