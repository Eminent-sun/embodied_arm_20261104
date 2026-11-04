"""Local camera perception. Publishes observations, never motor commands."""
import argparse
import json
import os
from pathlib import Path
import time
import select
import signal
import subprocess
import uuid
from collections import deque
from concurrent.futures import ThreadPoolExecutor

import cv2
import mediapipe as mp
import numpy as np
from ultralytics import YOLO
import torch

from .camera import OrbbecCamera, UVCCamera, LatestCamera
from .geometry import Calibration, depth_point
from .quality import sample_depth, camera_signature, predict_region
from .tracking import TemporalTracker, HandTracker
from .overlay import draw_tools

ROOT = Path(__file__).resolve().parents[2]
EDGES = [(0,1),(1,2),(2,3),(3,4),(0,5),(5,6),(6,7),(7,8),(5,9),(9,10),(10,11),(11,12),(9,13),(13,14),(14,15),(15,16),(13,17),(0,17),(17,18),(18,19),(19,20)]


def atomic_image(path, image):
    ok, encoded = cv2.imencode('.jpg', image, [cv2.IMWRITE_JPEG_QUALITY, 82])
    if not ok:
        raise RuntimeError('JPEG encoding failed')
    temporary = path.with_suffix('.jpg.tmp')
    temporary.write_bytes(encoded.tobytes())
    os.replace(temporary,path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--camera', choices=['orbbec', 'uvc'], default='orbbec')
    parser.add_argument('--device', default='/dev/video4')
    default_model = ROOT/'models/tools_yolo11n.pt'
    if not default_model.is_file():default_model=ROOT/'models/yolo11n.pt'
    parser.add_argument('--model', type=Path, default=default_model)
    parser.add_argument('--hand-model', type=Path, default=ROOT/'models/hand_landmarker.task')
    parser.add_argument('--calibration', type=Path, default=ROOT/'config/calibration/camera_to_base.json')
    parser.add_argument('--station', type=Path, default=ROOT/'config/vision_station.json')
    parser.add_argument('--output', type=Path, default=ROOT/'runtime/vision')
    parser.add_argument('--frames', type=int, default=0, help='0 means continuous')
    parser.add_argument('--headless', action='store_true')
    parser.add_argument('--confidence', type=float, default=0.35)
    parser.add_argument('--iou', type=float, default=0.45, help='Same-class NMS overlap threshold')
    parser.add_argument('--compute', default='auto', help='auto, cpu, or 0 (AMD ROCm GPU)')
    parser.add_argument('--imgsz', type=int, default=640)
    parser.add_argument('--threads', type=int, default=1)
    parser.add_argument('--preview-fps', type=float, default=30)
    parser.add_argument('--log-hz', type=float, default=2)
    parser.add_argument('--record-all', action='store_true', help='Log every processed frame for benchmarks')
    parser.add_argument('--half', action='store_true', help='FP16 on GPU only; benchmark before selecting')
    parser.add_argument('--ros', action='store_true', help='Publish JSON on /perception/observations; source ROS first')
    parser.add_argument('--ps-host', help='Optional PS observation receiver host (separate process/channel, no motor commands)')
    parser.add_argument('--ps-port',type=int,default=7011)
    args = parser.parse_args()
    if args.preview_fps <= 0 or args.log_hz <= 0 or args.threads < 1:
        parser.error('FPS, logging rate and thread count must be positive')
    if not 0 < args.iou <= 1 or not 0 < args.confidence <= 1:
        parser.error('Confidence and NMS IoU must be in (0, 1]')
    torch.set_num_threads(args.threads)
    cv2.setNumThreads(2)
    compute = ('0' if torch.cuda.is_available() else 'cpu') if args.compute == 'auto' else args.compute
    if args.half and compute == 'cpu':
        parser.error('--half requires GPU')
    for model in [args.model, args.hand_model]:
        if not model.is_file():
            parser.error(f'Model missing: {model}; run scripts/download_vision_models.py')
    args.output.mkdir(parents=True, exist_ok=True)
    calibration = Calibration(args.calibration)
    station = json.loads(args.station.read_text())
    if station.get('mounting') != 'eye_to_hand':parser.error('Expected a fixed-camera eye_to_hand station')
    if station.get('image_roi_xyxy') is not None and station.get('camera_fixed') is not True:
        parser.error('Fix the camera before enabling a station ROI')
    tracker=TemporalTracker(min_hits=station['stability_min_hits'],start_confidence=args.confidence,**station.get('temporal_filter',{}))
    hand_tracker=HandTracker()
    source_session_id=uuid.uuid4().hex
    yolo = YOLO(str(args.model))
    yolo.predict(np.zeros((480,640,3),dtype=np.uint8), device=compute,
                 imgsz=args.imgsz, quantize=('fp16' if args.half else None), verbose=False)
    print(f'Compute={compute}, torch={torch.__version__}, HIP={torch.version.hip}',flush=True)
    supported = sorted(set(yolo.names.values()) & {'screwdriver', 'pliers', 'scissors', 'tweezers', 'pcb'})
    options = mp.tasks.vision.HandLandmarkerOptions(
        base_options=mp.tasks.BaseOptions(model_asset_path=str(args.hand_model)),
        running_mode=mp.tasks.vision.RunningMode.VIDEO, num_hands=2,
        min_hand_detection_confidence=0.5, min_hand_presence_confidence=0.5,
        min_tracking_confidence=0.5)
    hands = mp.tasks.vision.HandLandmarker.create_from_options(options)
    hand_worker = ThreadPoolExecutor(max_workers=1, thread_name_prefix='hand-landmarks')
    camera = None
    ros_process = None
    link_process = None
    count, last_stamp = 0, 0
    started = time.monotonic()
    completed = deque(maxlen=60)
    last_preview = last_depth = last_log = 0.0
    preview_credit = 1.0
    try:
        if args.ros:
            # This host aborts when ROCm + FastDDS share an interpreter. Keep ROS
            # in system Python and transfer only atomic, fresh JSON snapshots.
            ros_process=subprocess.Popen(['/usr/bin/python3','-u','-m','robotarm_vision.ros_publisher',
                '--input',str(args.output/'latest.json'),'--not-before',str(time.time())],
                stdout=subprocess.PIPE,text=True)
            ready=select.select([ros_process.stdout],[],[],15)[0]
            if not ready or ros_process.stdout.readline().strip()!='ROS_PUBLISHER_READY':
                raise RuntimeError('ROS publisher failed to start; source scripts/env_jazzy.bash first')
        if args.ps_host:
            link_env=os.environ.copy()
            link_env['PYTHONPATH']=str(ROOT/'communication')+os.pathsep+link_env.get('PYTHONPATH','')
            link_process=subprocess.Popen(['/usr/bin/python3','-u','-m','robotarm_link.vision_bridge',
                '--host',args.ps_host,'--port',str(args.ps_port),'--input',str(args.output/'latest.json'),
                '--source-session-id',source_session_id],env=link_env)
        camera = LatestCamera(OrbbecCamera() if args.camera == 'orbbec' else UVCCamera(args.device))
        with (args.output/'observations.jsonl').open('a') as log:
            while args.frames == 0 or count < args.frames:
                frame = camera.read()
                image = frame.color
                h, w = image.shape[:2]
                if [w,h]!=station['expected_image_size']:raise RuntimeError('Camera resolution differs from station configuration')
                context={'intrinsic':frame.intrinsic,'distortion':frame.distortion,
                         'setup_id':station.get('setup_id'),'camera_fixed':station.get('camera_fixed')}
                base_valid=calibration.compatible(frame.serial,context)
                t0 = time.monotonic()
                stamp = max(last_stamp+1, int(time.monotonic()*1000))
                last_stamp = stamp
                hand_input = mp.Image(image_format=mp.ImageFormat.SRGB,
                    data=np.ascontiguousarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB)))
                hand_result = hand_worker.submit(hands.detect_for_video, hand_input, stamp)
                detector_start = time.monotonic()
                prediction = predict_region(yolo,image,station.get('image_roi_xyxy'),device=compute,imgsz=args.imgsz,
                                            quantize=('fp16' if args.half else None),conf=min(.18,args.confidence),iou=args.iou,verbose=False)
                detector_ms = (time.monotonic()-detector_start)*1000
                result = hand_result.result()
                observation = {'schema_version':2, 'source_kind':'live_camera','source_session_id':source_session_id,'frame_id':count,
                    'captured_at_unix_s':frame.captured_at, 'published_at_unix_s':time.time(),
                    'camera':args.camera, 'camera_serial':frame.serial,
                    'image_size':[w,h], 'depth_available':frame.depth_m is not None,
                    'camera_intrinsics':frame.intrinsic, 'camera_distortion':frame.distortion,
                    'device_timestamp_ms':frame.device_timestamp_ms,
                    'timestamp_basis':'host_received_RGBD_pair',
                    'compute':compute, 'detector_ms':detector_ms,
                    'mounting':'eye_to_hand','station_setup_id':station.get('setup_id'),
                    'camera_frame':'camera_color_optical_frame','base_frame':'base_link','units':'m',
                    'base_calibration_valid':base_valid,
                    'calibration_id':calibration.data.get('calibration_id') if base_valid else None,
                    'camera_model_signature':camera_signature(frame.intrinsic,frame.distortion) if frame.intrinsic else None,
                    'image_roi_xyxy':station.get('image_roi_xyxy'),
                    'model':args.model.name, 'supported_tool_classes':supported,
                    'detections':[], 'hands':[]}
                canvas = image.copy()
                for box in prediction.boxes:
                    xyxy = box.xyxy[0].tolist()
                    u, v = (xyxy[0]+xyxy[2])/2, (xyxy[1]+xyxy[3])/2
                    quality=sample_depth(frame.depth_m,[u,v],frame.intrinsic,frame.distortion)
                    point=quality['point_camera_m']
                    observation['detections'].append({'class_name':yolo.names[int(box.cls[0])],
                        'confidence':float(box.conf[0]), 'box_xyxy':xyxy, 'center_px':[u,v],
                        'surface_point_camera_m':point,
                        'surface_point_base_m':calibration.point_in_base(point,frame.serial,context),
                        'depth_quality':quality,'point_kind':'bbox_center_surface_sample',
                        'grasp_pose':None})
                observation['detections']=tracker.update(observation['detections'],frame.received_monotonic)
                for detection in observation['detections']:
                    detection['surface_point_base_m']=calibration.point_in_base(detection['surface_point_camera_m'],frame.serial,context)
                draw_tools(canvas,observation['detections'],frame.intrinsic,frame.distortion)
                for landmarks, handedness in zip(result.hand_landmarks, result.handedness):
                    pixels = [(lm.x*w, lm.y*h) for lm in landmarks]
                    hand = {'handedness':handedness[0].category_name,
                            'confidence':float(handedness[0].score), 'keypoints':[]}
                    for index,(lm,pixel) in enumerate(zip(landmarks,pixels)):
                        quality=sample_depth(frame.depth_m,pixel,frame.intrinsic,frame.distortion)
                        point=quality['point_camera_m']
                        hand['keypoints'].append({'id':index,'pixel':list(pixel),
                            'normalized_xyz':[lm.x,lm.y,lm.z], 'camera_m':point,'depth_quality':quality,
                            'base_m':calibration.point_in_base(point,frame.serial,context)})
                    observation['hands'].append(hand)
                observation['hands'],observation['hand_present'],observation['hand_status']=hand_tracker.update(observation['hands'],frame.received_monotonic)
                for hand in observation['hands']:
                    hand['palm_base_m']=calibration.point_in_base(hand.get('palm_camera_m'),frame.serial,context)
                    pixels=[k['pixel'] for k in hand['keypoints']]
                    for k in hand['keypoints']:
                        k['base_m']=calibration.point_in_base(k['camera_m'],frame.serial,context)
                    color=(0,255,0) if hand['observed_this_frame'] else (0,180,255)
                    for a,b in EDGES:
                        cv2.line(canvas,tuple(map(int,pixels[a])),tuple(map(int,pixels[b])),color,2)
                    for pixel in pixels:cv2.circle(canvas,tuple(map(int,pixel)),3,color,-1)
                # Presence holds for 0.5 s; disappearance is not proof of a clear workspace.
                observation['inference_ms'] = (time.monotonic()-t0)*1000
                now = time.monotonic()
                completed.append(now)
                observation['processed_fps'] = ((len(completed)-1)/(completed[-1]-completed[0])) if len(completed)>1 else 0
                observation['host_latency_ms'] = (now-frame.received_monotonic)*1000
                observation['published_at_unix_s'] = time.time()
                if frame.depth_m is not None:
                    valid = np.isfinite(frame.depth_m)&(frame.depth_m>0.15)&(frame.depth_m<3)
                    observation['depth_valid_ratio'] = float(valid.mean())
                payload = json.dumps(observation, allow_nan=False)
                (args.output/'latest.json.tmp').write_text(payload+'\n')
                os.replace(args.output/'latest.json.tmp',args.output/'latest.json')
                if args.record_all or now-last_log >= 1/args.log_hz:
                    log.write(payload+'\n');log.flush();last_log=now
                cv2.putText(canvas,f'{compute} | {observation["processed_fps"]:.1f} FPS | hands: {len(observation["hands"])}',
                            (8,22),cv2.FONT_HERSHEY_SIMPLEX,0.5,(0,255,255),1)
                # A small token bucket absorbs capture/inference jitter near
                # 30 Hz without dropping frames that straddle fixed time slots.
                # Sustained output remains bounded by preview_fps.
                preview_credit = min(1.5, preview_credit + (now-last_preview)*args.preview_fps)
                last_preview = now
                if preview_credit >= 1.0:
                    preview_credit -= 1.0
                    atomic_image(args.output/'latest.jpg', canvas)
                    if frame.depth_m is not None:
                        depth_view = cv2.applyColorMap(np.uint8(np.clip((frame.depth_m-0.15)/1.35,0,1)*255),cv2.COLORMAP_TURBO)
                        depth_view[~valid] = 0
                        cv2.putText(depth_view,'Depth: 0.15m (blue) - 1.50m (red); black=invalid',
                                    (5,20),cv2.FONT_HERSHEY_SIMPLEX,0.42,(255,255,255),1)
                        atomic_image(args.output/'depth.jpg',depth_view)
                    else:
                        depth_view=np.zeros_like(canvas)
                        cv2.putText(depth_view,'RGB-only mode: no depth available',(20,50),
                                    cv2.FONT_HERSHEY_SIMPLEX,0.7,(255,255,255),2)
                        atomic_image(args.output/'depth.jpg',depth_view)
                        (args.output/'depth.npz').unlink(missing_ok=True)
                if frame.depth_m is not None and now-last_depth>=0.2:
                    with (args.output/'depth.npz.tmp').open('wb') as depth_file:
                        np.savez(depth_file,depth_m=frame.depth_m,color_bgr=frame.color,metadata=np.array(payload))
                    os.replace(args.output/'depth.npz.tmp',args.output/'depth.npz')
                    last_depth=now
                if ros_process and ros_process.poll() is not None:
                    raise RuntimeError('ROS publisher exited unexpectedly')
                if link_process and link_process.poll() is not None:
                    raise RuntimeError('PS vision publisher exited unexpectedly')
                if not args.headless:
                    cv2.imshow('Desktop perception - Q exits',canvas)
                    if cv2.waitKey(1)&0xff in [27,ord('q')]: break
                count += 1
                if count == 1 or count%30 == 0:
                    print(f'frames={count}, objects={len(observation["detections"])}, hands={len(observation["hands"])}, depth={observation["depth_available"]}, inference={observation["inference_ms"]:.1f}ms',flush=True)
    finally:
        if camera:camera.close()
        hand_worker.shutdown(wait=True)
        hands.close()
        cv2.destroyAllWindows()
        if ros_process:
            ros_process.send_signal(signal.SIGINT)
            try:ros_process.wait(timeout=5)
            except subprocess.TimeoutExpired:ros_process.terminate();ros_process.wait(timeout=5)
            ros_process.stdout.close()
        if link_process:
            link_process.send_signal(signal.SIGINT)
            try:link_process.wait(timeout=3)
            except subprocess.TimeoutExpired:link_process.terminate();link_process.wait(timeout=3)
        print(f'Processed {count} frames in {time.monotonic()-started:.1f}s',flush=True)


if __name__ == '__main__':
    main()
