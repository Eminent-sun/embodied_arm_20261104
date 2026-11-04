#!/usr/bin/env python3
"""Start a copied dashboard on a temporary localhost port; never starts camera."""
import json,os,re,socket,subprocess,sys,time,urllib.request,urllib.error
from pathlib import Path
root=Path(__file__).resolve().parents[2];app=root/'host/app'
with socket.socket() as s:s.bind(('127.0.0.1',0));port=s.getsockname()[1]
env=os.environ.copy();env['PYTHONPATH']=os.pathsep.join(str(app/x) for x in ['vision','communication','planning']);env['PYTHONDONTWRITEBYTECODE']='1'
log=(root/'metrics/logs/dashboard_smoke.log').open('w');proc=subprocess.Popen([sys.executable,'-m','robotarm_vision.dashboard','--port',str(port)],cwd=app,env=env,stdout=log,stderr=log)
base=f'http://127.0.0.1:{port}';report={}
try:
 for _ in range(50):
  try:
   with urllib.request.urlopen(base+'/api/pickup/status',timeout=.3) as r:report['pickup']=json.load(r)
   break
  except OSError:time.sleep(.1)
 else:raise RuntimeError('Dashboard did not start')
 for path in ['/','/workbench','/planning','/api/status']:
  with urllib.request.urlopen(base+path,timeout=2) as r:
   body=r.read().decode();report[path]=r.status
   if path=='/workbench':token=re.search("const token='([^']+)'",body).group(1)
 with urllib.request.urlopen(base+'/api/collection/status') as r:status=json.load(r)
 assert status['camera_state']=='stopped' and not status['inference_running']
 assert status['dataset_directory'].startswith(str(app))
 report['camera_state']=status['camera_state'];report['inference_running']=False;report['copy_root_confirmed']=True
 req=urllib.request.Request(base+'/api/pickup/freeze',data=b'{"track_id":1}',headers={'Content-Type':'application/json','X-Task-Token':token})
 try:
  urllib.request.urlopen(req);raise AssertionError('Missing RGB-D should not qualify')
 except urllib.error.HTTPError as e:
  assert e.code==400;report['no_rgbd_request_status']=e.code
 (root/'metrics/logs/dashboard_smoke.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2))
finally:
 proc.terminate();proc.wait(timeout=10);log.close()
