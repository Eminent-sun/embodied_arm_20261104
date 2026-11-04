#!/usr/bin/env python3
"""Freeze one current qualified visual target into an AI PC planning request."""
import argparse
import json
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'planning'),str(ROOT/'vision'),str(ROOT/'communication')]
from robotarm_planning.core import build_live_request
from robotarm_vision.geometry import Calibration


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--track-id',type=int,required=True)
    p.add_argument('--zone',default='',help='Required for legacy place/handover tasks only');p.add_argument('--profile',required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--hand-track-id',type=int,help='Explicit receiving hand ID within the fixed handover region')
    a=p.parse_args()
    if a.output.exists():p.error('Output exists; choose a new file to preserve the selected target')
    try:
        def read(path):return json.loads((ROOT/path).read_text())
        request=build_live_request(read('runtime/vision/latest.json'),a.track_id,a.zone,a.profile,
            read('config/planning.json'),Calibration(ROOT/'config/calibration/camera_to_base.json'),read('config/vision_station.json'),hand_track_id=a.hand_track_id)
        a.output.parent.mkdir(parents=True,exist_ok=True)
        with a.output.open('x') as f:json.dump(request,f,indent=2,ensure_ascii=False,allow_nan=False)
        print(f'Plan-only request saved: {a.output}')
    except (OSError,ValueError,KeyError,TypeError) as exc:p.error(str(exc))
if __name__=='__main__':main()
