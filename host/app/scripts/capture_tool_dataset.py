#!/usr/bin/env python3
"""Collect quality-checked RGB-D sessions for manual tool annotation."""
import argparse
from datetime import datetime
import json
from pathlib import Path
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'vision'))
import cv2
import numpy as np
from robotarm_vision.camera import OrbbecCamera, UVCCamera, LatestCamera


def frame_quality(image):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    return {'mean_luma': float(gray.mean()),
            'p95_luma': float(np.percentile(gray, 95)),
            'laplacian_variance': float(cv2.Laplacian(gray, cv2.CV_64F).var())}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--camera', choices=['orbbec', 'uvc'], default='orbbec')
    parser.add_argument('--device', default='/dev/video4')
    parser.add_argument('--count', type=int, default=30)
    parser.add_argument('--interval', type=float, default=1.)
    parser.add_argument('--scene', choices=['flat', 'upright', 'negative', 'unspecified'], default='unspecified')
    parser.add_argument('--output', type=Path, default=ROOT / 'datasets/site_tools/raw')
    parser.add_argument('--warmup', type=float, default=3.)
    args = parser.parse_args()
    if args.count < 1 or args.interval < 0 or args.warmup < 0:
        parser.error('count must be positive; interval and warmup must be nonnegative')
    session = args.output / (args.scene + '_' + datetime.now().strftime('%Y%m%d_%H%M%S_%f'))
    session.mkdir(parents=True, exist_ok=False)
    camera = LatestCamera(OrbbecCamera() if args.camera == 'orbbec' else UVCCamera(args.device))
    saved, rejected = 0, []
    try:
        until = time.monotonic() + args.warmup
        while time.monotonic() < until:
            camera.read()
        for index in range(args.count):
            frame = camera.read()
            quality = frame_quality(frame.color)
            if quality['p95_luma'] < 12:
                rejected.append({'index': index, 'reason': 'almost_black', **quality})
                print(f'Rejected almost-black frame {index}: check lighting/lens/exposure', flush=True)
            else:
                name = f'{index:05d}'
                if not cv2.imwrite(str(session / f'{name}.png'), frame.color):
                    raise RuntimeError('Image write failed')
                if frame.depth_m is not None:
                    np.save(session / f'{name}.depth.npy', frame.depth_m)
                metadata = {'captured_at': frame.captured_at, 'camera_serial': frame.serial,
                            'intrinsic': frame.intrinsic, 'distortion': frame.distortion,
                            'scene': args.scene, 'group': session.name, 'quality': quality,
                            'annotation_status': 'unlabelled'}
                (session / f'{name}.json').write_text(json.dumps(metadata, indent=2))
                saved += 1
                print(session / f'{name}.png', flush=True)
            time.sleep(args.interval)
    finally:
        camera.close()
        (session / 'session.json').write_text(json.dumps({
            'group': session.name, 'scene': args.scene, 'saved': saved,
            'rejected': rejected, 'split_rule': 'Keep this whole capture session in one split',
            'annotation_status': 'unlabelled'}, indent=2))
    if not saved:
        raise SystemExit('No usable RGB frames. Session must not enter a training dataset.')


if __name__ == '__main__':
    main()
