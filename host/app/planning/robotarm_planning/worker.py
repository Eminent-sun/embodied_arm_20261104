"""Read-only motion planner worker; deliberately has no execution/upload command."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import time
import traceback
import rclpy
from .core import PlanningError,validate_request,digest
from .moveit_backend import MoveItPlanner

ROOT=Path(__file__).resolve().parents[2]


def atomic(path,data):
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix(path.suffix+'.tmp');temp.write_text(json.dumps(data,indent=2,ensure_ascii=False,allow_nan=False));os.replace(temp,path)


def live_review(request):
    from .handover import review_plan_targets
    from robotarm_vision.geometry import Calibration
    obs=json.loads((ROOT/'runtime/vision/latest.json').read_text())
    cfg=json.loads((ROOT/'config/planning.json').read_text())
    station=json.loads((ROOT/'config/vision_station.json').read_text())
    cal=Calibration(ROOT/'config/calibration/camera_to_base.json')
    context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
             'camera_fixed':station.get('camera_fixed'),'setup_id':station.get('setup_id')}
    if digest(cfg)!=request['config_sha256'] or cal.data.get('calibration_id')!=request['calibration_id'] or not cal.compatible(obs.get('camera_serial'),context):
        raise PlanningError('标定、安装位或规划配置改变/失效')
    if cal.matrix.tolist()!=request['T_base_camera']:raise PlanningError('标定矩阵内容改变')
    return review_plan_targets(request,obs)


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--request',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    node=None;request={};started=time.time();lock=None
    try:
        request=json.loads(a.request.read_text());validate_request(request)
        if request['mode']=='measured' and not started<request['expires_at_unix_s']:raise PlanningError('规划请求已过期，请重新选择当前目标')
        if request['mode']=='measured':
            review=live_review(request)
            if review['state']!='observation_consistent':raise PlanningError(review['reason'])
        domain=os.environ.get('ROS_DOMAIN_ID','0')
        if not domain.isdigit():raise PlanningError('Invalid ROS domain')
        lock=(ROOT/'runtime/planning'/f'domain_{domain}.lock').open('a')
        try:fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:raise PlanningError('Another planning job is using this scene')
        def progress(stage):atomic(a.output,{'status':'planning','stage':stage,'started_at_unix_s':started,'execution_enabled':False})
        progress('waiting_for_moveit');rclpy.init();node=MoveItPlanner();result=node.plan(request,progress)
        result.update(created_at_unix_s=time.time(),request_sha256=digest(request),request_file=str(a.request.resolve()))
        if request['mode']=='measured':
            review=live_review(request)
            result['target_review']=review
            if review['state']!='observation_consistent':result['status']='requires_review'
        atomic(a.output,result);print(json.dumps({'status':result['status'],'segments':len(result['segments']),'duration_s':result['duration_s'],'output':str(a.output)},ensure_ascii=False))
    except Exception as exc:
        atomic(a.output,{'status':'failed','error':str(exc),'execution_enabled':False,'mode':request.get('mode'),
                         'started_at_unix_s':started,'finished_at_unix_s':time.time()})
        traceback.print_exc();return 1
    finally:
        if node:node.destroy_node()
        if rclpy.ok():rclpy.shutdown()
        if lock:lock.close()
    return 0

if __name__=='__main__':raise SystemExit(main())
