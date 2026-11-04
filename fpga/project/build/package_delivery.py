"""Create and verify a self-contained offline delivery. Never accesses hardware."""
from pathlib import Path
import hashlib,json,zipfile

root=Path(__file__).resolve().parents[1]
output=root.with_suffix('.zip')
excluded_dirs={'.Xil','.cache','__pycache__','xsim.dir','.git'}
excluded_suffixes={'.wdb','.pyc'}
files=sorted(p for p in root.rglob('*') if p.is_file()
             and not excluded_dirs.intersection(p.relative_to(root).parts)
             and not any(part.endswith('.cache') for part in p.relative_to(root).parts)
             and p.suffix not in excluded_suffixes and p.name!='manifest_sha256.json')
entries=[{'path':p.relative_to(root).as_posix(),'bytes':p.stat().st_size,
          'sha256':hashlib.sha256(p.read_bytes()).hexdigest()} for p in files]
manifest=root/'manifest_sha256.json'
manifest.write_text(json.dumps({'scope':'offline only; no hardware operation',
  'files':entries},indent=2)+'\n',encoding='utf-8')
with zipfile.ZipFile(output,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as archive:
    for path in files+[manifest]:archive.write(path,root.name+'/'+path.relative_to(root).as_posix())
with zipfile.ZipFile(output) as archive:
    assert archive.testzip() is None
    for entry in entries:
        data=archive.read(root.name+'/'+entry['path'])
        assert len(data)==entry['bytes'] and hashlib.sha256(data).hexdigest()==entry['sha256'],entry['path']
digest=hashlib.sha256(output.read_bytes()).hexdigest()
output.with_suffix('.zip.sha256').write_text(digest+'  '+output.name+'\n',encoding='ascii')
print(json.dumps({'ZIP':str(output),'files':len(entries)+1,'bytes':output.stat().st_size,
                  'sha256':digest,'CRC_and_payload_SHA256':'PASS'},indent=2))
