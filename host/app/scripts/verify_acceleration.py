#!/usr/bin/env python3
import json
from pathlib import Path
import platform
import time
import torch

root=Path(__file__).resolve().parents[1]
assert torch.version.hip, 'This Python is not the ROCm environment'
assert torch.cuda.is_available(), 'GPU inaccessible: check /dev/kfd and render group/ACL'
properties=torch.cuda.get_device_properties(0)
x=torch.randn(512,512,device='cuda');y=x@x;torch.cuda.synchronize()
assert torch.isfinite(y).all()
from ultralytics import YOLO
import numpy as np
model=YOLO(str(root/'models/yolo11n.pt'))
times=[]
for i in range(30):
    start=time.perf_counter();model.predict(np.zeros((480,640,3),np.uint8),device=0,verbose=False)
    torch.cuda.synchronize()
    if i>=5:times.append((time.perf_counter()-start)*1000)
report={'torch':torch.__version__,'hip':torch.version.hip,'gpu':str(properties),
        'kernel':platform.release(),'matrix_test':'passed','yolo11n_gpu_test':'passed',
        'yolo_predict_median_ms':float(np.median(times)),'yolo_predict_p95_ms':float(np.percentile(times,95))}
(root/'runtime/acceleration.json').write_text(json.dumps(report,indent=2))
(root/'.venv-rocm/verified').write_text(json.dumps(report))
print(json.dumps(report,indent=2))
