#!/usr/bin/env python3
"""Build a reproducible 3-class YOLO subset from ABC Hand_Tools + COCO scissors.

Split ABC by capture session, not neighboring video frames. Keep COCO official
train/val separation; partition official validation into validation and test.
Downloads are cached, verified as images, and recorded with source hashes.
"""
import argparse
from collections import Counter, defaultdict
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import json
from pathlib import Path
import time
import zipfile

import cv2
import numpy as np
import requests
import yaml

ROOT=Path(__file__).resolve().parents[1]
REPO='ABC-iRobotics/Hand_Tools'


def download(url,path):
    if path.exists() and path.stat().st_size:
        return path
    path.parent.mkdir(parents=True,exist_ok=True)
    for attempt in range(4):
        try:
            with requests.get(url,timeout=(15,120),stream=True) as response:
                response.raise_for_status()
                temp=path.with_suffix(path.suffix+'.part')
                with temp.open('wb') as file:
                    for chunk in response.iter_content(1<<20):file.write(chunk)
                temp.replace(path)
            return path
        except requests.RequestException:
            if attempt==3:raise
            time.sleep(attempt+1)


def box_label(cls,box,width,height):
    x,y,w,h=box
    x1,y1=max(0,x),max(0,y);x2,y2=min(width,x+w),min(height,y+h)
    if x2-x1<3 or y2-y1<3:return None
    return f'{cls} {(x1+x2)/2/width:.8f} {(y1+y2)/2/height:.8f} {(x2-x1)/width:.8f} {(y2-y1)/height:.8f}'


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output',type=Path,default=ROOT/'datasets/public_tools')
    parser.add_argument('--per-scene',type=int,default=50)
    parser.add_argument('--scissors-train',type=int,default=500)
    parser.add_argument('--workers',type=int,default=8)
    parser.add_argument('--abc-revision',default='160fddf59b606988c4ba571b2864d7189559c740')
    args=parser.parse_args();cache=ROOT/'datasets/downloads';output=args.output
    if (output/'manifest.json').exists():parser.error('Output already finalized; use a new output to rebuild')
    for split in ['train','val','test']:
        for kind in ['images','labels']:(output/kind/split).mkdir(parents=True,exist_ok=True)
    meta_path=cache/f'hand_tools_repository_{args.abc_revision}.json'
    download(f'https://hf-mirror.com/api/datasets/{REPO}/revision/{args.abc_revision}',meta_path)
    metadata=json.loads(meta_path.read_text());revision=metadata['sha']
    prefix=f'https://hf-mirror.com/datasets/{REPO}/resolve/{revision}/'
    download(prefix+'README.md',cache/'hand_tools_README.md')
    tasks=[]
    def scene(index):
        name=f'{index:04d}'
        path=download(prefix+name+'/sam6d_scene/annotations.json',cache/f'handtools_{name}.json')
        data=json.loads(path.read_text());frames=data['frames']
        selected=np.linspace(0,len(frames)-1,min(args.per_scene,len(frames)),dtype=int)
        split='train' if index<6 else ('val' if index<8 else 'test')
        result=[]
        for i in selected:
            frame=frames[i];labels=[]
            for ann in frame['annotations']:
                cls={'Screwdriver':0,'Pliers':1}.get(ann['object_name'])
                if cls is None or ann.get('visible_area_px',0)<30:continue
                line=box_label(cls,ann['bbox_xywh'],data['image_width'],data['image_height'])
                if line:labels.append(line)
            filename=Path(frame['image_path']).name
            result.append({'id':f'abc_{name}_{Path(filename).stem}','split':split,'source':'ABC Hand_Tools',
                'group':name,'url':prefix+name+'/images/'+filename,'labels':labels,
                'size':[data['image_width'],data['image_height']]})
        print(f'ABC session {name}: {len(result)} frames -> {split}',flush=True)
        return result
    with ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(scene,range(10)):tasks.extend(result)
    coco_revision='a81d5ad6b31be5893819cd3a8175bca2929286ff'
    for source_split in ['train2017','val2017']:
        annotation=download(f'https://hf-mirror.com/datasets/sashankSaya/coco2017/resolve/{coco_revision}/annotations/instances_{source_split}.json',cache/f'instances_{source_split}.json')
        data=json.loads(annotation.read_text())
        scissors=next(c['id'] for c in data['categories'] if c['name']=='scissors')
        boxes=defaultdict(list);crowd=set()
        for ann in data['annotations']:
            if ann['category_id']==scissors:
                if ann.get('iscrowd'):crowd.add(ann['image_id'])
                else:boxes[ann['image_id']].append(ann['bbox'])
        eligible=[im for im in data['images'] if im['id'] in boxes and im['id'] not in crowd]
        eligible.sort(key=lambda im:hashlib.sha256(str(im['id']).encode()).hexdigest())
        if source_split=='train2017':eligible=eligible[:args.scissors_train]
        for i,im in enumerate(eligible):
            split='train' if source_split=='train2017' else ('val' if i%2==0 else 'test')
            labels=[box_label(2,b,im['width'],im['height']) for b in boxes[im['id']]]
            tasks.append({'id':f'coco_{im["id"]:012d}','split':split,'source':'COCO 2017',
                'group':str(im['id']),'url':f'https://s3.amazonaws.com/images.cocodataset.org/{source_split}/{im["file_name"]}',
                'labels':[line for line in labels if line],'size':[im['width'],im['height']],
                'license_id':im['license'],'flickr_url':im.get('flickr_url')})
        (cache/f'coco_{source_split}_licenses.json').write_text(json.dumps(data['licenses'],indent=2))
    for split in ['train','val','test']:
        expected={t['id'] for t in tasks if t['split']==split}
        existing={p.stem for kind in ['images','labels'] for p in (output/kind/split).glob('*') if p.is_file()}
        if existing-expected:
            raise ValueError('Output contains files from a different build; use a fresh --output')
    def process(task):
        raw=download(task['url'],cache/'tool_images'/(task['id']+'.image'))
        image=cv2.imread(str(raw))
        if image is None or list(image.shape[1::-1])!=task['size']:raise ValueError(f'Corrupt/dimension mismatch: {raw}')
        task['sha256']=hashlib.sha256(raw.read_bytes()).hexdigest()
        task['pixel_sha256']=hashlib.sha256(image.tobytes()).hexdigest()
        # Resize only; normalized boxes remain valid. Training retains aspect ratio.
        if max(image.shape[:2])>960:
            scale=960/max(image.shape[:2]);image=cv2.resize(image,None,fx=scale,fy=scale,interpolation=cv2.INTER_AREA)
        target=output/'images'/task['split']/(task['id']+'.jpg')
        if not cv2.imwrite(str(target),image,[cv2.IMWRITE_JPEG_QUALITY,95]):raise RuntimeError('Image write failed')
        (output/'labels'/task['split']/(task['id']+'.txt')).write_text('\n'.join(task['labels'])+'\n')
        return task
    entries=[];failures=[]
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        futures={pool.submit(process,t):t for t in tasks}
        for future in as_completed(futures):
            try:entries.append(future.result())
            except Exception as exc:failures.append({'id':futures[future]['id'],'error':str(exc)})
            if (len(entries)+len(failures))%50==0:print(f'Downloaded {len(entries)}/{len(tasks)}, failed {len(failures)}',flush=True)
    # Exact duplicate pixels may span dataset splits; keep evaluation copies only.
    seen={};kept=[];duplicates=[]
    for item in sorted(entries,key=lambda t:({'test':0,'val':1,'train':2}[t['split']],t['id'])):
        if item['pixel_sha256'] in seen:
            duplicates.append(item['id'])
            for kind,ext in [('images','.jpg'),('labels','.txt')]:
                (output/kind/item['split']/(item['id']+ext)).unlink()
        else:seen[item['pixel_sha256']]=item['id'];kept.append(item)
    counts={split:Counter() for split in ['train','val','test']}
    for item in kept:
        for line in item['labels']:counts[item['split']][int(line.split()[0])]+=1
    manifest={'names':{0:'screwdriver',1:'pliers',2:'scissors'},'abc_repo':REPO,'abc_revision':revision,
        'coco_annotation_mirror':'sashankSaya/coco2017','coco_annotation_revision':coco_revision,
        'coco_annotation_sha256':{split:hashlib.sha256((cache/f'instances_{split}.json').read_bytes()).hexdigest() for split in ['train2017','val2017']},
        'abc_license_as_published':metadata.get('cardData',{}).get('license'),
        'coco_license':'Annotations CC BY 4.0; images carry individual COCO license IDs, retained per image',
        'split_policy':'ABC captures 0000-0005 train, 0006-0007 val, 0008-0009 test; COCO official train, official val alternated between val and test',
        'limitations':'ABC automatic annotations and limited physical tool instances; this is a bootstrap dataset, not a tabletop deployment acceptance set. PCB not trained.',
        'counts_images':dict(Counter(t['split'] for t in kept)),'counts_boxes':counts,'failures':failures,'duplicates_removed':duplicates,'entries':kept}
    (output/'manifest.json').write_text(json.dumps(manifest,indent=2))
    if any(any(counts[s][c]<5 for c in range(3)) for s in counts):raise RuntimeError('Too few samples in at least one class/split; inspect manifest')
    (output/'data.yaml').write_text(yaml.safe_dump({'path':str(output.resolve()),'train':'images/train','val':'images/val','test':'images/test','names':manifest['names']}))
    print(json.dumps({k:manifest[k] for k in ['counts_images','counts_boxes','duplicates_removed']},indent=2),flush=True)


if __name__=='__main__':main()
