#!/usr/bin/env python3
"""Frozen-threshold, class-aware IoU evaluation on reviewed site RGB only.
No camera, ROS, tracking, depth coordinate or motor side effects.
"""
import argparse,json,hashlib,time
from pathlib import Path
import numpy as np,torch
from ultralytics import YOLO
ROOT=Path(__file__).resolve().parents[1]
def iou(a,b):
 x1,y1=np.maximum(a[:2],b[:2]);x2,y2=np.minimum(a[2:],b[2:]);it=max(0,x2-x1)*max(0,y2-y1)
 return it/max((a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-it,1e-9)
def metrics(t):
 tp,fp,fn=map(int,t);pr=tp/(tp+fp) if tp+fp else None;re=tp/(tp+fn) if tp+fn else None
 return {'tp':tp,'fp':fp,'fn':fn,'precision':pr,'recall':re,'f1':2*tp/(2*tp+fp+fn) if 2*tp+fp+fn else None}
def main():
 p=argparse.ArgumentParser();p.add_argument('--model',type=Path,required=True);p.add_argument('--annotations',type=Path,default=ROOT/'datasets/site_tools/annotations_web_v4/holdout.json');p.add_argument('--split',default='test');p.add_argument('--output',type=Path,required=True);p.add_argument('--device',default='0');p.add_argument('--conf',type=float,default=.35);p.add_argument('--proposals',type=Path);a=p.parse_args()
 torch.set_num_threads(4);rows=[r for r in json.loads(a.annotations.read_text()) if r['split']==a.split];assert rows
 if a.proposals:pred=json.loads(a.proposals.read_text());elapsed=None
 else:
  model=YOLO(str(a.model));pred={};start=time.monotonic()
  for r in model.predict([str(ROOT/x['image']) for x in rows],stream=True,device=a.device,imgsz=640,conf=a.conf,iou=.45,batch=8,verbose=False):
   pred[str(Path(r.path).relative_to(ROOT))]=[{'class_id':int(c),'confidence':float(s),'xyxy':b.tolist()} for b,c,s in zip(r.boxes.xyxy.cpu(),r.boxes.cls.cpu(),r.boxes.conf.cpu())]
  elapsed=time.monotonic()-start
 counts=np.zeros((4,3),int);details=[];perfect=0
 for row in rows:
  gt=row['objects'];ps=sorted([b for b in pred[row['image']] if b['confidence']>=a.conf],key=lambda b:-b['confidence']);used=set();matches=[];fps=[]
  for j,b in enumerate(ps):
   candidates=[(iou(b['xyxy'],g['xyxy']),k) for k,g in enumerate(gt) if k not in used and g['class_id']==b['class_id']]
   best,k=max(candidates,default=(0,-1))
   if best>=.5:used.add(k);counts[b['class_id'],0]+=1;matches.append({'prediction':j,'truth':k,'iou':float(best)})
   else:counts[b['class_id'],1]+=1;fps.append(j)
  missing=[k for k in range(len(gt)) if k not in used]
  for k in missing:counts[gt[k]['class_id'],2]+=1
  perfect+=not missing and not fps
  details.append({'image':row['image'],'sample_id':row['sample_id'],'matches':matches,'false_positive_indices':fps,'missed_truth_indices':missing,'predictions':ps,'truth':gt})
 report={'model':str(a.model.resolve()),'model_sha256':hashlib.sha256(a.model.read_bytes()).hexdigest(),'annotation_sha256':hashlib.sha256(a.annotations.read_bytes()).hexdigest(),'split':a.split,'images':len(rows),'objects':sum(len(r['objects']) for r in rows),'confidence':a.conf,'nms_iou':.45,'matching_iou':.5,'overall':metrics(counts.sum(0)),'per_class':{n:metrics(counts[i]) for i,n in enumerate(['screwdriver','pliers','scissors','tweezers'])},'perfect_frames':perfect,'elapsed_s':elapsed,'performance_scope':'Offline batch inference including image decode/loading. Not live RGB-D/hand/tracking/telemetry pipeline FPS.','details':details}
 a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(report,indent=2));print(json.dumps({k:v for k,v in report.items() if k!='details'},indent=2))
if __name__=='__main__':main()
