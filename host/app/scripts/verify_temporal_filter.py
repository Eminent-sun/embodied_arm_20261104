#!/usr/bin/env python3
"""Synthetic perturbation audit of saved detector output; never opens a camera."""
import copy
import json
from pathlib import Path
import sys
import time
import threading
import uuid
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'vision'),str(ROOT/'communication')]
from robotarm_vision.tracking import TemporalTracker
from robotarm_link.protocol import Client
from robotarm_link.vision_bridge import relay_once
from robotarm_link.vision_receiver import serve


def main():
    out=ROOT/'runtime/temporal';out.mkdir(exist_ok=True)
    original=json.loads((ROOT/'runtime/eye_to_hand/pipeline-replay.json').read_text())['received']['observation']
    tracker=TemporalTracker();rng=np.random.default_rng(73);trace=[];raw=[];smooth=[]
    for frame in range(100):
        measurements=copy.deepcopy(original['detections'])
        jitter=float(rng.normal(0,.004));p=measurements[0]['surface_point_camera_m'];p[0]+=jitter
        if frame==45:p[0]+=.15
        if frame in (60,61,62):measurements=measurements[1:]
        detections=tracker.update(measurements,frame/30)
        target=next((d for d in detections if d['track_id']==1),None)
        trace.append({'frame':frame,'input_x_m':p[0] if frame not in (60,61,62) else None,'target':target})
        if 10<=frame<40:raw.append(p[0]);smooth.append(target['surface_point_camera_m'][0])
    stop=threading.Event();ready=threading.Event();ports=[]
    def bound(port):ports.append(port);ready.set()
    thread=threading.Thread(target=serve,kwargs={'port':0,'ready':bound,'stop_event':stop},daemon=True);thread.start()
    if not ready.wait(3):raise RuntimeError('No simulator')
    client=Client(port=ports[0]);session=uuid.uuid4().hex
    try:
        acknowledgements=[]
        # Exercise actual file->bridge->PS transport with explicit synthetic origin.
        for frame in range(3):
            obs={**original,'schema_version':2,'source_kind':'synthetic_test','source_session_id':session,'frame_id':frame,
                 'captured_at_unix_s':time.time(),'detections':detections,'hands':[]}
            path=out/'synthetic_observation.json';path.write_text(json.dumps(obs))
            _,reply=relay_once(client,path,status_path=out/'link_status.json');acknowledgements.append(reply)
        receiver=client.request('vision_status');sent=json.loads((out/'link_status.json').read_text())
        assert receiver['received_payload']==sent['payload']
        assert all(a['accepted'] for a in acknowledgements)
        assert not receiver['execution_enabled']
        report={'source_kind':'synthetic_test','camera_opened':False,'description':'Saved seven-object result + artificial +/- mm jitter, 150 mm spike and three-frame dropout; not a real video benchmark.',
                'raw_x_std_mm':float(np.std(raw)*1000),'filtered_x_std_mm':float(np.std(smooth)*1000),
                'outlier_rejected':trace[45]['target']['tracking_status']=='jump_rejected',
                'dropout_held_unusable':all(not trace[i]['target']['coordinate_usable'] for i in (60,61,62)),
                'acks':acknowledgements,'received_matches_status_file':True,'trace':trace}
        (out/'report.json').write_text(json.dumps(report,indent=2))
        xs=[t['input_x_m'] for t in trace];ys=[t['target']['surface_point_camera_m'][0] if t['target'] and t['target']['surface_point_camera_m'] else None for t in trace]
        fig,ax=plt.subplots(figsize=(11,4));ax.plot(np.arange(100)/30,xs,label='Raw synthetic measurement',alpha=.6)
        ax.plot(np.arange(100)/30,ys,label='Filtered / bounded held point');ax.axvspan(2,2.1,color='orange',alpha=.2,label='Dropout: unavailable for motion update')
        ax.set(xlabel='Synthetic time (s)',ylabel='Camera X (m)',title='Software regression fixture, not real-video performance');ax.legend();fig.tight_layout();fig.savefig(out/'filter_comparison.png',dpi=160);plt.close(fig)
        print(json.dumps({k:v for k,v in report.items() if k!='trace'},indent=2))
    finally:client.close();stop.set();thread.join(3)
if __name__=='__main__':main()
