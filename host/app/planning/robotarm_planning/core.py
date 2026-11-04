"""Geometry and plan contracts. No ROS, camera, GPU or motor imports."""
import copy
import hashlib
import json
import math
import time
import numpy as np
from robotarm_link.protocol import JOINTS,LIMITS,validate_trajectory


class PlanningError(ValueError):pass


def vector(value,n,label):
    if not isinstance(value,list) or len(value)!=n or any(type(v) not in (float,int) or not math.isfinite(v) for v in value):
        raise PlanningError(f'{label}: expected {n} finite numbers')
    return np.array(value,float)


def pose_matrix(pose):
    p=vector(pose['position_m'],3,'position');q=vector(pose['quaternion_xyzw'],4,'quaternion')
    if abs(np.linalg.norm(q)-1)>.001:raise PlanningError('Quaternion must be unit length')
    x,y,z,w=q/np.linalg.norm(q)
    m=np.eye(4);m[:3,3]=p
    m[:3,:3]=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],
              [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],
              [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    return m


def matrix_pose(m):
    # Robust eigenvector form, including rotations close to pi.
    r=m[:3,:3];k=np.array([[r[0,0]-r[1,1]-r[2,2],r[1,0]+r[0,1],r[2,0]+r[0,2],r[2,1]-r[1,2]],
        [r[1,0]+r[0,1],r[1,1]-r[0,0]-r[2,2],r[2,1]+r[1,2],r[0,2]-r[2,0]],
        [r[2,0]+r[0,2],r[2,1]+r[1,2],r[2,2]-r[0,0]-r[1,1],r[1,0]-r[0,1]],
        [r[2,1]-r[1,2],r[0,2]-r[2,0],r[1,0]-r[0,1],np.trace(r)]])/3
    _,v=np.linalg.eigh(k);q=v[:,-1]
    if q[3]<0:q=-q
    return {'position_m':m[:3,3].tolist(),'quaternion_xyzw':q.tolist()}


def link_pose(tcp_pose,link_to_tcp):
    return matrix_pose(pose_matrix(tcp_pose)@np.linalg.inv(pose_matrix(link_to_tcp)))


def digest(data):return hashlib.sha256(json.dumps(data,sort_keys=True,allow_nan=False).encode()).hexdigest()


def validate_config(cfg):
    if cfg.get('schema_version')!=1 or cfg.get('frame_id')!='base_link' or cfg.get('tip_link')!='Link6':raise PlanningError('Expected base_link / Link6 configuration')
    lo=vector(cfg['workspace_min_m'],3,'workspace min');hi=vector(cfg['workspace_max_m'],3,'workspace max')
    if np.any(hi<=lo) or np.max(np.abs([lo,hi]))>5:raise PlanningError('Invalid workspace bounds')
    gripper=cfg['gripper'];pose_matrix(gripper['link_to_tcp'])
    if not gripper.get('collision_boxes'):raise PlanningError('Gripper collision envelope missing')
    for box in cfg['scene_boxes']+gripper['collision_boxes']:
        size=vector(box['size_m'],3,'box size')
        if np.any(size<=0) or np.any(size>5):raise PlanningError('Invalid box dimensions')
        pose_matrix(box['pose'])
    if not cfg['scene_boxes']:raise PlanningError('Measured table/collision scene missing')
    if not 0<cfg['max_joint_velocity_rad_s']<=.5 or not 0<cfg['max_joint_acceleration_rad_s2']<=1:raise PlanningError('Invalid joint speed/acceleration budget')
    return cfg


def make_waypoints(surface,profile,zone,cfg,pickup_only=False):
    surface=vector(surface,3,'surface');offset=vector(profile['surface_to_tcp_offset_base_m'],3,'grasp offset')
    q=profile['tcp_quaternion_xyzw'];grasp={'position_m':(surface+offset).tolist(),'quaternion_xyzw':q};pose_matrix(grasp)
    place=copy.deepcopy(grasp if pickup_only else zone['tcp_pose']);pose_matrix(place)
    clearance=profile['clearance_m']
    if not isinstance(clearance,(int,float)) or not .01<=clearance<=.3:raise PlanningError('Clearance must be 10..300 mm')
    stages=[]
    for name,pose,lift,method in [('approach',grasp,clearance,'ompl'),('grasp',grasp,0,'cartesian'),
            ('lift',grasp,clearance,'cartesian'),('transfer',place,clearance,'ompl'),
            ('place',place,0,'cartesian'),('retreat',place,clearance,'cartesian')]:
        if pickup_only and name not in ['approach','grasp','lift']:continue
        tcp=copy.deepcopy(pose);tcp['position_m'][2]+=lift
        p=np.array(tcp['position_m'])
        if np.any(p<np.array(cfg['workspace_min_m'])) or np.any(p>np.array(cfg['workspace_max_m'])):raise PlanningError(f'{name}: target outside measured workspace')
        stages.append({'name':name,'method':method,'tcp_pose_base':tcp,'link_pose_base':link_pose(tcp,cfg['gripper']['link_to_tcp'])})
    size=vector(profile['object_size_m'],3,'object envelope')
    if np.any(size<=0) or np.any(size>.4):raise PlanningError('Object collision envelope invalid')
    center=surface+vector(profile['surface_to_object_center_base_m'],3,'object center offset')
    return stages,{'size_m':size.tolist(),'pose':{'position_m':center.tolist(),'quaternion_xyzw':[0.,0.,0.,1.]}}


def build_live_request(obs,track_id,zone_name,profile_name,cfg,calibration,station,now=None,hand_track_id=None):
    from robotarm_vision.target_lock import current_point,lock_target
    now=time.time() if now is None else now
    if cfg.get('mode')!='measured' or cfg.get('validated') is not True:raise PlanningError('实测规划配置尚未验收')
    validate_config(cfg)
    if cfg['gripper'].get('tcp_calibrated') is not True:raise PlanningError('夹爪 TCP 尚未标定')
    if cfg.get('robot_model_reviewed') is not True or not isinstance(cfg.get('robot_description_sha256'),str) or len(cfg['robot_description_sha256'])!=64:raise PlanningError('真实机械臂与末端模型尚未审核绑定')
    if cfg.get('setup_id')!=station.get('setup_id') or cfg.get('calibration_id')!=calibration.data.get('calibration_id'):raise PlanningError('规划配置与相机标定安装位不一致')
    if obs.get('base_calibration_valid') is not True or obs.get('station_setup_id')!=station.get('setup_id') or obs.get('calibration_id')!=calibration.data.get('calibration_id'):raise PlanningError('观测来自不同或未标定的安装位')
    if type(track_id) is not int:raise PlanningError('必须选择具体目标 ID')
    handover=None
    if cfg.get('task_kind')=='tool_handover':
        from .handover import freeze_hand,make_handover_waypoints
        # Check the actual camera binding before deriving any hand base point.
        context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
                 'setup_id':station.get('setup_id'),'camera_fixed':station.get('camera_fixed')}
        if not calibration.compatible(obs.get('camera_serial'),context):raise PlanningError('相机安装位标定无效')
        handover=freeze_hand(obs,cfg,zone_name,calibration.matrix,hand_track_id,now)
    elif obs.get('hand_present') is not False:raise PlanningError('手部存在或状态未知')
    matches=[d for d in obs.get('detections',[]) if d.get('track_id')==track_id]
    if len(matches)!=1:raise PlanningError('锁定目标丢失或 ID 不唯一')
    target=matches[0]
    if not current_point(obs,target,now) or not target.get('stable') or not target.get('depth_quality',{}).get('valid'):raise PlanningError('目标深度过期、跳变或未稳定')
    context={'intrinsic':obs.get('camera_intrinsics'),'distortion':obs.get('camera_distortion'),
             'setup_id':station.get('setup_id'),'camera_fixed':station.get('camera_fixed')}
    point=calibration.point_in_base(target.get('surface_point_camera_m'),obs.get('camera_serial'),context)
    if point is None:raise PlanningError('相机到基座标定无效；不能生成基座目标')
    profile=cfg['grasp_profiles'].get(profile_name);zone=cfg.get('place_zones',{}).get(zone_name)
    if not profile or profile.get('reviewed') is not True or target['class_name'] not in profile.get('classes',[]):raise PlanningError('缺少此工具的已审核抓取方向、偏移与包络')
    if handover:
        stages,obj=make_handover_waypoints(point,profile,handover,cfg)
    elif cfg.get('task_kind')=='tabletop_pickup':
        stages,obj=make_waypoints(point,profile,None,cfg,pickup_only=True)
    else:
        if not zone:raise PlanningError('缺少已测量放置位姿')
        stages,obj=make_waypoints(point,profile,zone,cfg)
    locked_obs=copy.deepcopy(obs);locked_obs['base_calibration_valid']=True
    locked_obs['calibration_id']=calibration.data['calibration_id'];locked_obs['station_setup_id']=station['setup_id']
    locked_target=copy.deepcopy(target);locked_target['surface_point_base_m']=point
    return {'schema_version':1,'mode':'measured','created_at_unix_s':now,'expires_at_unix_s':now+30,
            'frame_id':'base_link','units':'m','target_lock':lock_target(locked_obs,locked_target),
            'point_camera_m':copy.deepcopy(target['surface_point_camera_m']),'point_base_m':point,
            'T_base_camera':calibration.matrix.tolist(),'calibration_id':calibration.data['calibration_id'],
            'profile':profile_name,'place_zone':zone_name,'stages':stages,'object':obj,
            'task_kind':cfg.get('task_kind','pick_place'),'handover':handover,
            'config':copy.deepcopy(cfg),'config_sha256':digest(cfg),'execution_enabled':False}


def validate_request(req):
    if req.get('schema_version')!=1 or req.get('mode') not in ['measured','synthetic_test'] or req.get('execution_enabled') is not False:raise PlanningError('Invalid plan-only request')
    cfg=validate_config(req['config'])
    if digest(cfg)!=req['config_sha256']:raise PlanningError('Configuration changed')
    if req['mode']=='measured' and (cfg.get('mode')!='measured' or cfg.get('validated') is not True or not req.get('target_lock',{}).get('measurement_qualified')):raise PlanningError('Unqualified measured request')
    if req['mode']=='synthetic_test' and cfg.get('mode')!='synthetic_test':raise PlanningError('Simulation configuration required')
    if req.get('frame_id')!='base_link' or req.get('units')!='m':raise PlanningError('Invalid coordinate frame/units')
    transform=np.asarray(req.get('T_base_camera'),float)
    if transform.shape!=(4,4) or not np.isfinite(transform).all() or not np.allclose(transform[3],[0,0,0,1]) or not np.allclose(transform[:3,:3].T@transform[:3,:3],np.eye(3),atol=1e-5) or not np.isclose(np.linalg.det(transform[:3,:3]),1):raise PlanningError('Invalid camera-to-base rigid transform')
    camera=vector(req['point_camera_m'],3,'camera point');base=vector(req['point_base_m'],3,'base point')
    if not np.allclose((transform@np.r_[camera,1])[:3],base,atol=1e-6):raise PlanningError('Camera/base coordinate conversion mismatch')
    kind=req.get('task_kind','pick_place')
    if kind not in ['pick_place','tool_handover','tabletop_pickup']:raise PlanningError('Unknown task kind')
    if cfg.get('task_kind','pick_place')!=kind:raise PlanningError('Task kind differs from configuration')
    expected=['approach','grasp','lift','transfer','present'] if kind=='tool_handover' else ['approach','grasp','lift','transfer','place','retreat']
    if kind=='tabletop_pickup':expected=['approach','grasp','lift']
    if [s['name'] for s in req['stages']]!=expected:raise PlanningError('Incomplete task sequence')
    if kind=='tabletop_pickup':
        stages,obj=make_waypoints(req['point_base_m'],cfg['grasp_profiles'][req['profile']],None,cfg,pickup_only=True)
        if digest(stages)!=digest(req['stages']) or digest(obj)!=digest(req['object']):raise PlanningError('Pickup path differs from selected target')
    if kind=='tool_handover':
        from .handover import region_config,hand_geometry,make_handover_waypoints
        handover=req['handover'];lock=handover['hand_lock'];region=region_config(cfg,handover['region_name'])
        geometry=hand_geometry(lock['camera_points'],lock['raw_camera_points'],transform,region)
        for key in geometry:
            if digest(geometry[key])!=digest(handover[key]) or digest(geometry[key])!=digest(lock[key]):raise PlanningError('Hand geometry or region target changed')
        if req['mode']=='measured' and any(lock.get(k)!=req['target_lock'].get(k) for k in ['source_session_id','station_setup_id','calibration_id']):raise PlanningError('Tool and hand provenance differs')
        stages,obj=make_handover_waypoints(req['point_base_m'],cfg['grasp_profiles'][req['profile']],handover,cfg)
        if digest(stages)!=digest(req['stages']) or digest(obj)!=digest(req['object']):raise PlanningError('Handover path differs from frozen target')
    for s in req['stages']:
        if s['method'] not in ['ompl','cartesian']:raise PlanningError('Invalid planning method')
        pose_matrix(s['tcp_pose_base']);pose_matrix(s['link_pose_base'])
        if not np.allclose(pose_matrix(s['link_pose_base']),pose_matrix(link_pose(s['tcp_pose_base'],cfg['gripper']['link_to_tcp'])),atol=1e-8):raise PlanningError('TCP conversion mismatch')
        p=np.array(s['tcp_pose_base']['position_m'])
        if np.any(p<cfg['workspace_min_m']) or np.any(p>cfg['workspace_max_m']):raise PlanningError('Out of workspace')
    return req


def bounded_trajectory(names,points,max_velocity,max_acceleration):
    if sorted(names)!=sorted(JOINTS):raise PlanningError('Expected six named joints')
    order=[names.index(n) for n in JOINTS]
    q=np.array([[p['positions'][i] for i in order] for p in points],float)
    if len(q)<2 or len(q)>1000 or not np.isfinite(q).all():raise PlanningError('Invalid trajectory samples')
    t=np.array([p['time_s'] for p in points],float);t-=t[0]
    if not np.isfinite(t).all():raise PlanningError('Invalid trajectory time')
    if np.any(np.diff(t)<=0):
        # Cartesian services may return an unparameterized path. This fallback
        # limits sampled position slopes; it is NOT a commissioned PL interpolator.
        t=np.r_[0,np.cumsum(np.maximum(.04,np.max(np.abs(np.diff(q,axis=0)),axis=1)/max_velocity))]
    dt=np.diff(t);v=np.diff(q,axis=0)/dt[:,None]
    a=np.diff(np.vstack([np.zeros((1,6)),v,np.zeros((1,6))]),axis=0)/np.r_[dt[0]/2,(dt[:-1]+dt[1:])/2,dt[-1]/2][:,None]
    scale=max(1.,float(np.max(np.abs(v)))/max_velocity,math.sqrt(float(np.max(np.abs(a)))/max_acceleration))*1.01
    t*=scale
    out={'joint_names':JOINTS,'points':[{'time_s':float(ti),'positions_rad':qi.tolist()} for ti,qi in zip(t,q)],
         'sampled_peak_velocity_rad_s':float(np.max(np.abs(v))/scale),
         'sampled_peak_acceleration_rad_s2':float(np.max(np.abs(a))/scale**2),
         'interpolation':'position_samples; physical PL interpolation and dynamic limits require commissioning'}
    validate_trajectory(out,max_velocity=max_velocity)
    return out
