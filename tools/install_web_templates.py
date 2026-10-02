#!/usr/bin/env python3
"""Extract only matching official single-thread Web templates from a verified TPZ."""
from pathlib import Path
import argparse, hashlib, json, zipfile
ROOT=Path(__file__).resolve().parent.parent
SHA512='da606b61c10157844f8300172df374472665f95015495cb1a7cd132c40ede404faa96cc1016a4b9662db9909ddea69632c4948b2cd11163438dad4808881fb68'
MEMBERS={'web_nothreads_debug.zip':'4a8a8ef7519637f7898fad25f09d3e466965e99c04e441682e1bc2d97a548922','web_nothreads_release.zip':'1446f79dc12f60ce5d244c39fb6628ec298337ca5c4f91a16491feea72aa1bc9'}
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('archive',type=Path);args=p.parse_args()
 with args.archive.open('rb') as source:
  if hashlib.file_digest(source,'sha512').hexdigest()!=SHA512:raise RuntimeError('Official4.6.3 archive checksum mismatch')
 target=ROOT/'builds/export-data/godot/export_templates/4.6.3.stable';target.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(args.archive) as archive:
  if archive.read('templates/version.txt').decode().strip()!='4.6.3.stable':raise RuntimeError('Template version mismatch')
  for name,expected in MEMBERS.items():
   content=archive.read('templates/'+name)
   if hashlib.sha256(content).hexdigest()!=expected:raise RuntimeError('Member digest mismatch')
   dest=target/name
   if dest.exists() and dest.read_bytes()!=content:raise RuntimeError('Refusing to replace a different installed template')
   if not dest.exists():dest.write_bytes(content)
 print(json.dumps({'source':'Official Godot4.6.3 export_templates.tpz','archive_sha512':SHA512,'installed':MEMBERS}))
if __name__=='__main__':main()
