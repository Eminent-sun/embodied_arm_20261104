#!/usr/bin/env python3
"""Fixed-image detector + hand benchmark; NOT camera/stream end-to-end FPS."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import json
from pathlib import Path
import time
import cv2
import mediapipe as mp
import numpy as np
import torch
from ultralytics import YOLO

ROOT=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--image',type=Path,default=ROOT/'runtime/hand_reference.jpg')
parser.add_argument('--model',type=Path,default=ROOT/'models/yolo11n.pt')
parser.add_argument('--compute',default='cpu')
parser.add_argument('--output',type=Path,required=True)
args=parser.parse_args()
torch.set_num_threads(1);cv2.setNumThreads(2)
image=cv2.imread(str(args.image))
if image is None:parser.error('Image cannot be opened')
image=cv2.resize(image,(640,480));hand_image=mp.Image(image_format=mp.ImageFormat.SRGB,data=cv2.cvtColor(image,cv2.COLOR_BGR2RGB))
options=mp.tasks.vision.HandLandmarkerOptions(base_options=mp.tasks.BaseOptions(model_asset_path=str(ROOT/'models/hand_landmarker.task')),
    running_mode=mp.tasks.vision.RunningMode.VIDEO,num_hands=2)
model=YOLO(str(args.model));model.predict(image,device=args.compute,verbose=False)
times=[];hand_counts=[]
with mp.tasks.vision.HandLandmarker.create_from_options(options) as hands, ThreadPoolExecutor(max_workers=1) as pool:
    for i in range(120):
        start=time.perf_counter();future=pool.submit(hands.detect_for_video,hand_image,(i+1)*33)
        result=model.predict(image,device=args.compute,verbose=False)[0]
        hand_result=future.result()
        if args.compute!='cpu':torch.cuda.synchronize()
        elapsed=(time.perf_counter()-start)*1000
        if i>=20:times.append(elapsed);hand_counts.append(len(hand_result.hand_landmarks))
report={'compute':args.compute,'torch':torch.__version__,'image':str(args.image),'image_size':[640,480],
        'measurement':'Concurrent detector and hand model only, fixed image, excludes camera/depth/UI',
        'samples':len(times),'median_ms':float(np.median(times)),'p95_ms':float(np.percentile(times,95)),
        'hands_per_frame_min':min(hand_counts),'hands_per_frame_max':max(hand_counts)}
args.output.write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
