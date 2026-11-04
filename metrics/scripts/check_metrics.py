#!/usr/bin/env python3
"""Check that published percentiles are computed from delivered raw timing rows."""
import csv,json,math,sys
from pathlib import Path
import numpy as np
root=Path(__file__).resolve().parents[2];logs=root/'metrics/logs';checks=[]
for raw,meta,field,key in [
 ('detector_gpu.csv','detector_gpu.json','predict_wall_ms',('timing_ms','predict_wall_ms')),
 ('detector_cpu.csv','detector_cpu.json','predict_wall_ms',('timing_ms','predict_wall_ms')),
 ('cpu_fallback.csv','cpu_fallback.json','predict_wall_ms',('timing_ms','predict_wall_ms')),
 ('offline_rgbd.csv','benchmark.json','perception_wall_ms',('offline_rgbd','timing_ms')),
 ('hand_model.csv','benchmark.json','hand_model_wall_ms',('hand_model','timing_ms')),
 ('host_loopback_rtt.csv','host_loopback.json','rtt_ms',('rtt_ms',))]:
 data=list(csv.DictReader((logs/raw).open()));v=np.array([float(r[field]) for r in data]);d=json.loads((logs/meta).read_text())
 for k in key:d=d[k]
 for q in [50,95,99]:assert math.isclose(float(np.percentile(v,q)),d[f'p{q}'],rel_tol=1e-10,abs_tol=1e-10),(raw,q)
 assert math.isclose(float(v.max()),d['max'],rel_tol=1e-10)
 checks.append({'file':raw,'samples':len(v),'percentiles_match':True})
f=json.loads((logs/'fixed_threshold.json').read_text());tp=f['overall']['tp'];fp=f['overall']['fp'];fn=f['overall']['fn']
assert tp+fn==393 and len(f['details'])==124 and f['overall']['precision']==tp/(tp+fp)
checks.append({'fixed_threshold_counts_match':True,'images':124,'objects':393})
print(json.dumps({'ok':True,'checks':checks},indent=2))
