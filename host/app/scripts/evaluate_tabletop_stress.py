#!/usr/bin/env python3
"""Paired imaging-perturbation regression on an existing validation photo.

Derivatives are evaluation diagnostics only, not new independent test images.
"""
import argparse
import json
from pathlib import Path
import sys
import cv2
import numpy as np
import torch
from ultralytics import YOLO
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from evaluate_site_tools import iou


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--models',type=Path,nargs='+',required=True)
    p.add_argument('--output',type=Path,default=ROOT/'runtime/temporal/stress');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
    entries=[json.loads(f.read_text()) for f in (ROOT/'datasets/site_tools/annotations').glob('*.json')]
    e=next(x for x in entries if x['split']=='val');im=cv2.imread(str(ROOT/e['image']));rng=np.random.default_rng(119)
    variants=[('original',im)]
    for gain in [.55,.75,1.2,1.4]:variants.append((f'gain_{gain}',np.clip(im.astype(float)*gain,0,255).astype(np.uint8)))
    for size,sigma in [(3,.8),(5,1.2)]:variants.append((f'blur_{size}',cv2.GaussianBlur(im,(size,size),sigma)))
    for quality in [30,55]:
        _,enc=cv2.imencode('.jpg',im,[cv2.IMWRITE_JPEG_QUALITY,quality]);variants.append((f'jpeg_{quality}',cv2.imdecode(enc,1)))
    variants.append(('sensor_noise_sigma5',np.clip(im.astype(float)+rng.normal(0,5,im.shape),0,255).astype(np.uint8)))
    torch.set_num_threads(2);reports=[]
    for path in a.models:
        model=YOLO(str(path));cases=[]
        for name,frame in variants:
            result=model.predict(frame,device='0',imgsz=640,conf=.35,iou=.45,verbose=False)[0]
            predictions=[(int(c),b.tolist(),float(s)) for b,c,s in zip(result.boxes.xyxy.cpu(),result.boxes.cls.cpu(),result.boxes.conf.cpu())]
            pairs=sorted([(iou(o['xyxy'],b),j,k) for j,o in enumerate(e['objects']) for k,(c,b,_) in enumerate(predictions) if c==o['class_id']],reverse=True)
            gt=set();pred=set();matches=[]
            for score,j,k in pairs:
                if score<.5:break
                if j not in gt and k not in pred:gt.add(j);pred.add(k);matches.append(score)
            cases.append({'variant':name,'tp':len(gt),'fp':len(predictions)-len(pred),'fn':len(e['objects'])-len(gt),'mean_matched_iou':float(np.mean(matches)) if matches else None})
        reports.append({'model':str(path),'cases':cases,'total_tp':sum(c['tp'] for c in cases),'total_fp':sum(c['fp'] for c in cases),'total_fn':sum(c['fn'] for c in cases),'mean_case_iou':float(np.mean([c['mean_matched_iou'] for c in cases if c['mean_matched_iou'] is not None]))})
    report={'source':e['image'],'confidence':.35,'nms_iou':.45,'match_iou':.5,'models':reports,'limit':'Ten correlated versions of one already-used validation arrangement. No new independent real data; cannot estimate deployment accuracy or grasp success.'}
    (a.output/'report.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
