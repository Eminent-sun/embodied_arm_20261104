"""Dashboard -> isolated system-Python planner. Never imports ROS in this process."""
import json
import os
from pathlib import Path
import secrets
import signal
import subprocess
import threading
import time

ROOT=Path(__file__).resolve().parents[2]
_lock=threading.Lock();_process=None;_guard_lock=threading.Lock()


def load_job(job_id):
    if len(job_id)!=16 or any(c not in '0123456789abcdef' for c in job_id):raise ValueError('Invalid plan ID')
    folder=ROOT/'runtime/planning/jobs'/job_id
    result=json.loads((folder/'result.json').read_text())
    if result.get('mode')!='measured' or result.get('task_kind')!='tool_handover' or result.get('status') not in ['planned_for_review','requires_review']:return result
    from robotarm_planning.core import digest
    from robotarm_planning.handover import HandoverGuard
    from .geometry import Calibration
    # UI polling is advisory, NOT a real-time safety loop or motor stop command.
    # Persist the invalidation so browser/dashboard restarts cannot clear it.
    with _guard_lock:
        path=folder/'guard.json'
        previous=json.loads(path.read_text()) if path.exists() else {}
        try:
            req=json.loads((folder/'request.json').read_text())
            obs=json.loads((ROOT/'runtime/vision/latest.json').read_text())
            cfg=json.loads((ROOT/'config/planning.json').read_text())
            station=json.loads((ROOT/'config/vision_station.json').read_text())
            cal=Calibration(ROOT/'config/calibration/camera_to_base.json')
            context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
                     'camera_fixed':station.get('camera_fixed'),'setup_id':station.get('setup_id')}
            if digest(cfg)!=req['config_sha256'] or not cal.compatible(obs.get('camera_serial'),context) or cal.matrix.tolist()!=req['T_base_camera']:
                raise ValueError('规划配置或相机标定改变')
            guard=HandoverGuard(req)
            guard.invalidated=previous.get('hold_required',False) or result['status']=='requires_review'
            review=guard.update(obs,phase='pickup')
        except (OSError,ValueError,KeyError,TypeError) as exc:
            review={'state':'requires_replan','reason':str(exc),'hold_required':True,'automatic_release':False,
                    'execution_enabled':False,'controller_commands_sent':False}
        if review!=previous:
            temp=folder/'guard.json.tmp';temp.write_text(json.dumps(review,ensure_ascii=False));os.replace(temp,path)
    if review['hold_required']:result['status']='requires_review'
    result['target_review']=review
    return result


def review_task(task,obs):
    from .target_lock import review_lock
    from .geometry import Calibration
    from robotarm_planning.handover import review_plan_targets
    if not task.get('target_lock'):return {'state':'requires_selection','reason':'请选择工具目标','execution_enabled':False}
    if task.get('task_kind')!='tool_handover':return review_lock(task['target_lock'],obs)
    if not task.get('handover'):return {'state':'requires_selection','reason':'交接区尚未标定或未选中稳定的接收手','execution_enabled':False}
    try:
        cfg=json.loads((ROOT/'config/planning.json').read_text());station=json.loads((ROOT/'config/vision_station.json').read_text())
        cal=Calibration(ROOT/'config/calibration/camera_to_base.json')
        context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
                 'camera_fixed':station.get('camera_fixed'),'setup_id':station.get('setup_id')}
        if not cal.compatible(obs.get('camera_serial'),context):raise ValueError('相机标定或安装位改变')
        return review_plan_targets({**task,'config':cfg,'T_base_camera':cal.matrix.tolist()},obs)
    except (ValueError,KeyError,TypeError,OSError) as exc:
        return {'state':'requires_review','reason':str(exc),'execution_enabled':False}


def start_job(task_id,profile_name):
    global _process
    from robotarm_planning.core import build_live_request
    from .geometry import Calibration
    from robotarm_planning.handover import review_plan_targets
    if not isinstance(task_id,str) or len(task_id)!=16 or any(c not in '0123456789abcdef' for c in task_id):raise ValueError('先生成并选择任务草案')
    task=json.loads((ROOT/'runtime/tasks'/(task_id+'.json')).read_text())
    obs=json.loads((ROOT/'runtime/vision/latest.json').read_text())
    lock=task.get('target_lock')
    if not lock:raise ValueError('没有锁定的具体目标')
    selection=review_task(task,obs)
    if selection['state']!='observation_consistent':raise ValueError(selection['reason'])
    cfg=json.loads((ROOT/'config/planning.json').read_text());station=json.loads((ROOT/'config/vision_station.json').read_text())
    if cfg.get('task_kind','pick_place')!=task.get('task_kind','pick_place'):raise ValueError('任务类型改变，请重新生成草案')
    req=build_live_request(obs,lock['track_id'],task['place_zone'],profile_name,cfg,Calibration(ROOT/'config/calibration/camera_to_base.json'),station,hand_track_id=task.get('hand_track_id'))
    # Keep the operator-selected reference, not a later nearby measurement, as the review anchor.
    req['target_lock']=lock
    review=review_plan_targets(req,obs)
    if review['state']!='observation_consistent':raise ValueError(review['reason'])
    with _lock:
        if _process is not None and _process.poll() is None:raise ValueError('另一个规划任务正在运行')
        job_id=secrets.token_hex(8);folder=ROOT/'runtime/planning/jobs'/job_id;folder.mkdir(parents=True)
        (folder/'request.json').write_text(json.dumps(req,indent=2,allow_nan=False))
        (folder/'result.json').write_text(json.dumps({'status':'queued','execution_enabled':False}))
        with (folder/'worker.log').open('w') as log:
            _process=subprocess.Popen([str(ROOT/'scripts/plan_task.sh'),'--request',str(folder/'request.json'),'--output',str(folder/'result.json')],cwd=ROOT,stdout=log,stderr=subprocess.STDOUT,start_new_session=True)
        process=_process
    def watchdog():
        try:code=process.wait(timeout=180)
        except subprocess.TimeoutExpired:
            os.killpg(process.pid,signal.SIGTERM)
            try:process.wait(timeout=3)
            except subprocess.TimeoutExpired:os.killpg(process.pid,signal.SIGKILL);process.wait()
            code=-1
        try:
            data=json.loads((folder/'result.json').read_text())
            if data.get('status') in ['queued','planning']:
                temp=folder/'result.json.tmp';temp.write_text(json.dumps({'status':'failed','error':f'Planner worker exited or timed out ({code})','execution_enabled':False}));os.replace(temp,folder/'result.json')
        except (OSError,ValueError):pass
    threading.Thread(target=watchdog,daemon=True).start()
    return {'job_id':job_id,'status':'queued','execution_enabled':False}
