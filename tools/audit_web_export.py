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
SCHEMA14='160fe884cd9e80966cf94493020cb2a9454957e54bc7c0def72754bc95e03fd5'
SCHEMA14_SAVE='4ec2f5ecdcd966f5e49a23bff1c0507381cb2bbae563e150c1b5af9ecf98eec2'
SCHEMA14_PROVENANCE='91c576ec2e3b85eb71936834427db60796d346a99bd6753689bbd4867429ffb1'
SCHEMA15='6a23204d1558b9f2e15ef4150f2c818fb200415fddad00fc35e1e3d99761a159'
SCHEMA15_SAVE='decba7dffc7af4906c3e3166e1b32ac9765329434869a3dcd0bf86f3653e17d6'
FITTING_PROVENANCE='14912385256444e441350c79e2fd2435af7898ef604cafa0216ed40a3960b292'
FITTING_LEGACY_MODEL='e1184548085af19dc0142fd01c25fe667b2be7e661bee50c03fd821899fb1c42'
OLD15_PCK='bdd6c5f2e202a4072e5d3f41024d0ea97e384f0435caedbd7afebebdef74b3c1'
CAPSTONE_SOURCE_ASSETS={
 'assets/generated/characters/painted_liang_combat_v4.png':'4812052ca14b016e43818713eaefe3a15ba3baa79fc421a8d40fc1e6774b5f33',
 'assets/generated/characters/painted_liang_portrait_v1.png':'ce56fcca4b2bfaa5af6511df62b65e1463fc21437d5d452d8cb75ede00e081d3',
 'assets/generated/characters/liang_provenance/combat-v4-review.json':'a1041d94a31df1a21542f766d7698e54d1bf797f98212890e6e48e47b767660c',
 'assets/generated/characters/liang_provenance/combat-v4-measurements.json':'c449ffee9ce988bca9121e2ea0e36b08b9e356fae28a0bca1b2df482f2e51555',
 'assets/generated/characters/liang_provenance/portrait-v1-review.json':'21cba51f3aa572a13dcae5e5add7a3be48ecaf2f7c1bc9dcf594be228fe0f8e9',
}
SCHEMA13='4e052447cb4dbfed20ee3fd22f23261aef043ad7791a457e1e737fe8faa1176d'
LEGACY_FIXTURES='9087fd567f3fa6953ad040025e084b054f535927042f9c8b868318bbab140a46'
JOURNAL_ORACLE='38cb8469799e8169201c06e203cd219901e3d06c159c09998ffc2e577ff0c443'
EXPECTED_JOURNAL_CHECKS=2832  # Independently measured full-measure02; real Main/J/HUD/World/M, immutable117/14.
EXPECTED_POLISH_CHECKS=460  # Independently measured actual paint resources/draw calls/font-cache gates.
EXPECTED_CONSIGNEE_CHECKS=1036  # Independently measured actual chapter14 scene/model/save/art gates.
EXPECTED_CAPSTONE_CHECKS=1179  # Measured source rehearsal02; later stable rerun must pass.
EXPECTED_CHECKS=21589  # Measured source21584 plus exactly five still-pending PCK-only checks; no PCK pass claim.
EXPECTED_SOURCE_CHECKS=21584  # Measured full-measure02 with zero failures; fresh strict repeat required.
EXPECTED_FITTING_CHECKS=12369  # Measured real Main/controller/native input/metrics/history/schema16 partition.
EXPECTED_TRANSFER_CHECKS=363  # Measured full16 raw transport matrix, retaining1–14 and adding15/16.
EXPECTED_CONDITION_CHECKS=191  # Independently marked actual companion-condition runtime gates.
EXPECTED_EXPLORATION_CHECKS=349
EXPECTED_UNIFIED_CHECKS=1247
EXPECTED_PRESERVED_CHECKS=1471
COMPLETE_SCOPE='Audit scope: complete; prepared state/input only; no browser or physical desktop-close claim'
PRESERVED_COVERAGE='Preserved noncombat exact-runtime coverage:'
UNIFIED_COVERAGE='Schema13 unified automatic exact-runtime coverage:'
EXPLORATION_COVERAGE='Ordered exploration party exact-runtime coverage:'
CONDITION_COVERAGE='Exploration companion condition exact-runtime coverage:'
TRANSFER_COVERAGE='Empty-slot save transfer exact-runtime coverage:'
CONSIGNEE_COVERAGE='Schema14 consignee chapter exact-runtime coverage:'
POLISH_COVERAGE='Heting paint-only polish exact-runtime coverage:'
CAPSTONE_COVERAGE='Schema15 capstone chapter exact-runtime coverage:'
FITTING_COVERAGE='Schema16 equipment fitting exact-runtime coverage:'
JOURNAL_COVERAGE='Schema16 journal guidance exact-runtime coverage:'
SOURCE_PENDING='SOURCE REHEARSAL: PENDING exactly5 packaging-only assertions until exact final PCK; no exported-pack claim'
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

def verify_legacy_fixtures(directory):
    directory=Path(directory)
    manifest=directory/'provenance.json'
    if sha(manifest)!=LEGACY_FIXTURES:raise RuntimeError('Legacy fixture provenance changed')
    fixtures=json.loads(manifest.read_text(encoding='utf-8'))['fixtures']
    if [item['version'] for item in fixtures]!=list(range(1,14)):raise RuntimeError('Legacy fixture schema coverage changed')
    for item in fixtures:
        path=relative(item['path'])
        if path.as_posix()!=f"tests/fixtures/legacy_saves/schema_{item['version']:02d}_default.json":raise RuntimeError('Unexpected historical fixture path')
        source=directory/path.name
        if source.is_symlink() or sha(source)!=item['sha256']:raise RuntimeError('Legacy save fixture changed: '+path.name)
    return LEGACY_FIXTURES


def audit_environment(directory, platform=None):
    env=os.environ.copy();platform=os.name if platform is None else platform
    data=directory/'web-smoke-data';config=directory/'config';cache=directory/'cache';home=directory/'home'
    for path in (data,config,cache,home):path.mkdir(parents=True,exist_ok=False)
    env.update(HOME=str(home),XDG_DATA_HOME=data.as_posix(),XDG_CONFIG_HOME=config.as_posix(),XDG_CACHE_HOME=cache.as_posix(),HERO_AUDIT_PYTHON=sys.executable)
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
    if root == ROOT:verify_capstone_inputs(root);verify_fitting_inputs(root);verify_journal_inputs(root)
    return sha(manifest)


def completed_pack_checks(text, exit_code):
    """Fail closed on pre-automatic, partial, rehearsal, duplicate, pre-transfer, pre-consignee, pre-polish, pre-capstone, pre-fitting, pre-journal, unmeasured or error logs."""
    if exit_code != 0 or min(EXPECTED_CHECKS,EXPECTED_UNIFIED_CHECKS,EXPECTED_PRESERVED_CHECKS,EXPECTED_EXPLORATION_CHECKS,EXPECTED_CONDITION_CHECKS,EXPECTED_TRANSFER_CHECKS,EXPECTED_CONSIGNEE_CHECKS,EXPECTED_POLISH_CHECKS,EXPECTED_CAPSTONE_CHECKS,EXPECTED_FITTING_CHECKS,EXPECTED_JOURNAL_CHECKS)<=0:
        return None
    if EXPECTED_SOURCE_CHECKS != EXPECTED_CHECKS-5: return None
    if EXPECTED_CHECKS != 92+EXPECTED_PRESERVED_CHECKS+EXPECTED_UNIFIED_CHECKS+EXPECTED_EXPLORATION_CHECKS+EXPECTED_CONDITION_CHECKS+EXPECTED_TRANSFER_CHECKS+EXPECTED_CONSIGNEE_CHECKS+EXPECTED_POLISH_CHECKS+EXPECTED_CAPSTONE_CHECKS+EXPECTED_FITTING_CHECKS+EXPECTED_JOURNAL_CHECKS: return None
    lines=text.splitlines()
    if [line for line in lines if line.lstrip().startswith('Audit scope:')] != [COMPLETE_SCOPE]: return None
    if 'SOURCE REHEARSAL:' in text or any(marker in text for marker in OLD_COVERAGE): return None
    if any(line.lstrip().startswith(('ERROR:', 'SCRIPT ERROR:')) for line in lines): return None
    for marker,expected in ((PRESERVED_COVERAGE,EXPECTED_PRESERVED_CHECKS),(UNIFIED_COVERAGE,EXPECTED_UNIFIED_CHECKS),(EXPLORATION_COVERAGE,EXPECTED_EXPLORATION_CHECKS),(CONDITION_COVERAGE,EXPECTED_CONDITION_CHECKS),(TRANSFER_COVERAGE,EXPECTED_TRANSFER_CHECKS),(CONSIGNEE_COVERAGE,EXPECTED_CONSIGNEE_CHECKS),(POLISH_COVERAGE,EXPECTED_POLISH_CHECKS),(CAPSTONE_COVERAGE,EXPECTED_CAPSTONE_CHECKS),(FITTING_COVERAGE,EXPECTED_FITTING_CHECKS),(JOURNAL_COVERAGE,EXPECTED_JOURNAL_CHECKS)):
        coverage=[line for line in lines if line.lstrip().startswith(marker.removesuffix(':'))]
        if len(coverage)!=1 or re.fullmatch(re.escape(marker)+r' '+str(expected)+r' checks;[^\n]+',coverage[0]) is None: return None
    summaries=[line for line in lines if line.lstrip().startswith(('PASS:', 'FAIL:'))]
    if summaries != [f'PASS: {EXPECTED_CHECKS} exported-pack checks; 0 failures']: return None
    return EXPECTED_CHECKS


def audit_inputs(root=None):
    """Bind external driver/wrapper/readers/fixtures before and after execution."""
    root=ROOT if root is None else Path(root)
    names=['tools/smoke_export.gd','tools/audit_web_export.py','tools/run_godot_check.py']
    names += ['tests/fixtures/'+name for name in (
        'v019_game_state.gd.txt','v020_game_state.gd.txt','v017_game_state.gd.txt',
        'v022_game_state.gd.txt','v025_game_state.gd.txt','v028_game_state.gd.txt','v028_game_state.provenance.json',
        'capstone/schema_14_default.json','capstone/schema_14_provenance.json',
        'v029_game_state.gd.txt','weapon_fitting/schema_14_default.json','weapon_fitting/schema_15_default.json',
        'weapon_fitting/provenance.json','weapon_fitting/legacy_automatic.gd.txt')]
    names += ['tests/capstone_package_fixture_producer.gd','tests/journal_guidance_frozen_oracle.json']
    names += ['tests/fixtures/legacy_saves/provenance.json']
    names += [f'tests/fixtures/legacy_saves/schema_{version:02d}_default.json' for version in range(1,14)]
    return {name:sha(root/name) for name in names}


def verify_capstone_inputs(root=None):
    root=ROOT if root is None else Path(root)
    pins=dict(CAPSTONE_SOURCE_ASSETS)
    pins.update({'tests/fixtures/v028_game_state.gd.txt':SCHEMA14,
                 'tests/fixtures/capstone/schema_14_default.json':SCHEMA14_SAVE,
                 'tests/fixtures/capstone/schema_14_provenance.json':SCHEMA14_PROVENANCE})
    for name,digest in pins.items():
        path=root/name
        if path.is_symlink() or sha(path)!=digest:raise RuntimeError('Pinned capstone source/producer input changed: '+name)
    doc=json.loads((root/'tests/fixtures/capstone/schema_14_default.json').read_text(encoding='utf-8'))
    if doc['version']!=14 or any(key.startswith('capstone_') for key in doc['player']):
        raise RuntimeError('Authentic14 fixture has modern header/field contamination')
    return pins


def verify_fitting_inputs(root=None):
    """Read-only pins for authentic15 producer/fixture and original combat source."""
    root=ROOT if root is None else Path(root)
    pins={'tests/fixtures/v028_game_state.gd.txt':SCHEMA14,
          'tests/fixtures/v029_game_state.gd.txt':SCHEMA15,
          'tests/fixtures/weapon_fitting/schema_14_default.json':SCHEMA14_SAVE,
          'tests/fixtures/weapon_fitting/schema_15_default.json':SCHEMA15_SAVE,
          'tests/fixtures/weapon_fitting/provenance.json':FITTING_PROVENANCE,
          'tests/fixtures/weapon_fitting/legacy_automatic.gd.txt':FITTING_LEGACY_MODEL}
    for name,digest in pins.items():
        path=root/name
        if path.is_symlink() or not path.is_file() or sha(path)!=digest:
            raise RuntimeError('Pinned fitting historical input changed: '+name)
    provenance=json.loads((root/'tests/fixtures/weapon_fitting/provenance.json').read_text(encoding='utf-8'))
    if provenance['legacy_manifest_sha256']!=LEGACY_FIXTURES or [entry['version'] for entry in provenance['fixtures']]!=[14,15]:
        raise RuntimeError('Fitting historical coverage/provenance changed')
    for item in provenance['fixtures']:
        name=relative(item['path']).as_posix();reader=relative(item['source']).as_posix()
        if name!=f"tests/fixtures/weapon_fitting/schema_{item['version']}_default.json" or reader!=f"tests/fixtures/v0{item['version']+14}_game_state.gd.txt":
            raise RuntimeError('Unexpected fitting historical fixture or producer path')
        path=root/name;source=root/reader
        if path.stat().st_size!=item['bytes'] or sha(path)!=item['sha256'] or source.stat().st_size!=item['source_bytes'] or sha(source)!=item['source_sha256']:
            raise RuntimeError('Fitting historical size/hash mismatch')
        document=json.loads(path.read_text(encoding='utf-8'))
        if document['version']!=item['version'] or any(key.startswith('weapon_fitting') for key in document['player']):
            raise RuntimeError('Authentic pre16 fixture has modern header/field contamination')
    old15=provenance['fixtures'][1]
    if old15['kind']!='actual-old15-pck-producer-default' or old15['pck_sha256']!=OLD15_PCK or old15['pck_bytes']!=59251392:
        raise RuntimeError('Actual old15 PCK provenance changed')
    return pins


def verify_journal_inputs(root=None):
    """Immutable phase-1 observation corpus, external to every release PCK."""
    root=ROOT if root is None else Path(root)
    name='tests/journal_guidance_frozen_oracle.json';path=root/name
    if path.is_symlink() or not path.is_file() or sha(path)!=JOURNAL_ORACLE:
        raise RuntimeError('Pinned journal observation oracle changed: '+name)
    oracle=json.loads(path.read_text(encoding='utf-8'))
    labels=[row['label'] for row in oracle['rows']]
    repairs=oracle['reviewed_target_differences']
    if len(labels)!=117 or len(set(labels))!=117 or len(repairs)!=14 or len({row['label'] for row in repairs})!=14:
        raise RuntimeError('Journal frozen117/14 coverage changed')
    if any(row['label'] not in labels or row['winning_arc']!='qin_rope' for row in repairs):
        raise RuntimeError('Journal reviewed target repair scope changed')
    return {name:JOURNAL_ORACLE}


def completed_source_checks(text, exit_code):
    """Same full ten-partition gate, with precisely the five pack-only checks pending."""
    lines=text.splitlines()
    if [line for line in lines if line.lstrip().startswith('SOURCE REHEARSAL:')] != [SOURCE_PENDING]:return None
    if [line for line in lines if line.lstrip().startswith(('PASS:', 'FAIL:'))] != [f'PASS: {EXPECTED_SOURCE_CHECKS} source-rehearsal checks; 0 failures']:return None
    synthetic='\n'.join(line for line in lines if line!=SOURCE_PENDING)
    synthetic=synthetic.replace(f'PASS: {EXPECTED_SOURCE_CHECKS} source-rehearsal checks; 0 failures',f'PASS: {EXPECTED_CHECKS} exported-pack checks; 0 failures')
    return EXPECTED_SOURCE_CHECKS if completed_pack_checks(synthetic,exit_code) is not None else None


def source_snapshot(root=None):
    """Capture actual export inputs and external audit inputs; no Git/credential reads."""
    root=ROOT if root is None else Path(root)
    paths=[root/name for name in ('project.godot','export_presets.cfg')]
    for name in ('assets','scripts','scenes','licenses','web'):
        paths.extend(p for p in (root/name).rglob('*') if p.is_file())
    snapshot={p.relative_to(root).as_posix():sha(p) for p in paths}
    snapshot.update(audit_inputs(root))
    return dict(sorted(snapshot.items()))


def source_rehearsal(directory,godot):
    """Never export. Refuse overwrite and preserve failed/interrupted attempts."""
    directory.mkdir(parents=True,exist_ok=False)
    env=audit_environment(directory)
    env.setdefault('GODOT_SILENCE_ROOT_WARNING','1')
    env.setdefault('HERO_CHECK_TIMEOUT_SECONDS','900')
    version=subprocess.check_output([godot,'--headless','--version'],env=env,text=True).strip()
    if version!=ENGINE:raise RuntimeError('Unexpected Godot engine')
    verify_legacy_fixtures(ROOT/'tests/fixtures/legacy_saves');verify_capstone_inputs();verify_fitting_inputs();verify_journal_inputs()
    before=source_snapshot()
    (directory/'SOURCE-BEFORE.json').write_text(json.dumps(before,indent=2)+'\n',encoding='utf-8')
    command=[sys.executable,str(ROOT/'tools/run_godot_check.py'),godot,'--headless','--audio-driver','Dummy',
             '--path',str(ROOT),'--script',str(ROOT/'tools/smoke_export.gd'),'--','--source-rehearsal',
             '--schema16-subject='+str(directory/'CURRENT16-SUBJECT.json'),
             '--journal-oracle='+str(ROOT/'tests/journal_guidance_frozen_oracle.json')]
    log=directory/'SOURCE-REHEARSAL.log'
    with log.open('wb') as output:
        result=subprocess.run(command,env=env,cwd=ROOT,stdout=output,stderr=subprocess.STDOUT)
    after=source_snapshot()
    (directory/'SOURCE-AFTER.json').write_text(json.dumps(after,indent=2)+'\n',encoding='utf-8')
    raw=log.read_text(encoding='utf-8',errors='replace')
    checks=completed_source_checks(raw,result.returncode)
    changed=sorted(k for k in set(before)|set(after) if before.get(k)!=after.get(k))
    evidence={'engine':version,'command':command,'exit_code':result.returncode,'checks':checks,
              'expected_source_checks':EXPECTED_SOURCE_CHECKS,'pending_pack_only_checks':5,
              'source_before_sha256':sha(directory/'SOURCE-BEFORE.json'),'source_after_sha256':sha(directory/'SOURCE-AFTER.json'),
              'changed_inputs':changed,'source_unchanged':not changed,'provisional':bool(changed),
              'log_sha256':sha(log),'schema16_subject_sha256':sha(directory/'CURRENT16-SUBJECT.json') if (directory/'CURRENT16-SUBJECT.json').is_file() else None,
              'passed':checks is not None and not changed,
              'scope':'Full source rehearsal only; exactly five true PCK assertions pending. No export, exactPCK, browser, full-old-runtime or pixel claim.'}
    (directory/'SOURCE-REHEARSAL.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    print(raw,end='');print(json.dumps(evidence));return 0 if evidence['passed'] else 1


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('build',type=Path);parser.add_argument('--godot',default=os.environ.get('GODOT_BIN','godot'))
    parser.add_argument('--source-rehearsal',action='store_true',help='Use build argument as a fresh evidence directory; never export/build/package')
    args=parser.parse_args();build=args.build.resolve()
    if args.source_rehearsal:return source_rehearsal(build,args.godot)
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
    schema13=ROOT/'tests/fixtures/v025_game_state.gd.txt'
    if sha(schema13)!=SCHEMA13:raise RuntimeError('Historical schema13 Web25 reader changed')
    schema14=ROOT/'tests/fixtures/v028_game_state.gd.txt'
    schema14_save=ROOT/'tests/fixtures/capstone/schema_14_default.json'
    schema15=ROOT/'tests/fixtures/v029_game_state.gd.txt'
    schema15_save=ROOT/'tests/fixtures/weapon_fitting/schema_15_default.json'
    legacy_model=ROOT/'tests/fixtures/weapon_fitting/legacy_automatic.gd.txt'
    verify_capstone_inputs();verify_fitting_inputs();verify_journal_inputs()
    legacy_fixtures=ROOT/'tests/fixtures/legacy_saves'
    verify_legacy_fixtures(legacy_fixtures)
    inputs=audit_inputs()
    directory=build/'exact-pack-audit'
    directory.mkdir()  # Refuse to overwrite previous audit evidence or test profiles.
    env=audit_environment(directory)
    version=subprocess.check_output([args.godot,'--headless','--version'],env=env,text=True).strip()
    if version!=ENGINE:raise RuntimeError('Unexpected Godot engine')
    log=directory/'PCK-AUDIT.log';driver=ROOT/'tools/smoke_export.gd'
    command=[sys.executable,str(ROOT/'tools/run_godot_check.py'),args.godot,'--headless','--audio-driver','Dummy',
             '--path',str(build/'site'),'--main-pack',str(build/'site/index.pck'),'--script',str(driver),
             '--','--legacy-reader='+legacy.as_posix(),'--schema11-reader='+schema11.as_posix(),'--schema12-reader='+schema12.as_posix(),'--schema9-reader='+schema9.as_posix(),'--schema13-reader='+schema13.as_posix(),'--schema14-reader='+schema14.as_posix(),'--schema14-save='+schema14_save.as_posix(),'--legacy-save-fixtures='+legacy_fixtures.as_posix(),
             '--schema15-reader='+schema15.as_posix(),'--schema15-save='+schema15_save.as_posix(),
             '--fitting-legacy-model='+legacy_model.as_posix(),'--schema16-subject='+str(directory/'CURRENT16-SUBJECT.json'),
             '--journal-oracle='+str(ROOT/'tests/journal_guidance_frozen_oracle.json')]
    with log.open('wb') as output:
        result=subprocess.run(command,env=env,cwd=build/'site',stdout=output,stderr=subprocess.STDOUT)
    text=log.read_text(encoding='utf-8',errors='replace')
    checks=completed_pack_checks(text,result.returncode)
    passed=checks is not None
    verify_site(build,report)
    if verify_source_manifest(build,report)!=source_manifest_sha256:raise RuntimeError('Source manifest changed during audit')
    if audit_inputs()!=inputs:raise RuntimeError('Audit tool/reader/fixture inputs changed during execution')
    verify_legacy_fixtures(legacy_fixtures)
    evidence={'source_commit':report['source_commit'],'engine':version,'pck_sha256':sha(build/'site/index.pck'),
              'audit_sha256':inputs['tools/smoke_export.gd'],'audit_input_sha256':inputs,'legacy_sha256':LEGACY,'schema11_reader_sha256':SCHEMA11,'schema9_reader_sha256':SCHEMA9,'schema12_reader_sha256':SCHEMA12,'source_manifest_sha256':source_manifest_sha256,'schema13_reader_sha256':SCHEMA13,'legacy_fixtures_manifest_sha256':LEGACY_FIXTURES,'schema14_reader_sha256':SCHEMA14,'schema14_save_sha256':SCHEMA14_SAVE,'schema14_provenance_sha256':SCHEMA14_PROVENANCE,'schema15_reader_sha256':SCHEMA15,'schema15_save_sha256':SCHEMA15_SAVE,'fitting_provenance_sha256':FITTING_PROVENANCE,'fitting_legacy_model_sha256':FITTING_LEGACY_MODEL,'save_schema':16,'party_capacity':4,'log_sha256':sha(log),'exit_code':result.returncode,
              'passed':passed,'checks':checks,'preserved_checks':EXPECTED_PRESERVED_CHECKS if passed else None,'unified_checks':EXPECTED_UNIFIED_CHECKS if passed else None,'exploration_checks':EXPECTED_EXPLORATION_CHECKS if passed else None,'condition_checks':EXPECTED_CONDITION_CHECKS if passed else None,'transfer_checks':EXPECTED_TRANSFER_CHECKS if passed else None,'consignee_checks':EXPECTED_CONSIGNEE_CHECKS if passed else None,'polish_checks':EXPECTED_POLISH_CHECKS if passed else None,'capstone_checks':EXPECTED_CAPSTONE_CHECKS if passed else None,'fitting_checks':EXPECTED_FITTING_CHECKS if passed else None,'journal_checks':EXPECTED_JOURNAL_CHECKS if passed else None,'journal_oracle_sha256':JOURNAL_ORACLE,'journal_scope':'Prepared actual shipped Main/session/J/HUD/World/M; no migration, no serialized journal, external117/14 oracle; actual retained Web30 PCK roundtrip separately required','schema16_subject_sha256':sha(directory/'CURRENT16-SUBJECT.json') if (directory/'CURRENT16-SUBJECT.json').is_file() else None,'historical_reader_scope':'Authentic byte-pinned13/14/15 sources with current packed dependencies;13 rejects genuine14,14 rejects genuine15,15 rejects actual packed16; complete-old15 process on this subject is a separate later gate','polish_scope':'actual paint resource/draw-call/font-cache contracts; no native framebuffer or browser pixel acceptance','transfer_transport':'native injected fake; real packed core/UI; not browser download/persistence','scope':'Exact Web PCK under native editor; not browser graphics/audio/persistence or physical window-close'}
    (directory/'PCK-AUDIT.json').write_text(json.dumps(evidence,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(evidence));return 0 if passed else 1

if __name__=='__main__':sys.exit(main())
