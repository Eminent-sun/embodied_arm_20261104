#!/usr/bin/env python3
"""Build the versioned site experiment from visually reviewed annotations.
Run in .venv-vision; originals/old dataset never modified. Full sessions stay together.
"""
import json,hashlib,shutil,argparse,collections
from pathlib import Path
import cv2,numpy as np,yaml
ROOT=Path(__file__).resolve().parents[1]
p=argparse.ArgumentParser();p.add_argument('--annotations',type=Path,default=ROOT/'datasets/site_tools/annotations_web_v4/annotations.json');p.add_argument('--output',type=Path,default=ROOT/'datasets/tools_site_v4');a=p.parse_args()
assert not a.output.exists(),'Refuse to overwrite an experiment dataset'
out=a.output;out.mkdir(parents=True)
base=ROOT/'datasets/tools_v2';base_manifest=json.loads((base/'manifest.json').read_text());ann=json.loads(a.annotations.read_text());names={0:'screwdriver',1:'pliers',2:'scissors',3:'tweezers'}
rows=[];rng=np.random.default_rng(73)
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write_sample(name,split,image,objects,provenance):
 ip=out/'images'/split/(name+'.png');lp=out/'labels'/split/(name+'.txt');ip.parent.mkdir(parents=True,exist_ok=True);lp.parent.mkdir(parents=True,exist_ok=True)
 cv2.imwrite(str(ip),image);h,w=image.shape[:2];lines=[]
 for cls,b in objects:
  x1,y1,x2,y2=b;assert 0<=x1<x2<=w and 0<=y1<y2<=h
  lines.append(f'{cls} {(x1+x2)/2/w:.8f} {(y1+y2)/2/h:.8f} {(x2-x1)/w:.8f} {(y2-y1)/h:.8f}')
 lp.write_text('\n'.join(lines)+'\n' if lines else '')
 rows.append({'image':str(ip.relative_to(out)),'split':split,'objects':objects,'sha256':sha(ip),**provenance})
# Old public/real train and validation only; old public test is evaluated separately.
for r in base_manifest['images']:
 if r['split'] not in ('train','val'):continue
 src=base/r['image'];dst=out/r['image'];dst.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,dst)
 sl=base/'labels'/r['split']/(src.stem+'.txt');dl=out/'labels'/r['split']/sl.name;dl.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(sl,dl)
 rows.append({**r,'inherited_manifest':str((base/'manifest.json').relative_to(ROOT))})
for r in ann:
 assert r['review_status']=='visually_reviewed',r['image']
 split=r['split'];src=ROOT/r['image'];im=cv2.imread(str(src));objects=[[x['class_id'],x['xyxy']] for x in r['objects']];stem=r['session_id'][-8:]+'_'+r['sample_id']
 prov={'source':'local_gemini_rgbd','source_image':r['image'],'source_sha256':sha(src),'group':r['session_id'],'annotation_method':r['annotation_method'],'synthetic':False}
 write_sample('site_'+stem,split,im,objects,prov)
 if split!='train':continue
 # Exact 90-degree rotations have exact box transforms; photometric changes don't invent objects/depth.
 cur=im;cur_boxes=objects
 for k in range(1,4):
  h,w=cur.shape[:2];cur=cv2.rotate(cur,cv2.ROTATE_90_CLOCKWISE)
  cur_boxes=[[c,[h-b[3],b[0],h-b[1],b[2]]] for c,b in cur_boxes]
  photo=np.clip(cur.astype(np.float32)*[.82,1.12,.96][k-1]+[3,-4,8][k-1],0,255).astype(np.uint8)
  write_sample(f'aug_{stem}_r{k*90}',split,photo,cur_boxes,{**prov,'synthetic':True,'augmentation':f'clockwise {k*90} degrees + brightness; no synthetic depth'})
# Empty patches only from reviewed TRAIN images; no box intersects even with 20px margin.
train=[r for r in ann if r['split']=='train'];neg=0
for r in train:
 if neg>=32:break
 im=cv2.imread(str(ROOT/r['image']));h,w=im.shape[:2]
 for attempt in range(40):
  cw,ch=256,192;x=int(rng.integers(0,w-cw+1));y=int(rng.integers(0,h-ch+1))
  if any(b['xyxy'][0]-20<x+cw and b['xyxy'][2]+20>x and b['xyxy'][1]-20<y+ch and b['xyxy'][3]+20>y for b in r['objects']):continue
  crop=cv2.resize(im[y:y+ch,x:x+cw],(640,480));write_sample(f'negative_{neg:03}','train',crop,[],{'source':'local_gemini_rgbd','source_image':r['image'],'source_sha256':sha(ROOT/r['image']),'group':r['session_id'],'synthetic':True,'augmentation':'empty background crop resized','crop_xywh':[x,y,cw,ch]});neg+=1;break
manifest={'schema_version':1,'names':names,'seed':73,'source_annotations':str(a.annotations.relative_to(ROOT)),'annotation_sha256':sha(a.annotations),'inherited_dataset_manifest':str((base/'manifest.json').relative_to(ROOT)),'licenses':base_manifest['licenses'],'local_license':'User-provided local captures; retained locally, not redistributed','session_split':{r['session_id']:r['split'] for r in ann},'split_rule':'Complete recording session and every derivative remain in one split. Same occasion/tools/background; not independent-day acceptance.','images':rows,'image_counts':dict(collections.Counter(r['split'] for r in rows))}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False))
data={'path':str(out.resolve()),'train':'images/train','val':'images/val','names':names}
# Holdout is deliberately absent from training config: evaluate once after best checkpoint selection.
(out/'data.yaml').write_text(yaml.safe_dump(data));print(manifest['image_counts'], 'empty backgrounds',neg)
# Check file AND decoded pixel equality across experiment splits.
seen={};duplicates=[]
for r in rows:
 px=cv2.imread(str(out/r['image']));digest=hashlib.sha256(px.tobytes()+str(px.shape).encode()).hexdigest()
 if digest in seen and seen[digest]['split']!=r['split']:duplicates.append([seen[digest]['image'],r['image']])
 seen[digest]=r
(out/'split_audit.json').write_text(json.dumps({'cross_split_exact_pixel_duplicates':duplicates,'session_split':manifest['session_split'],'note':'Shared physical tools/background across sessions; correlated views remain. Exact check is not proof of independence.'},indent=2))
assert not duplicates,duplicates
