"""Verify the merged delivery offline; no installation or hardware access."""
import csv, hashlib, json, re, sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
manifest=json.loads((root/'file_manifest.json').read_text(encoding='utf8'))
bad=[]
for record in manifest['files']:
    p=root/record['path']
    if not p.is_file() or p.stat().st_size!=record['bytes'] or hashlib.sha256(p.read_bytes()).hexdigest()!=record['sha256']:
        bad.append(record['path'])
paths=[r['path'] for r in manifest['files']]
for p in paths:
    if not re.fullmatch(r'[a-z0-9_./-]+',p) or '..' in Path(p).parts:bad.append('invalid_path:'+p)
    if Path(p).suffix in {'.mp4','.avi','.mov','.mkv','.wmv','.zip'}:bad.append('unwanted_archive_or_video:'+p)
for row in csv.DictReader((root/'metrics/metrics.csv').open(encoding='utf-8-sig',newline='')):
    if row['证据文件'] and not (root/'metrics'/row['证据文件']).is_file():bad.append('evidence:'+row['证据文件'])
for name,item in json.loads((root/'host/app/models/manifest.json').read_text(encoding='utf8')).items():
    if hashlib.sha256((root/'host/app/models'/name).read_bytes()).hexdigest()!=item['sha256']:bad.append('model:'+name)
print(json.dumps({'checked_files':len(paths),'bad_files':bad,'ok':not bad},ensure_ascii=False,indent=2))
sys.exit(bool(bad))
