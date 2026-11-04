#!/usr/bin/env python3
"""Compare detectors on manually labelled site validation photographs, not grasp poses."""
import argparse
import json
from pathlib import Path
import cv2
import sys
from ultralytics import YOLO

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vision'))
from robotarm_vision.quality import predict_region
NAMES={0:'screwdriver',1:'pliers',2:'scissors',3:'tweezers'}


def iou(a,b):
    x=max(0,min(a[2],b[2])-max(a[0],b[0]))
    y=max(0,min(a[3],b[3])-max(a[1],b[1]))
    inter=x*y
    return inter/max(1e-9,(a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-inter)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--models',type=Path,nargs='+',required=True)
    parser.add_argument('--output',type=Path,default=ROOT/'runtime/retraining/site-evaluation')
    parser.add_argument('--confidence',type=float,default=.35)
    parser.add_argument('--iou',type=float,default=.45,help='Same-class NMS overlap threshold')
    parser.add_argument('--device',default='0')
    parser.add_argument('--roi',type=int,nargs=4,help='Optional full-image pixel ROI x1 y1 x2 y2')
    args=parser.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    entries=[json.loads(p.read_text()) for p in sorted((ROOT/'datasets/site_tools/annotations').glob('*.json'))]
    entries=[e for e in entries if e['split']=='val']
    report={'confidence':args.confidence,'iou_threshold':.5,'nms_iou':args.iou,'roi':args.roi,
            'limitation':'Same seven physical tools, one validation arrangement also used for checkpoint selection. Not an independent acceptance test or guarantee.',
            'models':[]}
    for model_index,path in enumerate(args.models):
        model=YOLO(str(path));cases=[]
        for e in entries:
            image=cv2.imread(str(ROOT/e['image']))
            if image is None:raise ValueError('Cannot read site validation image')
            result=predict_region(model,image,args.roi,device=args.device,conf=args.confidence,iou=args.iou,verbose=False)
            predictions=[{'class_id':int(c),'confidence':float(s),'xyxy':b.tolist()} for b,c,s in zip(result.boxes.xyxy.cpu(),result.boxes.cls.cpu(),result.boxes.conf.cpu())]
            matched=set();details=[]
            for obj in e['objects']:
                candidates=[(iou(obj['xyxy'],p['xyxy']),i) for i,p in enumerate(predictions) if p['class_id']==obj['class_id'] and i not in matched]
                score,index=max(candidates,default=(0,None))
                ok=score>=.5
                if ok:matched.add(index)
                details.append({**obj,'name':NAMES[obj['class_id']],'matched':ok,'matched_iou':score if ok else None,'confidence':predictions[index]['confidence'] if ok else None})
            tp=len(matched);fp=len(predictions)-tp;fn=len(e['objects'])-tp
            image_path=args.output/f'model_{model_index}_{e["group"]}.jpg'
            result.save(filename=str(image_path))
            cases.append({'image':e['image'],'group':e['group'],'objects':details,'predictions':predictions,'tp':tp,'fp':fp,'fn':fn,
                          'precision':tp/max(1,tp+fp),'recall':tp/max(1,tp+fn),'overlay':str(image_path)})
        report['models'].append({'weights':str(path.resolve()),'classes':model.names,'cases':cases})
    (args.output/'report.json').write_text(json.dumps(report,indent=2))
    print(json.dumps(report,indent=2))

if __name__=='__main__':main()
