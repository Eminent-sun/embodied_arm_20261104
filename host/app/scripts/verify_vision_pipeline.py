#!/usr/bin/env python3
"""Offline RGB-D replay -> quality/stability -> TCP PS simulator. No camera or motors."""
import argparse
import json
from pathlib import Path
import sys
import threading
import time
import uuid

ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'vision'),str(ROOT/'communication')]
import cv2
import numpy as np
import torch
from ultralytics import YOLO
from robotarm_vision.quality import sample_depth,camera_signature,predict_region
from robotarm_vision.tracking import TemporalTracker
from robotarm_vision.geometry import Calibration
from robotarm_link.protocol import Client
from robotarm_link.vision_protocol import observation_payload
from robotarm_link.vision_receiver import serve


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--image',type=Path,required=True,help='Saved PNG with matching .depth.npy and .json')
    p.add_argument('--output',type=Path,default=ROOT/'runtime/eye_to_hand/pipeline-replay.json')
    p.add_argument('--roi',type=int,nargs=4);p.add_argument('--device',default='0')
    args=p.parse_args();im=cv2.imread(str(args.image))
    if im is None:p.error('Cannot read image')
    dep=np.load(args.image.with_suffix('.depth.npy'),allow_pickle=False)
    meta=json.loads(args.image.with_suffix('.json').read_text())
    if dep.shape!=im.shape[:2]:p.error('RGB-D shape mismatch')
    station=json.loads((ROOT/'config/vision_station.json').read_text())
    context={'intrinsic':meta['intrinsic'],'distortion':meta['distortion'],
             'setup_id':station['setup_id'],'camera_fixed':station['camera_fixed']}
    cal=Calibration(ROOT/'config/calibration/camera_to_base.json');serial=meta['camera_serial']
    base_valid=cal.compatible(serial,context)
    tracker=TemporalTracker();torch.set_num_threads(1);model=YOLO(str(ROOT/'models/tools_yolo11n.pt'))
    # Warm up before opening the short-timeout telemetry session.
    predict_region(model,im,args.roi,device=args.device,conf=.35,iou=.45,verbose=False)
    stopped=threading.Event();ready=threading.Event();ports=[]
    def bound(port):ports.append(port);ready.set()
    server=threading.Thread(target=serve,kwargs={'port':0,'ready':bound,'stop_event':stopped},daemon=True)
    server.start()
    if not ready.wait(3):raise RuntimeError('Simulator startup failed')
    client=Client(port=ports[0]);session=uuid.uuid4().hex
    try:
        hello=client.request('hello');acks=[]
        for i in range(3):
            prediction=predict_region(model,im,args.roi,device=args.device,conf=.35,iou=.45,verbose=False)
            detections=[]
            for box in prediction.boxes:
                b=box.xyxy[0].tolist();pixel=[(b[0]+b[2])/2,(b[1]+b[3])/2]
                q=sample_depth(dep,pixel,meta['intrinsic'],meta['distortion']);point=q['point_camera_m']
                detections.append({'class_name':model.names[int(box.cls[0])],'confidence':float(box.conf[0]),
                    'box_xyxy':b,'surface_point_camera_m':point,'surface_point_base_m':cal.point_in_base(point,serial,context),
                    'depth_quality':q,'point_kind':'bbox_center_surface_sample','grasp_pose':None})
            detections=tracker.update(detections,time.monotonic())
            for detection in detections:detection['surface_point_base_m']=cal.point_in_base(detection['surface_point_camera_m'],serial,context)
            # This is explicitly historical replay, not a fresh camera capture.
            obs={'schema_version':2,'source_kind':'offline_replay','source_session_id':session,'frame_id':i,
                 'captured_at_unix_s':time.time(),'camera_serial':serial,'mounting':'eye_to_hand','image_size':[im.shape[1],im.shape[0]],
                 'camera_frame':'camera_color_optical_frame','base_frame':'base_link','units':'m','station_setup_id':station['setup_id'],
                 'calibration_id':cal.data.get('calibration_id') if base_valid else None,
                 'camera_model_signature':camera_signature(meta['intrinsic'],meta['distortion']),
                 'base_calibration_valid':base_valid,'hand_present':False,'detections':detections}
            payload=observation_payload(obs);acks.append(client.request('observe',observation=payload))
        received=client.request('vision_status')
        assert received['fresh'] and received['observation']['source_kind']=='offline_replay'
        assert not received['execution_enabled']
        report={'offline_replay_only':True,'camera_opened':False,'source_image':str(args.image),
                'original_capture_time':meta['captured_at'],'roi':args.roi,'hello':hello,'acknowledgements':acks,
                'received':received,'stable_count':sum(d['stable'] for d in detections),
                'depth_valid_count':sum(d['depth_quality']['valid'] for d in detections),
                'note':'Three replays of one historical image test integration, not real video stability/accuracy; no hand model or physical control in this verification.'}
        args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(json.dumps(report,indent=2,allow_nan=False))
        print(json.dumps({'detections':len(detections),'stable':report['stable_count'],'depth_valid':report['depth_valid_count'],
                          'base_calibration_valid':base_valid,'acknowledged_frames':len(acks),'report':str(args.output)}))
    finally:client.close();stopped.set();server.join(3)

if __name__=='__main__':main()
