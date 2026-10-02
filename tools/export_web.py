#!/usr/bin/env python3
"""Build a bounded, source-bound single-thread Web preview. Does not serve/deploy."""
from pathlib import Path
import argparse, hashlib, json, os, shutil, subprocess, time, signal, zipfile, re
ROOT = Path(__file__).resolve().parent.parent
MIB = 1024**2
TEMPLATE = "1446f79dc12f60ce5d244c39fb6628ec298337ca5c4f91a16491feea72aa1bc9"
ENGINE = "4.6.3.stable.official.7d41c59c4"

def sha(path):
    with Path(path).open("rb") as source: return hashlib.file_digest(source, "sha256").hexdigest()
def sources():
    paths = [ROOT / name for name in ["project.godot", "export_presets.cfg"]]
    for name in ["assets", "scripts", "scenes", "licenses", "web"]:
        paths.extend(path for path in (ROOT / name).rglob("*") if path.is_file())
    return {str(path.relative_to(ROOT)): sha(path) for path in sorted(paths)}
def free(path): return shutil.disk_usage(path).free

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label",required=True)
    args=parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*",args.label): parser.error("Invalid label")
    build=ROOT/"builds"/args.label
    if build.exists(): parser.error("Preserve existing evidence; choose a new label")
    template=ROOT/"builds/export-data/godot/export_templates/4.6.3.stable/web_nothreads_release.zip"
    if not template.is_file() or sha(template)!=TEMPLATE: raise RuntimeError("Pinned official Web template missing or changed")
    dirty=subprocess.check_output(["git","status","--porcelain","--untracked-files=normal","--","assets","scripts","scenes","licenses","web","project.godot","export_presets.cfg","tools"],cwd=ROOT,text=True)
    if dirty: raise RuntimeError("Commit source and tools before export")
    before=sources();source_bytes=sum((ROOT/p).stat().st_size for p in before)
    extra=max(0,source_bytes-56*MIB)*3
    if free(ROOT)<768*MIB+extra: raise RuntimeError("Web build needs768MiB plus source-growth budget; desktop gate unchanged")
    build.mkdir();site=build/"site";site.mkdir()
    env=os.environ.copy();env.update(XDG_DATA_HOME=str(ROOT/"builds/export-data"),XDG_CONFIG_HOME=str(build/"config"),XDG_CACHE_HOME=str(build/"cache"))
    for key in ["XDG_CONFIG_HOME","XDG_CACHE_HOME"]:Path(env[key]).mkdir()
    version=subprocess.check_output(["godot","--headless","--version"],env=env,text=True).strip()
    if version!=ENGINE: raise RuntimeError("Unexpected engine version")
    record={"label":args.label,"source_commit":subprocess.check_output(["git","rev-parse","HEAD"],cwd=ROOT,text=True).strip(),"engine":version,"template_sha256":TEMPLATE,"source_entries":len(before),"source_bytes":source_bytes,"build_script_sha256":sha(__file__),"start_free":free(ROOT),"minimum_free":free(ROOT),"reserve_bytes":512*MIB,"status":"building","browser_validation":"pending","deployment":"not performed"}
    (build/"SOURCE-SHA256SUMS.txt").write_text("".join(v+"  "+k+"\n" for k,v in before.items()))
    started=time.monotonic()
    with (build/"EXPORT.log").open("wb") as log:
        proc=subprocess.Popen(["godot","--headless","--path",str(ROOT),"--export-release","Web Single Thread",str(site/"index.html")],cwd=ROOT,env=env,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        while proc.poll() is None:
            record["minimum_free"]=min(record["minimum_free"],free(ROOT))
            generated=sum(p.stat().st_size for p in build.rglob("*") if p.is_file())
            if free(ROOT)<512*MIB or generated>256*MIB or time.monotonic()-started>180:
                os.killpg(proc.pid,signal.SIGKILL);proc.wait();record["abort"]="Web reserve, output cap or timeout";break
            time.sleep(.25)
    record["exit_code"]=proc.returncode;record["source_unchanged"]=sources()==before
    output=(build/"EXPORT.log").read_text()
    record["status"]="exported" if proc.returncode==0 and record["source_unchanged"] and "ERROR:" not in output else "failed"
    (build/"BUILD-REPORT.json").write_text(json.dumps(record,indent=2)+"\n")
    if record["status"]!="exported": raise RuntimeError("Web export failed; evidence retained")
    for name in ["index.html","index.js","index.wasm","index.pck"]:
        if not (site/name).is_file(): raise RuntimeError("Expected Web asset missing: "+name)
    if any(site.glob("*service.worker*")): raise RuntimeError("Unexpected PWA/service worker")
    if (site/"index.wasm").read_bytes()[:4]!=b"\0asm": raise RuntimeError("Invalid WebAssembly header")
    shutil.copytree(ROOT/"licenses",site/"licenses")
    shutil.copy2(ROOT/"assets/fonts/LICENSE.txt",site/"licenses/FONT-LICENSE.txt")
    for name in ["ASSET_LICENSES.md","WEB_EXPORT.md"]:
        if (ROOT/name).is_file():shutil.copy2(ROOT/name,site/name)
    hashes={str(p.relative_to(site)):sha(p) for p in sorted(site.rglob("*")) if p.is_file()}
    record["site_files"]={name:{"sha256":value,"bytes":(site/name).stat().st_size} for name,value in hashes.items()}
    archive=build/(args.label+".zip")
    if free(ROOT)<640*MIB: raise RuntimeError("Keep512MiB reserve before ZIP creation")
    with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED,compresslevel=6) as bundle:
        for path in sorted(hashes):bundle.write(site/path,"Hero-Web/"+path)
    with zipfile.ZipFile(archive) as bundle:
        if set(bundle.namelist())!={"Hero-Web/"+p for p in hashes}: raise RuntimeError("Archive membership mismatch")
        for path,digest in hashes.items():
            if hashlib.sha256(bundle.read("Hero-Web/"+path)).hexdigest()!=digest: raise RuntimeError("Archive bytes differ")
    record["archive"]={"file":archive.name,"bytes":archive.stat().st_size,"sha256":sha(archive)}
    record["minimum_free"]=min(record["minimum_free"],free(ROOT));record["status"]="archive verified; browser testing pending"
    (build/"BUILD-REPORT.json").write_text(json.dumps(record,indent=2)+"\n")
    (build/"SHA256SUMS.txt").write_text(sha(archive)+"  "+archive.name+"\n")
    print(json.dumps(record))
if __name__=="__main__":main()
