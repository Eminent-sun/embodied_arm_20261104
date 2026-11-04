#!/usr/bin/env python3
"""Export one synchronized RGB-D snapshot to a metric optical-frame PLY cloud."""
import argparse
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'vision'))
import cv2
import numpy as np
from robotarm_vision.calibration import intrinsic_matrix

parser=argparse.ArgumentParser(description=__doc__)
parser.add_argument('--input',type=Path,default=ROOT/'runtime/vision/depth.npz')
parser.add_argument('--output',type=Path,default=ROOT/'runtime/vision/cloud.ply')
parser.add_argument('--stride',type=int,default=2)
args=parser.parse_args()
if args.stride<1:parser.error('Stride must be positive')
with np.load(args.input,allow_pickle=False) as snapshot:
    depth=snapshot['depth_m'];meta=json.loads(str(snapshot['metadata']))
    color=snapshot['color_bgr'][:,:,::-1]
y,x=np.mgrid[0:depth.shape[0]:args.stride,0:depth.shape[1]:args.stride]
z=depth[y,x].ravel();valid=np.isfinite(z)&(z>0.15)&(z<3)
pixels=np.stack([x.ravel()[valid],y.ravel()[valid]],axis=1).astype(float)
rays=cv2.undistortPoints(pixels.reshape(-1,1,2),intrinsic_matrix(meta['camera_intrinsics']),np.asarray(meta['camera_distortion'])).reshape(-1,2)
xyz=np.column_stack([rays*z[valid,None],z[valid]])
rgb=color[y,x].reshape(-1,3)[valid]
args.output.parent.mkdir(parents=True,exist_ok=True)
with args.output.open('w') as f:
    f.write(f'ply\nformat ascii 1.0\ncomment optical frame metres; source frame {meta["frame_id"]}\nelement vertex {len(xyz)}\nproperty float x\nproperty float y\nproperty float z\nproperty uchar red\nproperty uchar green\nproperty uchar blue\nend_header\n')
    np.savetxt(f,np.column_stack([xyz,rgb]),fmt='%.6f %.6f %.6f %d %d %d')
args.output.with_suffix('.json').write_text(json.dumps(meta,indent=2))
print(f'{len(xyz)} valid points: {args.output}')
