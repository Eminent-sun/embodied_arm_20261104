"""Review a frozen observation reference, never continuously replace a motion goal."""
import math
import time
from copy import deepcopy


def current_point(obs,target,now=None):
    now=time.time() if now is None else now
    age=now-obs.get('captured_at_unix_s',0)
    point_age=target.get('coordinate_age_ms')
    return (obs.get('source_kind')=='live_camera' and 0<=age<.15
            and isinstance(point_age,(int,float)) and math.isfinite(point_age) and 0<=point_age+age*1000<=150
            and target.get('coordinate_usable') is True and target.get('coordinate_fresh') is True
            and target.get('observed_this_frame') is True)


def lock_target(obs,target):
    return deepcopy({'source_session_id':obs.get('source_session_id'),'track_id':target.get('track_id'),
            'class_name':target['class_name'],'frame_id':obs.get('frame_id'),
            'calibration_id':obs.get('calibration_id'),'station_setup_id':obs.get('station_setup_id'),
            'surface_point_base_m':target.get('surface_point_base_m'),
            'surface_point_camera_m':target.get('surface_point_camera_m'),
            'created_at_unix_s':time.time(),'max_deviation_m':.01,
            'measurement_qualified':bool(current_point(obs,target) and obs.get('base_calibration_valid')),
            'note':'Frozen surface sample for review; not a grasp pose or controller setpoint'})


def review_lock(lock,obs,now=None):
    now=time.time() if now is None else now
    result={'track_id':lock.get('track_id'),'state':'requires_review','execution_enabled':False}
    def stop(reason,state='requires_review'):
        return {**result,'state':state,'reason':reason}
    age=now-obs.get('captured_at_unix_s',0)
    if not 0<=age<.5:return stop('视觉数据过期，等待新鲜观测','waiting')
    if not lock.get('measurement_qualified'):return stop('选择时坐标尚不合格，需要重新选择确认')
    if lock.get('source_session_id')!=obs.get('source_session_id'):return stop('视觉会话改变，必须重新选择目标')
    if any(lock.get(k)!=obs.get(k) for k in ['calibration_id','station_setup_id']):return stop('标定或安装位改变')
    targets=[d for d in obs.get('detections',[]) if d.get('track_id')==lock.get('track_id') and d.get('class_name')==lock.get('class_name')]
    if len(targets)!=1:return stop('锁定目标丢失，不切换到同类其他物体','waiting')
    target=targets[0]
    if obs.get('hand_present'):return stop('手部仍在画面中或刚刚消失，需复核','waiting')
    if not current_point(obs,target,now):return stop('坐标暂存、跳变、过期或未稳定，等待复核','waiting')
    if not obs.get('base_calibration_valid'):return stop('尚无有效基座标定')
    before=lock.get('surface_point_base_m');after=target.get('surface_point_base_m')
    if before is None or after is None:return stop('缺少基座三维点')
    values=list(before)+list(after)
    if len(before)!=3 or len(after)!=3 or not all(isinstance(v,(float,int)) and math.isfinite(v) for v in values):return stop('无效三维点')
    distance=math.dist(before,after)
    if distance>lock['max_deviation_m']:return {**stop('目标相对确认位置移动，需重新确认'),'deviation_m':distance}
    return {**result,'state':'observation_consistent','reason':'目标观测一致；抓取规划与执行验收仍未完成','deviation_m':distance}
