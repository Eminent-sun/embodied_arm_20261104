#!/usr/bin/env python3
"""Train only when real, split annotations exist. Run with .venv-vision Python."""
import argparse
from pathlib import Path
import yaml
import json
import torch
import numpy as np
from ultralytics import YOLO

ROOT=Path(__file__).resolve().parents[1]

def json_default(value):
    if isinstance(value,np.generic):return value.item()
    if isinstance(value,np.ndarray):return value.tolist()
    raise TypeError(f'Unsupported report value: {type(value).__name__}')
parser=argparse.ArgumentParser()
parser.add_argument('--epochs',type=int,default=100)
parser.add_argument('--device',default='auto')
parser.add_argument('--data',type=Path,default=ROOT/'config/tools_dataset.yaml')
parser.add_argument('--batch',type=int,default=8)
parser.add_argument('--imgsz',type=int,default=640)
parser.add_argument('--workers',type=int,default=4)
parser.add_argument('--name',default='tools_yolo11n')
parser.add_argument('--patience',type=int,default=15)
parser.add_argument('--model',type=Path,default=ROOT/'models/yolo11n.pt')
parser.add_argument('--degrees',type=float,default=0.,help='Training-only rotation augmentation in degrees')
parser.add_argument('--amp',action='store_true',help='Use automatic mixed precision after Ultralytics hardware checks')
parser.add_argument('--lr0',type=float,default=.01)
parser.add_argument('--optimizer',default='auto',choices=['auto','SGD','AdamW'])
parser.add_argument('--mosaic',type=float,default=1.)
args=parser.parse_args()
data=yaml.safe_load(args.data.read_text())
if isinstance(data['names'],dict):data['names']={int(k):v for k,v in data['names'].items()}
dataset=Path(data.get('path',ROOT/'datasets/tools'))
if not dataset.is_absolute():dataset=(args.data.parent/dataset).resolve()
classes=len(data['names'])
for split in ['train','val']:
    images=list((dataset/data[split]).glob('*.jpg'))+list((dataset/data[split]).glob('*.png'))
    if not images:parser.error(f'No labelled {split} images; collect and annotate first')
    objects=0
    class_counts=[0]*classes
    for image in images:
        label=dataset/'labels'/split/(image.stem+'.txt')
        if not label.is_file():parser.error(f'Missing label: {label}')
        for line in label.read_text().splitlines():
            fields=line.split()
            if len(fields)!=5:parser.error(f'Invalid detection annotation: {label}')
            cls=int(fields[0]);values=list(map(float,fields[1:]))
            if cls not in range(classes) or not all(0<=v<=1 for v in values) or values[2]<=0 or values[3]<=0:
                parser.error(f'Invalid class/box: {label}')
            objects+=1
            class_counts[cls]+=1
    if not objects:parser.error(f'No objects labelled in {split}')
    if any(count==0 for count in class_counts):
        missing=[data['names'][i] for i,count in enumerate(class_counts) if count==0]
        parser.error(f'No {split} labels for configured classes {missing}; remove untrained classes (such as PCB) or collect labels')
data['path']=str(dataset)
generated=ROOT/'runtime/tools_dataset.yaml';generated.write_text(yaml.safe_dump(data))
device=('0' if torch.cuda.is_available() else 'cpu') if args.device=='auto' else args.device
torch.set_num_threads(4)
model=YOLO(str(args.model))
model.train(data=str(generated),epochs=args.epochs,imgsz=args.imgsz,batch=args.batch,workers=args.workers,
    device=device,project=str(ROOT/'runtime/training'),name=args.name,
    seed=73,deterministic=True,patience=args.patience,cache=False,amp=args.amp,
    close_mosaic=5,plots=True,degrees=args.degrees,lr0=args.lr0,optimizer=args.optimizer,mosaic=args.mosaic)
best=model.trainer.best
report={'best':str(best),'torch':torch.__version__,'hip':torch.version.hip,'device':device,
        'data':str(args.data.resolve()),'names':data['names'],'epochs_requested':args.epochs,
        'initial_model':str(args.model.resolve()),'degrees':args.degrees,
        'lr0':args.lr0,'optimizer':args.optimizer,'mosaic':args.mosaic}
if data.get('test'):
    metrics=YOLO(str(best)).val(data=str(generated),split='test',imgsz=args.imgsz,
                               batch=args.batch,device=device,workers=args.workers,
                               project=str(ROOT/'runtime/training'),name=args.name+'_test')
    report['test_metrics']=metrics.results_dict
    present={int(i) for i in metrics.box.ap_class_index}
    report['test_per_class_map50_95']=[float(v) if i in present else None for i,v in enumerate(metrics.box.maps)]
    report['test_classes_without_ground_truth']=[data['names'][i] for i in range(classes) if i not in present]
    report['test_per_class']=metrics.summary()
(Path(best).parents[1]/'evaluation.json').write_text(json.dumps(report,indent=2,default=json_default))
print(json.dumps(report,indent=2,default=json_default))
