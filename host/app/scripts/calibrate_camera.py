#!/usr/bin/env python3
"""Printable checkerboard, Gemini RGB-D capture, intrinsics and fixed-camera extrinsics."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import shutil
import sys
import time

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vision'))
import cv2
import numpy as np
from robotarm_vision.calibration import board_points, intrinsic_matrix, solve_intrinsic, solve_external
from robotarm_vision.camera import LatestCamera, OrbbecCamera
from robotarm_vision.geometry import depth_point
from robotarm_vision.quality import sample_depth, camera_signature


def write_json(path, data):
    path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(data,indent=2,ensure_ascii=False,allow_nan=False)+'\n')


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action',choices=['board','capture','intrinsics','extrinsics','template','sample','freeze'])
    parser.add_argument('--columns',type=int,default=9,help='Inner corners, not squares')
    parser.add_argument('--rows',type=int,default=6)
    parser.add_argument('--square-mm',type=float,default=20)
    parser.add_argument('--session',type=Path,default=ROOT/'runtime/calibration/session')
    parser.add_argument('--input',type=Path)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--activate',action='store_true',help='Install externally measured transform only after passing validation')
    parser.add_argument('--pixel',nargs=2,type=int,metavar=('U','V'))
    parser.add_argument('--rms-mm',type=float,default=5.)
    parser.add_argument('--max-mm',type=float,default=10.)
    parser.add_argument('--station',type=Path,default=ROOT/'config/vision_station.json')
    args=parser.parse_args()
    obj=board_points(args.columns,args.rows,args.square_mm/1000)
    if args.action=='freeze':
        source=args.input or ROOT/'runtime/vision/depth.npz'
        # Open the atomic snapshot once, keeping RGB/depth/metadata from one frame.
        with np.load(source,allow_pickle=False) as frozen:
            color=frozen['color_bgr'].copy();depth=frozen['depth_m'].copy();metadata=str(frozen['metadata'])
        meta=json.loads(metadata)
        if not 0<=time.time()-meta['captured_at_unix_s']<2:parser.error('Live snapshot is stale; do not calibrate from an unverified old camera placement')
        if color.shape[:2]!=depth.shape:parser.error('RGB/depth shape mismatch')
        output=args.output or ROOT/'runtime/calibration/snapshots'/datetime.now().strftime('%Y%m%d_%H%M%S_%f.npz')
        if output.suffix!='.npz':parser.error('Frozen snapshot output must end in .npz')
        output.parent.mkdir(parents=True,exist_ok=True)
        if output.exists() or output.with_suffix('.png').exists():parser.error('Snapshot path already exists')
        with output.open('xb') as f:np.savez_compressed(f,color_bgr=color,depth_m=depth,metadata=metadata)
        if not cv2.imwrite(str(output.with_suffix('.png')),color):raise RuntimeError('Failed to save frozen RGB preview')
        print(f'Frozen RGB-D: {output}; inspect pixels on {output.with_suffix(".png")}');return
    if args.action=='sample':
        if not args.input or args.pixel is None:parser.error('sample requires --input frozen RGB-D npz and --pixel U V')
        with np.load(args.input,allow_pickle=False) as frozen:
            meta=json.loads(str(frozen['metadata']));depth=frozen['depth_m']
            intrinsic=meta.get('camera_intrinsics',meta.get('intrinsic'))
            distortion=meta.get('camera_distortion',meta.get('distortion'))
            result=sample_depth(depth,args.pixel,intrinsic,distortion)
        result.update(camera_serial=meta['camera_serial'],factory_intrinsic=intrinsic,
                      factory_distortion=distortion,source_snapshot=str(args.input.resolve()),
                      source_frame_id=meta.get('frame_id'),pixel=args.pixel,
                      camera_model_signature=camera_signature(intrinsic,distortion),base_m=None,
                      note='Frozen same-frame sample. Measure base_m at this exact physical marker; no inferred base coordinates.')
        write_json(args.output or ROOT/'runtime/calibration/point_sample.json',result)
        print(json.dumps(result,indent=2));return
    if args.action=='board':
        size=args.square_mm;w=(args.columns+1)*size;h=(args.rows+1)*size
        svg=[f'<svg xmlns="http://www.w3.org/2000/svg" width="{w+20}mm" height="{h+30}mm" viewBox="0 0 {w+20} {h+30}">',f'<rect width="100%" height="100%" fill="white"/>']
        for y in range(args.rows+1):
            for x in range(args.columns+1):
                if (x+y)%2==0:svg.append(f'<rect x="{10+x*size}" y="{10+y*size}" width="{size}" height="{size}" fill="black"/>')
        svg.append(f'<text x="10" y="{h+19}" font-size="3">{args.columns} x {args.rows} inner corners; square {size:g} mm. Print 100%, measure with ruler.</text></svg>')
        path=args.output or ROOT/'config/calibration/checkerboard_9x6_20mm.svg'
        path.parent.mkdir(parents=True,exist_ok=True);path.write_text('\n'.join(svg));print(path);return
    if args.action=='template':
        write_json(args.output or ROOT/'config/calibration/correspondences.template.json',
                   {'units':'m','camera_serial':'AY6T25501D7','physically_measured':False,
                    'camera_fixed':False,'setup_id':None,'factory_intrinsic':None,'factory_distortion':None,
                    'fit':[{'camera_m':None,'base_m':None} for _ in range(6)],
                    'validation':[{'camera_m':None,'base_m':None} for _ in range(4)],
                    'instructions':'Fixed camera. Measure paired physical locations; use >=4 NEW locations for validation. Set physically_measured=true only for actual measurements. Never use examples to enable motion.'})
        return
    if args.action=='extrinsics':
        if not args.input:parser.error('--input requires measured correspondences JSON')
        data=json.loads(args.input.read_text());result=solve_external(data,args.rms_mm/1000,args.max_mm/1000)
        result['source_file']=str(args.input.resolve());result['created_at']=datetime.now().isoformat()
        output=args.output or ROOT/'runtime/calibration/camera_to_base_candidate.json'
        write_json(output,result)
        if args.activate:
            if not result['validated']:parser.error(f'External calibration failed; diagnostic saved to {output}')
            station=json.loads(args.station.read_text())
            if station.get('camera_fixed') is not True or station.get('setup_id')!=result['setup_id']:
                parser.error('Station is not fixed or setup_id differs; calibration was not activated')
            target=ROOT/'config/calibration/camera_to_base.json'
            if target.exists():shutil.copy2(target,target.with_suffix('.json.backup.'+datetime.now().strftime('%Y%m%d%H%M%S')))
            write_json(target,result)
        print(json.dumps(result,ensure_ascii=False,indent=2));return
    if args.action=='capture':
        args.session.mkdir(parents=True,exist_ok=True)
        if (args.session/'session.json').exists():parser.error('Session already exists; choose a new --session to avoid mixing configurations')
        camera=LatestCamera(OrbbecCamera());count=0;previous=None
        try:
            while True:
                frame=camera.read();gray=cv2.cvtColor(frame.color,cv2.COLOR_BGR2GRAY)
                ok,corners=cv2.findChessboardCornersSB(gray,(args.columns,args.rows),cv2.CALIB_CB_NORMALIZE_IMAGE)
                canvas=frame.color.copy()
                if ok:cv2.drawChessboardCorners(canvas,(args.columns,args.rows),corners,True)
                cv2.putText(canvas,f'SPACE save | Q quit | saved {count} | board {ok}',(8,22),cv2.FONT_HERSHEY_SIMPLEX,0.55,(0,255,255),1)
                cv2.imshow('Camera calibration - move/tilt board, cover image',canvas)
                key=cv2.waitKey(1)&255
                if key in [27,ord('q')]:break
                if key==32 and ok:
                    if previous is not None and np.sqrt(np.mean((corners-previous)**2))<12:
                        print('Move/tilt the board more before saving another view.',flush=True);continue
                    previous=corners.copy();name=f'{count:04d}'
                    cv2.imwrite(str(args.session/f'{name}.png'),frame.color)
                    np.savez(args.session/f'{name}.npz',corners=corners,depth_m=frame.depth_m)
                    write_json(args.session/'session.json',{'columns':args.columns,'rows':args.rows,'square_m':args.square_mm/1000,
                        'camera_serial':frame.serial,'image_size':[gray.shape[1],gray.shape[0]],
                        'factory_intrinsic':frame.intrinsic,'factory_distortion':frame.distortion,'views':count+1})
                    count+=1;print(f'Saved view {count}',flush=True)
        finally:camera.close();cv2.destroyAllWindows()
        return
    meta=json.loads((args.session/'session.json').read_text())
    obj=board_points(meta['columns'],meta['rows'],meta['square_m'])
    files=sorted(args.session.glob('*.npz'))
    corners=[];depth_errors=[]
    matrix=intrinsic_matrix(meta['factory_intrinsic']);dist=np.array(meta['factory_distortion'])
    for path in files:
        with np.load(path,allow_pickle=False) as data:
            pts=data['corners'];corners.append(pts)
            ok,rvec,tvec=cv2.solvePnP(obj,pts,matrix,dist)
            if ok:
                predicted=obj@cv2.Rodrigues(rvec)[0].T+tvec.ravel()
                for pixel,expected in zip(pts.reshape(-1,2),predicted):
                    measured=depth_point(data['depth_m'],pixel,meta['factory_intrinsic'],meta['factory_distortion'])
                    if measured:depth_errors.append(measured[2]-expected[2])
    result=solve_intrinsic(corners,tuple(meta['image_size']),obj)
    result.update(camera_serial=meta['camera_serial'],square_m=meta['square_m'],samples=[p.name for p in files])
    if depth_errors:
        result['factory_depth_check']={'samples':len(depth_errors),'median_z_error_m':float(np.median(depth_errors)),
            'p95_absolute_z_error_m':float(np.percentile(np.abs(depth_errors),95)),
            'note':'Checkerboard corner depth vs factory-intrinsic PnP plane; verify printed square size and flatness.'}
    output=args.output or args.session/'intrinsics_report.json';write_json(output,result);print(json.dumps(result,indent=2))


if __name__=='__main__':main()
