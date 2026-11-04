#!/usr/bin/env python3
"""Four-class tool data: pinned public annotations + manually labelled RGB-D photos.

All derived images stay in their parent's training split. Synthetic composites
contain real photographed tool cutouts, never synthetic depth or test samples.
"""
import argparse
from collections import Counter
import hashlib
import json
import re
from pathlib import Path
import shutil
import cv2
import numpy as np
import pyarrow.parquet as pq
import yaml

ROOT = Path(__file__).resolve().parents[1]
NAMES = {0: 'screwdriver', 1: 'pliers', 2: 'scissors', 3: 'tweezers'}
REV = 'c4e319e03bf20cb595a7e6c3cd97ca94efdaa8af'
MAPPING = {'Screwdriver_bboxes': 0, 'Pliers_bboxes': 1,
           'Needle-nose pliers_bboxes': 1, 'Cutting pliers_bboxes': 2}


def sha(data):
    return hashlib.sha256(data).hexdigest()


def group_for(name):
    name = re.split(r'\.rf\.', name)[0]
    dated = re.match(r'\d{4}-\d{2}-\d{2}', name)
    if dated:
        return 'capture_day_' + dated.group()
    # Group video frames from the same recording, not only Roboflow variants.
    name = re.sub(r'(?i)(?:_mp4|_mov|\.mp4|\.mov).*', '', name)
    name = re.sub(r'(?i)(?:[_-]frame[_-]?\d+).*', '', name)
    return name


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=ROOT/'datasets/tools_v2')
    parser.add_argument('--parquet', type=Path, default=ROOT/'datasets/downloads/tool-safety-train-0.parquet')
    parser.add_argument('--composites', type=int, default=180)
    args = parser.parse_args()
    out = args.output
    if (out/'manifest.json').exists():
        parser.error('Finalized output exists; choose a new output directory')
    for split in ['train', 'val', 'test']:
        for kind in ['images', 'labels']:
            (out/kind/split).mkdir(parents=True, exist_ok=True)
    rows, counts, seen = [], Counter(), set()
    rng = np.random.default_rng(73)

    def save(name, image, objects, split, source, group, **extra):
        h, w = image.shape[:2]
        labels, kept = [], []
        for cls, box in objects:
            x1, y1, x2, y2 = box
            x1, x2 = np.clip([x1, x2], 0, w)
            y1, y2 = np.clip([y1, y2], 0, h)
            if x2-x1 < 2 or y2-y1 < 2:
                continue
            labels.append(f'{cls} {(x1+x2)/2/w:.8f} {(y1+y2)/2/h:.8f} {(x2-x1)/w:.8f} {(y2-y1)/h:.8f}')
            kept.append([int(cls), [float(x1), float(y1), float(x2), float(y2)]])
            counts[(split, NAMES[cls])] += 1
        if not labels:
            return
        path = out/'images'/split/(name+'.jpg')
        if not cv2.imwrite(str(path), image, [cv2.IMWRITE_JPEG_QUALITY, 95]):
            raise RuntimeError(f'Failed to save {path}')
        (out/'labels'/split/(name+'.txt')).write_text('\n'.join(labels)+'\n')
        rows.append(dict(id=name, image=str(path.relative_to(out)), split=split,
                         source=source, group=group, objects=kept,
                         sha256=sha(path.read_bytes()), **extra))

    public = pq.read_table(args.parquet, columns=['image','image_name',*MAPPING]).to_pylist()
    selected, dedup = [], set()
    for item in public:
        objects = [(cls, box) for column, cls in MAPPING.items() for box in (item[column] or [])]
        if not objects:
            continue
        name = item['image_name']
        # One Roboflow augmentation per original file. Group broader videos too.
        original = re.split(r'\.rf\.', name)[0]
        if original in dedup:
            continue
        image = cv2.imdecode(np.frombuffer(item['image']['bytes'], np.uint8), cv2.IMREAD_COLOR)
        if image is None:
            raise ValueError(f'Unreadable public image {name}')
        pixelhash = sha(image.tobytes())
        if pixelhash in seen:
            continue
        dedup.add(original); seen.add(pixelhash)
        selected.append((name, image, objects, group_for(name)))
    # Union similar images before splitting; rotated/source variants still need audit.
    hashes = []
    for _, im, _, _ in selected:
        gray=cv2.resize(cv2.cvtColor(im,cv2.COLOR_BGR2GRAY),(32,32)).astype(np.float32)
        dct=cv2.dct(gray)[:8,:8].ravel(); bits=dct>np.median(dct[1:])
        hashes.append(sum(int(v)<<i for i,v in enumerate(bits)))
    parent=list(range(len(selected)))
    def root(i):
        while parent[i]!=i:
            parent[i]=parent[parent[i]];i=parent[i]
        return i
    by_group={}
    for i, (_, _, _, group) in enumerate(selected):
        if group in by_group: parent[root(i)]=root(by_group[group])
        else: by_group[group]=i
        for j in range(i):
            if (hashes[i]^hashes[j]).bit_count()<=6:parent[root(i)]=root(j)
    for i,(name,im,objects,group) in enumerate(selected):
        merged=selected[root(i)][3]
        bucket=int(sha(merged.encode())[:8],16)%10
        split='test' if bucket==0 else ('val' if bucket==1 else 'train')
        save(f'safety_{i:04d}',im,objects,split,'tool-safety-dataset',merged,
             source_filename=name,original_group=group,revision=REV,
             annotation_method='public xyxy labels; cutting pliers mapped to task scissors class')

    # Keep established COCO separation; retain ordinary scissors in the new class.
    old=ROOT/'datasets/public_tools'
    for split in ['train','val','test']:
        paths=sorted((old/'images'/split).glob('coco*'))
        if split=='train':paths=paths[:300]
        for p in paths:
            im=cv2.imread(str(p));h,w=im.shape[:2];objects=[]
            for line in (old/'labels'/split/(p.stem+'.txt')).read_text().splitlines():
                c,x,y,bw,bh=map(float,line.split())
                if int(c)==2:objects.append((2,[(x-bw/2)*w,(y-bh/2)*h,(x+bw/2)*w,(y+bh/2)*h]))
            save(p.stem,im,objects,split,'COCO 2017',p.stem,
                 original_manifest=str(old/'manifest.json'))

    assets=[]
    for p in sorted((ROOT/'datasets/site_tools/annotations').glob('*.json')):
        entry=json.loads(p.read_text());image=cv2.imread(str(ROOT/entry['image']))
        objects=[(a['class_id'],a['xyxy']) for a in entry['objects']]
        split=entry['split'];group=entry['group']
        save('site_'+group,image,objects,split,'Gemini2 real tabletop',group,
             original_image=entry['image'],annotation_method=entry['annotation_method'])
        if split!='train':continue
        # Mask the actual photographed objects; background pixels are not labels.
        for i,(cls,box) in enumerate(objects):
            x1,y1,x2,y2=map(int,box);pad=7
            x1=max(0,x1-pad);y1=max(0,y1-pad);x2=min(image.shape[1],x2+pad);y2=min(image.shape[0],y2+pad)
            crop=image[y1:y2,x1:x2].copy();h,w=crop.shape[:2]
            mask=np.zeros((h,w),np.uint8)
            cv2.grabCut(crop,mask,(3,3,w-6,h-6),np.zeros((1,65)),np.zeros((1,65)),5,cv2.GC_INIT_WITH_RECT)
            mask=np.uint8((mask==cv2.GC_FGD)|(mask==cv2.GC_PR_FGD))*255
            mask=cv2.morphologyEx(mask,cv2.MORPH_OPEN,np.ones((2,2),np.uint8))
            for ax,ay,bx,by in entry['objects'][i].get('mask_include_regions',[]):
                # Per-image manual corrections retain the photographed pixels.
                cv2.rectangle(mask,(ax-x1,ay-y1),(bx-x1,by-y1),255,-1)
            if np.count_nonzero(mask)<25:raise ValueError('Unusable foreground mask')
            # A clipped tweezer tip is a real full-frame label, but should not
            # become an apparently complete floating tool in composites.
            if not entry['objects'][i].get('truncated'):
                assets.append((cls,crop,mask,group,i))
            review=crop.copy();review[mask==0]=(230,230,230)
            cv2.imwrite(str(out/f'cutout_review_{i}.png'),review)
        # Whole-image derivatives include real clutter and edges; not holdout data.
        for i in range(32):
            h,w=image.shape[:2];angle=float(rng.uniform(-180,180));scale=float(rng.uniform(.75,1.05))
            mat=cv2.getRotationMatrix2D((w/2,h/2),angle,scale)
            aug=cv2.warpAffine(image,mat,(w,h),borderMode=cv2.BORDER_CONSTANT,borderValue=(150,150,150))
            transformed=[]
            for cls,(x1,y1,x2,y2) in objects:
                points=np.array([[x1,y1,1],[x2,y1,1],[x2,y2,1],[x1,y2,1]])@mat.T
                lo=points.min(0);hi=points.max(0)
                # Keep every remaining visible annotated fragment.
                transformed.append((cls,[*lo,*hi]))
            alpha=float(rng.uniform(.8,1.2));beta=float(rng.uniform(-12,12))
            aug=np.clip(aug.astype(float)*alpha+beta,0,255).astype(np.uint8)
            save(f'site_affine_{i:03d}',aug,transformed,'train','real-photo affine augmentation',group,
                 synthetic=True,original_image=entry['image'],depth_available=False)
    for i in range(args.composites):
        base=int(rng.integers(95,220));canvas=np.full((480,640,3),base,np.uint8)
        noise=rng.normal(0,2,(480,640,1));canvas=np.clip(canvas.astype(float)+noise,0,255).astype(np.uint8)
        objects=[];placed=[];used=[]
        for asset_index in rng.choice(len(assets),size=int(rng.integers(3,len(assets)+1)),replace=False):
            cls,crop,mask,group,idx=assets[asset_index]
            scale=float(rng.uniform(.65,1.2));angle=float(rng.uniform(-180,180))
            h,w=crop.shape[:2];side=int(np.ceil(np.hypot(h,w)*scale))+8
            mat=cv2.getRotationMatrix2D((w/2,h/2),angle,scale)
            mat[:,2]+=np.array([side/2-w/2,side/2-h/2])
            patch=cv2.warpAffine(crop,mat,(side,side));m=cv2.warpAffine(mask,mat,(side,side),flags=cv2.INTER_NEAREST)
            yy,xx=np.where(m>0)
            if len(xx)<25:continue
            xa,xb,ya,yb=xx.min(),xx.max()+1,yy.min(),yy.max()+1
            patch=patch[ya:yb,xa:xb];m=m[ya:yb,xa:xb];hh,ww=m.shape
            if hh>=470 or ww>=630:continue
            for attempt in range(40):
                x=int(rng.integers(5,635-ww));y=int(rng.integers(5,475-hh));b=[x,y,x+ww,y+hh]
                if all(min(b[2],q[2])<=max(b[0],q[0]) or min(b[3],q[3])<=max(b[1],q[1]) for q in placed):break
            else:continue
            foreground=m>0
            canvas[y:y+hh,x:x+ww][foreground]=patch[foreground]
            objects.append((cls,b));placed.append(b);used.append(idx)
        alpha=float(rng.uniform(.75,1.25));canvas=np.clip(canvas.astype(float)*alpha,0,255).astype(np.uint8)
        save(f'composite_{i:04d}',canvas,objects,'train','photographic cutout composite',assets[0][3],
             synthetic=True,asset_indices=used,depth_available=False)
    # No parent group is permitted in multiple splits.
    groups={}
    for row in rows:
        key=(row['source'] if row['source']=='COCO 2017' else '',row['group'])
        if key in groups and groups[key]!=row['split']:raise ValueError('Cross-split group leakage')
        groups[key]=row['split']
    manifest={'names':NAMES,'seed':73,'tool_safety_revision':REV,
              'tool_safety_parquet_sha256':sha(args.parquet.read_bytes()),
              'task_taxonomy':'scissors includes blue flush cutter and public Cutting pliers; other pliers remain pliers',
              'validation_limit':'Only one same-camera/same-tools real tabletop validation arrangement; no upright-box acceptance and no independent new-site test. Synthetic images are training-only.',
              'licenses':{'tool-safety-dataset':'MIT declared by uploader; card archived; original image provenance not independently verified',
                          'COCO':'See original public_tools manifest and per-image license IDs',
                          'site':'User-provided local camera images, not uploaded'},
              'image_counts':dict(Counter(r['split'] for r in rows)),
              'objects_by_split_class':{f'{s}/{c}':n for (s,c),n in counts.items()},'images':rows}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2))
    (out/'data.yaml').write_text(yaml.safe_dump({'path':str(out.resolve()),'train':'images/train','val':'images/val','test':'images/test','names':NAMES}))
    print(json.dumps({k:manifest[k] for k in ['image_counts','objects_by_split_class','validation_limit']},indent=2))

if __name__=='__main__':main()
