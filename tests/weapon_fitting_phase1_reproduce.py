#!/usr/bin/env python3
"""Reproduce focused source fitting checks with isolated disposable test data.

From the source root:
  python3 tests/weapon_fitting_phase1_reproduce.py --godot godot --output /tmp/hero-fitting-new-run
A headless editor import prepares the class/resource cache before focused checks.
Optional --old15-pck PATH also exercises the complete old15 reader. Full project
regression is separately run by bash run-tests.sh with the documented three old
PCK environment variables. This focused runner does not certify UI or packages.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

ROOT=Path(__file__).resolve().parent.parent
HASHES={
 'tests/fixtures/weapon_fitting/pressure_entry_reference.json':'cc8874ab19261538ff4bc092e6bb84a2db9f0d0534435217a83197e7602c1b0b',
 'tests/fixtures/weapon_fitting/legacy_automatic.gd.txt':'e1184548085af19dc0142fd01c25fe667b2be7e661bee50c03fd821899fb1c42',
}
PCK15='bdd6c5f2e202a4072e5d3f41024d0ea97e384f0435caedbd7afebebdef74b3c1'
def digest(path):
 h=hashlib.sha256()
 with path.open('rb') as f:
  for b in iter(lambda:f.read(1024*1024),b''):h.update(b)
 return h.hexdigest()
def snapshot():
 binding=json.loads((ROOT/'tests/weapon_fitting_phase1_binding.json').read_text())['current_owned_source']
 return {name:digest(ROOT/name) for name in sorted(binding)}
def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--godot',default='godot');p.add_argument('--output',required=True);p.add_argument('--old15-pck')
 a=p.parse_args();out=Path(a.output).resolve()
 if out.exists() or out.is_relative_to(ROOT):raise SystemExit('Choose a fresh output directory outside source; retained evidence is never overwritten')
 engine=shutil.which(a.godot)
 if not engine:raise SystemExit('Official Godot4.6.3 executable not found')
 version=subprocess.check_output([engine,'--version'],text=True).strip()
 if version!='4.6.3.stable.official.7d41c59c4':raise SystemExit('This evidence contract requires official Godot4.6.3')
 for name,h in HASHES.items():
  if digest(ROOT/name)!=h:raise SystemExit('Retained fixture hash mismatch: '+name)
 if a.old15_pck:
  pack=Path(a.old15_pck).resolve()
  if digest(pack)!=PCK15 or pack.stat().st_size!=59251392:raise SystemExit('Complete old15 PCK identity mismatch')
 out.mkdir(parents=True)
 old=out/'legacy_automatic.gd';old.write_bytes((ROOT/'tests/fixtures/weapon_fitting/legacy_automatic.gd.txt').read_bytes())
 if digest(old)!=HASHES['tests/fixtures/weapon_fitting/legacy_automatic.gd.txt']:raise SystemExit('Materialized adapter mismatch')
 before=snapshot();records=[]
 def run(name,args):
  folder=out/name;folder.mkdir()
  env=os.environ.copy()
  for key,child in [('HOME','home'),('XDG_DATA_HOME','data'),('XDG_CONFIG_HOME','config'),('XDG_CACHE_HOME','cache'),('TMPDIR','tmp')]:
   (folder/child).mkdir();env[key]=str(folder/child)
  command=[sys.executable,str(ROOT/'tools/run_godot_check.py'),engine,*args]
  log=folder/'engine.log'
  with log.open('xb') as f: result=subprocess.run(command,cwd=ROOT,env=env,stdout=f,stderr=subprocess.STDOUT)
  errors=re.findall(r'^(?:SCRIPT ERROR|ERROR):.*$',log.read_text(),re.M)
  records.append({'name':name,'command':command,'exit_code':result.returncode,'engine_errors':errors,'log_sha256':digest(log)})
  if result.returncode or errors:raise RuntimeError('Focused run failed: '+name)
 try:
  run('import',['--headless','--editor','--path',str(ROOT),'--import','--quit'])
  for test in ['rules','state','read_consumers','history','schema','trial_model','trial_metrics']:
   args=['--headless','--path',str(ROOT),'--script','res://tests/weapon_fitting_'+test+'_test.gd']
   if test=='trial_model':args+=['--','--legacy-model='+str(old),'--output='+str(out/'model-result.json')]
   if test=='trial_metrics':args+=['--','--numerical-entry='+str(ROOT/'tests/fixtures/weapon_fitting/pressure_entry_reference.json'),'--output='+str(out/'metrics-result.json')]
   run(test,args)
  if a.old15_pck:
   subject=out/'current16.json';control=out/'old15-positive.json'
   run('produce16',['--headless','--path',str(ROOT),'--script','res://tests/weapon_fitting_fixture_producer.gd','--','16',str(subject)])
   run('actual_old15_reader',['--headless','--main-pack',str(pack),'--script',str(ROOT/'tests/weapon_fitting_old15_pack_probe.gd'),'--',str(pack),str(subject),str(control)])
 finally:
  after=snapshot();changed=[n for n in sorted(set(before)|set(after)) if before.get(n)!=after.get(n)]
  report={'scope':'Focused source checks only; not full regression, UI, native, new package, browser or deployment','engine':version,'runs':records,'owned_source_changed':changed,'complete_old15_gate_enabled':bool(a.old15_pck)}
  for name,value in [('source-before.json',before),('source-after.json',after),('result.json',report)]:
   (out/name).write_text(json.dumps(value,indent=2)+'\n')
  if changed:raise RuntimeError('Owned source changed during run; no acceptance exception allowed')
 print(str(out/'result.json'))
if __name__=='__main__':main()
