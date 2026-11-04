#!/usr/bin/env python3
"""Dedicated CPU fallback environment, same cached inputs/config as GPU test."""
import argparse,json,time
from pathlib import Path
import cv2,torch,psutil
from ultralytics import YOLO
from benchmark_aipc import BASE,APP,summary,csv_save,save
p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=BASE/'metrics/logs');p.add_argument('--duration',type=float,default=60);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=True)
rows=json.loads((APP/'datasets/site_tools/annotations_web_v4/holdout.json').read_text());images=[cv2.imread(str(APP/r['image'])) for r in rows]
cv2.setNumThreads(2);model=YOLO(str(APP/'models/tools_yolo11n.pt'));params=dict(imgsz=640,conf=.18,iou=.45,verbose=False,quantize=None,batch=1,device='cpu')
model.predict(images[0],**params);torch.set_num_threads(1)
for i in range(20):model.predict(images[i],**params)
log=[];start=time.perf_counter();i=0
while i<len(images) or time.perf_counter()-start<a.duration:
 t=time.perf_counter_ns();r=model.predict(images[i%len(images)],**params)[0];ms=(time.perf_counter_ns()-t)/1e6
 log.append({'sample':i,'image_index':i%len(images),'preprocess_ms':r.speed['preprocess'],'model_ms':r.speed['inference'],'postprocess_ms':r.speed['postprocess'],'predict_wall_ms':ms,'detections':len(r.boxes),'rss_bytes':psutil.Process().memory_info().rss});i+=1
wall=time.perf_counter()-start
result={'torch':torch.__version__,'backend':'dedicated CPU fallback','actual_torch_threads':torch.get_num_threads(),'samples':len(log),'duration_s':wall,'fps':len(log)/wall,'max_rss_bytes':max(x['rss_bytes'] for x in log),'parameter_dtype':str(next(model.model.parameters()).dtype),'timing_ms':{k:summary([r[k] for r in log]) for k in ['preprocess_ms','model_ms','postprocess_ms','predict_wall_ms']}}
csv_save(a.output/'cpu_fallback.csv',log);save(a.output/'cpu_fallback.json',result);print(json.dumps(result,indent=2))
