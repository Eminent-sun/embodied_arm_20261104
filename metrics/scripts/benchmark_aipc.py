#!/usr/bin/env python3
"""Offline AI PC measurements. Never opens a camera or sends to real hardware."""
import argparse,csv,hashlib,json,sys,time,threading,platform,os
os.environ.setdefault("YOLO_AUTOINSTALL","false")
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import numpy as np
BASE=Path(__file__).resolve().parents[2];APP=BASE/'host/app'
sys.path[:0]=[str(APP/'vision'),str(APP/'communication'),str(APP/'scripts')]

def summary(values):
 a=np.asarray(values,float)
 return {'n':len(a),'mean':float(a.mean()),'p50':float(np.percentile(a,50)),'p95':float(np.percentile(a,95)),
         'p99':float(np.percentile(a,99)),'max':float(a.max()),'min':float(a.min())}
def save(path,data):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data,ensure_ascii=False,indent=2,allow_nan=False,default=lambda x:x.item() if isinstance(x,np.generic) else x.tolist()))
def csv_save(path,rows):
 with path.open('w',newline='') as f:
  w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=BASE/'metrics/logs');p.add_argument('--duration',type=float,default=60);p.add_argument('--pipeline-duration',type=float,default=30);p.add_argument('--reuse-detector',action='store_true');a=p.parse_args();out=a.output;out.mkdir(parents=True,exist_ok=True)
 import cv2,torch,mediapipe as mp,psutil,yaml
 from ultralytics import YOLO
 from robotarm_vision.quality import sample_depth
 from robotarm_vision.tracking import TemporalTracker,HandTracker
 from robotarm_vision.overlay import draw_tools
 from evaluate_site_tools_v4 import iou,metrics
 torch.set_num_threads(1);cv2.setNumThreads(2)
 assert torch.cuda.is_available() and torch.version.hip,'ROCm GPU required for this declared benchmark'
 annotations=json.loads((APP/'datasets/site_tools/annotations_web_v4/holdout.json').read_text())
 images=[cv2.imread(str(APP/r['image'])) for r in annotations]
 assert all(x is not None and x.shape==(480,640,3) for x in images)
 params=dict(imgsz=640,conf=.18,iou=.45,verbose=False,quantize=None,batch=1)
 report={'date':time.strftime('%Y-%m-%dT%H:%M:%S%z'),'scope':'AI PC offline; no camera, real Ethernet peer, actuator or browser stream',
         'torch':torch.__version__,'hip':torch.version.hip,'gpu':torch.cuda.get_device_name(0),'gpu_arch':torch.cuda.get_device_properties(0).gcnArchName,
         'model_sha256':digest(APP/'models/tools_yolo11n.pt'),'precision':'FP32','input':[640,480],'imgsz':640,'batch':1,'torch_threads':1,'opencv_threads':2,'warmup':20,'detector':{}}
 for device in ([] if a.reuse_detector else ['cpu','0']):
  torch.set_num_threads(1)
  name='cpu' if device=='cpu' else 'gpu';model=YOLO(str(APP/'models/tools_yolo11n.pt'))
  model.predict(images[0],device=device,**params)
  torch.set_num_threads(1)
  for i in range(20):model.predict(images[i%len(images)],device=device,**params)
  if device!='cpu':torch.cuda.synchronize();torch.cuda.reset_peak_memory_stats()
  rows=[];predictions={};start=time.perf_counter();i=0
  cpu_start=time.process_time()
  while i<len(images) or time.perf_counter()-start<a.duration:
   idx=i%len(images);t=time.perf_counter_ns();r=model.predict(images[idx],device=device,**params)[0]
   if device!='cpu':torch.cuda.synchronize()
   elapsed=(time.perf_counter_ns()-t)/1e6
   rows.append({'sample':i,'image_index':idx,'preprocess_ms':r.speed['preprocess'],'model_ms':r.speed['inference'],
                'postprocess_ms':r.speed['postprocess'],'predict_wall_ms':elapsed,'detections':len(r.boxes),
                'rss_bytes':psutil.Process().memory_info().rss})
   if idx not in predictions:
    predictions[idx]=[{'class_id':int(c),'confidence':float(s),'xyxy':b.tolist()} for b,c,s in zip(r.boxes.xyxy.cpu(),r.boxes.cls.cpu(),r.boxes.conf.cpu())]
   i+=1
  wall=time.perf_counter()-start
  result={'actual_torch_threads':torch.get_num_threads(),'samples':len(rows),'duration_s':wall,'fps':len(rows)/wall,'process_cpu_seconds':time.process_time()-cpu_start,
          'parameter_dtype':str(next(model.model.parameters()).dtype),'max_rss_bytes':max(x['rss_bytes'] for x in rows),
          'timing_ms':{k:summary([x[k] for x in rows]) for k in ['preprocess_ms','model_ms','postprocess_ms','predict_wall_ms']}}
  if device!='cpu':result['torch_peak_allocated_bytes']=torch.cuda.max_memory_allocated();result['torch_peak_reserved_bytes']=torch.cuda.max_memory_reserved()
  report['detector'][name]=result;csv_save(out/f'detector_{name}.csv',rows);save(out/f'detector_{name}.json',result)
  print(name,result['samples'],result['fps'],flush=True)
  if device=='0':
   counts=np.zeros((4,3),int);details=[];perfect=0
   for idx,r in enumerate(annotations):
    gt=r['objects'];pred=sorted([b for b in predictions[idx] if b['confidence']>=.35],key=lambda b:-b['confidence']);used=set();tp=fp=0
    for b in pred:
     options=[(iou(b['xyxy'],g['xyxy']),j) for j,g in enumerate(gt) if j not in used and g['class_id']==b['class_id']]
     score,j=max(options,default=(0,-1))
     if score>=.5:used.add(j);counts[b['class_id'],0]+=1;tp+=1
     else:counts[b['class_id'],1]+=1;fp+=1
    for j,g in enumerate(gt):
     if j not in used:counts[g['class_id'],2]+=1
    fn=len(gt)-len(used);perfect+=not fp and not fn
    details.append({'image':r['image'],'tp':tp,'fp':fp,'fn':fn,'predictions':pred})
   fixed={'images':len(annotations),'objects':sum(len(x['objects']) for x in annotations),'confidence':.35,'nms_iou':.45,'match_iou':.5,
          'overall':metrics(counts.sum(0)),'perfect_frames':perfect,'per_class':{n:metrics(counts[j]) for j,n in enumerate(model.names.values())},'details':details}
   save(out/'fixed_threshold.json',fixed);report['fixed_threshold']={k:v for k,v in fixed.items() if k!='details'}
 if a.reuse_detector:
  report['detector']={k:json.loads((out/f'detector_{k}.json').read_text()) for k in ['cpu','gpu']}
  fixed=json.loads((out/'fixed_threshold.json').read_text());report['fixed_threshold']={k:v for k,v in fixed.items() if k!='details'}
  model=YOLO(str(APP/'models/tools_yolo11n.pt'))
 # Batch=1 AP evaluation: fixed whole-session holdout, never train on this dataset.
 cfg={'path':str(APP/'datasets/tools_site_v4_holdout'),'train':'images/test','val':'images/test','test':'images/test','names':model.names}
 (out/'holdout_eval.yaml').write_text(yaml.safe_dump(cfg))
 ap=model.val(data=str(out/'holdout_eval.yaml'),split='test',batch=1,imgsz=640,device=0,quantize=None,workers=0,
              conf=.001,iou=.7,plots=False,save_json=False,project=str(out),name='ap_validation',exist_ok=True,verbose=False)
 report['ap']={'images':124,'instances':393,'metrics':{k:float(v) for k,v in ap.results_dict.items()},'per_class':json.loads(json.dumps(ap.summary(),default=lambda x:x.item())),
               'note':'AP uses conf=.001 and NMS IoU=.7; fixed deployment threshold measured separately at .35/.45'}
 save(out/'ap_metrics.json',report['ap']);torch.set_num_threads(1)
 # Repeated real saved RGB-D scene. Synthetic replay timing, NOT new live capture.
 idx=max(range(len(annotations)),key=lambda i:len(annotations[i]['objects']));r=annotations[idx];image=images[idx]
 base=APP/Path(r['image']).parent.parent
 with np.load(base/'depth'/(r['sample_id']+'.npz')) as f:depth=f['depth_m'].copy()
 meta=json.loads((base/'metadata'/(r['sample_id']+'.json')).read_text());intr=meta['camera_intrinsics'];dist=meta['camera_distortion']
 options=mp.tasks.vision.HandLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(APP/'models/hand_landmarker.task')),
          running_mode=mp.tasks.vision.RunningMode.VIDEO,num_hands=2,min_hand_detection_confidence=.5,min_hand_presence_confidence=.5,min_tracking_confidence=.5)
 tracker=TemporalTracker();hand_tracker=HandTracker();rows=[];counter=0
 with mp.tasks.vision.HandLandmarker.create_from_options(options) as hands,ThreadPoolExecutor(max_workers=1) as pool:
  began=time.perf_counter();measure_start=None
  while counter<40 or measure_start is None or time.perf_counter()-measure_start<a.pipeline_duration:
   start=time.perf_counter_ns();hand_image=mp.Image(image_format=mp.ImageFormat.SRGB,data=np.ascontiguousarray(cv2.cvtColor(image,cv2.COLOR_BGR2RGB)))
   future=pool.submit(hands.detect_for_video,hand_image,(counter+1)*33)
   pred=model.predict(image,device=0,**params)[0];hr=future.result();torch.cuda.synchronize();models_ms=(time.perf_counter_ns()-start)/1e6
   detections=[]
   for b in pred.boxes:
    box=b.xyxy[0].tolist();pixel=[(box[0]+box[2])/2,(box[1]+box[3])/2];q=sample_depth(depth,pixel,intr,dist)
    detections.append({'class_name':model.names[int(b.cls[0])],'confidence':float(b.conf[0]),'box_xyxy':box,
      'surface_point_camera_m':q['point_camera_m'],'surface_point_base_m':None,'depth_quality':q})
   detections=tracker.update(detections,counter/30);hand_list=[]
   for landmarks,handed in zip(hr.hand_landmarks,hr.handedness):
    h={'handedness':handed[0].category_name,'confidence':float(handed[0].score),'keypoints':[]}
    for j,lm in enumerate(landmarks):
     pixel=[lm.x*640,lm.y*480];q=sample_depth(depth,pixel,intr,dist)
     h['keypoints'].append({'id':j,'pixel':pixel,'camera_m':q['point_camera_m'],'base_m':None,'depth_quality':q})
    hand_list.append(h)
   hand_list,present,state=hand_tracker.update(hand_list,counter/30)
   canvas=image.copy();draw_tools(canvas,detections,intr,dist)
   serialized=json.dumps({'source_kind':'offline_replay','detections':detections,'hands':hand_list,'base_calibration_valid':False},allow_nan=False)
   cv2.imencode('.jpg',canvas,[cv2.IMWRITE_JPEG_QUALITY,85]);total=(time.perf_counter_ns()-start)/1e6
   if counter>=20:
    if measure_start is None:measure_start=time.perf_counter()
    rows.append({'frame':counter-20,'parallel_models_ms':models_ms,'perception_wall_ms':total,'tools':len(detections),'hands':len(hand_list),'json_bytes':len(serialized.encode())})
   counter+=1
  duration=time.perf_counter()-measure_start
  report['offline_rgbd']={'source':r['image'],'source_timestamp':meta['captured_at_unix_s'],'frames':len(rows),'duration_s':duration,
    'fps':len(rows)/duration,'timing_ms':summary([x['perception_wall_ms'] for x in rows]),'hands_max':max(x['hands'] for x in rows),
    'scope':'Decoded cached same RGB-D repeated: parallel YOLO+MediaPipe, depth, tracking, overlay, JSON/JPEG encoding; excludes camera/USB, files/NPZ, ROS, browser/network, valid base transform and actuator'}
  csv_save(out/'offline_rgbd.csv',rows)
  # Distinct CPU MediaPipe benchmark on fixed hand-containing RGB; no false metric depth added.
  ref=cv2.imread(str(BASE/'data/hand_reference.jpg'));ref=cv2.resize(ref,(640,480))
  mpref=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(ref,cv2.COLOR_BGR2RGB));hr_rows=[]
  for j in range(220):
   t=time.perf_counter_ns();res=hands.detect_for_video(mpref,(counter+j+1)*33);ms=(time.perf_counter_ns()-t)/1e6
   if j>=20:hr_rows.append({'sample':j-20,'hand_model_wall_ms':ms,'hands':len(res.hand_landmarks)})
  csv_save(out/'hand_model.csv',hr_rows);report['hand_model']={'samples':200,'timing_ms':summary([x['hand_model_wall_ms'] for x in hr_rows]),
    'hands_min':min(x['hands'] for x in hr_rows),'hands_max':max(x['hands'] for x in hr_rows),'scope':'CPU MediaPipe fixed RGB image; no landmark accuracy ground truth, depth or motion'}
 # Paired holdout depth integrity; real archived depth, not an accuracy calibration.
 rows=[]
 for r,image in zip(annotations,images):
  base=APP/Path(r['image']).parent.parent
  with np.load(base/'depth'/(r['sample_id']+'.npz')) as d:dep=d['depth_m']
  valid=np.isfinite(dep)&(dep>.15)&(dep<3)
  rows.append({'image':r['image'],'shape_match':dep.shape==image.shape[:2],'rgb_hash_match':digest(APP/r['image'])==r['image_sha256'],'valid_depth_ratio':float(valid.mean())})
 csv_save(out/'rgbd_integrity.csv',rows)
 report['depth_integrity']={'paired_frames':len(rows),'shape_pass':sum(x['shape_match'] for x in rows),'hash_pass':sum(x['rgb_hash_match'] for x in rows),
    'valid_depth_ratio':summary([x['valid_depth_ratio'] for x in rows]),'scope':'Archived holdout RGB-D completeness; no distance ground-truth accuracy or new sensor frame-drop test'}
 save(out/'benchmark.json',report)
 print(json.dumps({k:v for k,v in report.items() if k!='detector'},ensure_ascii=False),flush=True)

if __name__=='__main__':main()
