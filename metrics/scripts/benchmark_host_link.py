#!/usr/bin/env python3
"""Host localhost protocol + artificial tracking input. No FPGA board measurements."""
import argparse,csv,json,sys,time,threading,copy
from pathlib import Path
import numpy as np
BASE=Path(__file__).resolve().parents[2];APP=BASE/'host/app';sys.path[:0]=[str(APP/'vision'),str(APP/'communication')]
from robotarm_link.protocol import Client
from robotarm_link.ps_simulator import serve
from robotarm_vision.tracking import TemporalTracker

def stats(v):
 a=np.array(v,float);return {**{f'p{q}':float(np.percentile(a,q)) for q in [50,95,99]},'max':float(a.max()),'mean':float(a.mean()),'n':len(a)}
def write_csv(p,rows):
 with p.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
def main():
 p=argparse.ArgumentParser();p.add_argument('--output',type=Path,default=BASE/'metrics/logs');p.add_argument('--duration',type=float,default=10);a=p.parse_args();out=a.output;out.mkdir(parents=True,exist_ok=True)
 ready=threading.Event();stop=threading.Event();ports=[]
 def cb(port):ports.append(port);ready.set()
 worker=threading.Thread(target=serve,kwargs={'port':0,'ready':cb,'stop_event':stop},daemon=True);worker.start();assert ready.wait(3)
 client=Client(port=ports[0]);rows=[];errors=0
 try:
  for _ in range(20):client.request('status')
  started=time.perf_counter();n=0
  while n<1000 or time.perf_counter()-started<a.duration:
   t=time.perf_counter_ns();reply=client.request('status');elapsed=(time.perf_counter_ns()-t)/1e6
   good=reply['ok'] and reply['positions_rad']==[0.,1.57,0.,0.,1.57,0.] and reply['mode']=='simulation'
   errors+=not good
   request={'seq':client.sequence,'command':'status'}
   payload_bytes=len(json.dumps(request,separators=(',',':')).encode())+len(json.dumps(reply,separators=(',',':')).encode())
   rows.append({'sequence':client.sequence,'rtt_ms':elapsed,'payload_bytes_both_directions':payload_bytes,'reply_valid':good});n+=1
  duration=time.perf_counter()-started
 finally:client.close();stop.set();worker.join(3)
 write_csv(out/'host_loopback_rtt.csv',rows)
 report={'scope':'Same AI PC TCP loopback, Python reference receiver; excludes physical NIC, cable, AX7010, PL and actuators',
  'endpoint':'127.0.0.1 ephemeral port','clock':'perf_counter_ns on one host; no clock sync needed for RTT',
  'samples':len(rows),'duration_s':duration,'rtt_ms':stats([r['rtt_ms'] for r in rows]),'timeouts':0,'invalid_replies':errors,
  'application_payload_bytes_per_s_both_directions':sum(r['payload_bytes_both_directions'] for r in rows)/duration,
  'requests_per_s':len(rows)/duration,'includes_arm1_header_in_throughput':False,'no_motion':True}
 (out/'host_loopback.json').write_text(json.dumps(report,indent=2))
 # Artificial static target with additive 4 mm normal noise; no physical accuracy claim.
 rng=np.random.default_rng(73);tracker=TemporalTracker();trace=[]
 for i in range(600):
  raw=.2+float(rng.normal(0,.004));injected=i in (180,360);drop=450<=i<453
  if injected:raw+=.15
  d={'class_name':'pliers','confidence':.9,'box_xyxy':[100,100,200,200],
     'surface_point_camera_m':[raw,.1,.6],'depth_quality':{'valid':True}}
  output=tracker.update([] if drop else [d],i/30)
  row=output[0] if output else {};point=row.get('surface_point_camera_m')
  trace.append({'frame':i,'input_x_m':raw,'filtered_x_m':point[0] if point else None,'injected_jump':injected,'dropout':drop,
                'tracking_status':row.get('tracking_status'),'coordinate_usable':row.get('coordinate_usable')})
 write_csv(out/'synthetic_filter.csv',trace)
 stable=[r for r in trace if 20<=r['frame']<160]
 rejected=sum(r['tracking_status']=='jump_rejected' for r in trace if r['injected_jump'])
 hold_ok=sum(r['coordinate_usable'] is False and r['filtered_x_m'] is not None for r in trace if r['dropout'])
 f={'scope':'Synthetic software fixture, 600 frames at nominal 30 Hz, seed73; not measured camera/robot jitter',
    'raw_std_mm':float(np.std([r['input_x_m'] for r in stable])*1000),'filtered_std_mm':float(np.std([r['filtered_x_m'] for r in stable])*1000),
    'jump_rejected':rejected,'jump_injected':2,'held_unusable':hold_ok,'dropout_frames':3}
 (out/'synthetic_filter.json').write_text(json.dumps(f,indent=2));print(json.dumps({'network':report,'filter':f},indent=2))
if __name__=='__main__':main()
