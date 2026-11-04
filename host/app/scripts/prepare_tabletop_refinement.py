#!/usr/bin/env python3
"""Training-only table crops and imaging perturbations; preserve parent splits."""
from pathlib import Path
import json
import hashlib
import os
import cv2
import numpy as np
import yaml
ROOT=Path(__file__).resolve().parents[1]

def main():
    src=ROOT/'datasets/tools_v2';out=ROOT/'datasets/tools_tabletop_v3'
    if out.exists():raise SystemExit('Refusing to overwrite dataset')
    out.mkdir();rng=np.random.default_rng(119)
    manifest=json.loads((src/'manifest.json').read_text());rows=[]
    for split in ('train','val','test'):
        for kind in ('images','labels'):
            dest=out/kind/split;dest.mkdir(parents=True)
            for p in (src/kind/split).iterdir():
                if p.suffix in ('.jpg','.png','.txt'):os.link(p,dest/p.name)
    for row in manifest['images']:
        if row['split']!='train' or row.get('synthetic'):continue
        is_site=row['source']=='Gemini2 real tabletop'
        # Real site: 96 variants. Public: one derivative for each other original.
        if not is_site and rng.random()>.4:continue
        image=cv2.imread(str(src/row['image']));h,w=image.shape[:2]
        for j in range(96 if is_site else 1):
            boxes=row['objects']
            if is_site:
                # All seven annotations stay visible; zoom from full frame to table.
                a=np.array([b for _,b in boxes]);lo=a[:,:2].min(0);hi=a[:,2:].max(0)
                x1=int(rng.uniform(0,max(1,lo[0]-8)));y1=int(rng.uniform(0,max(1,lo[1]-8)))
                x2=int(rng.uniform(min(w,hi[0]+8),w+1));y2=int(rng.uniform(min(h,hi[1]+8),h+1))
            else:x1,y1,x2,y2=0,0,w,h
            crop=image[y1:y2,x1:x2].copy();ch,cw=crop.shape[:2]
            alpha=float(rng.uniform(.65,1.3));beta=float(rng.uniform(-16,16))
            crop=np.clip(crop.astype(np.float32)*alpha+beta,0,255).astype(np.uint8)
            effect=j%4 if is_site else int(rng.integers(4))
            if effect==0:crop=cv2.GaussianBlur(crop,(3,3),.7)
            if effect==1:
                crop=np.clip(crop.astype(float)+rng.normal(0,2,crop.shape),0,255).astype(np.uint8)
            if effect==2:
                ok,enc=cv2.imencode('.jpg',crop,[cv2.IMWRITE_JPEG_QUALITY,55]);crop=cv2.imdecode(enc,1)
            name=f'refine_{row["id"]}_{j:03d}'
            file=out/'images/train'/f'{name}.jpg';cv2.imwrite(str(file),crop)
            labels=[]
            for cls,(a,b,c,d) in boxes:
                labels.append(f'{cls} {((a+c)/2-x1)/cw:.8f} {((b+d)/2-y1)/ch:.8f} {(c-a)/cw:.8f} {(d-b)/ch:.8f}')
            (out/'labels/train'/f'{name}.txt').write_text('\n'.join(labels)+'\n')
            rows.append({'image':str(file.relative_to(out)),'parent':row['image'],'group':row['group'],
                         'split':'train','synthetic':True,'crop_xyxy':[x1,y1,x2,y2],
                         'alpha':alpha,'beta':beta,'effect':effect,'sha256':hashlib.sha256(file.read_bytes()).hexdigest()})
    report={'parent_manifest':str(src/'manifest.json'),'seed':119,'derivatives':rows,
            'validation_test_unchanged':True,'counts':{s:len(list((out/'images'/s).glob('*'))) for s in ('train','val','test')},
            'limits':'No additional independent real photos; same old validation reused for selection. No generated depth. Crops and photometric derivatives are training-only. Parent licenses and groups apply.'}
    (out/'manifest.json').write_text(json.dumps(report,indent=2))
    (out/'data.yaml').write_text(yaml.safe_dump({'path':str(out),'train':'images/train','val':'images/val','test':'images/test','names':manifest['names']}))
    print(report['counts'])
if __name__=='__main__':main()
