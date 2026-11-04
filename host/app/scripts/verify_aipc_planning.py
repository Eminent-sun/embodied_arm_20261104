#!/usr/bin/env python3
"""Isolated MoveIt test with labelled synthetic geometry, never a camera calibration."""
import copy
import json
import os
from pathlib import Path
import sys
import time
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'planning'),str(ROOT/'vision'),str(ROOT/'communication')]
import rclpy
import numpy as np
from robotarm_planning.moveit_backend import MoveItPlanner
from robotarm_planning.core import make_waypoints,pose_matrix,matrix_pose,digest


def main():
    if os.environ.get('ROS_DOMAIN_ID')!='74':raise SystemExit('Run in isolated test ROS domain 74')
    out=ROOT/'runtime/planning';out.mkdir(exist_ok=True)
    rclpy.init();planner=MoveItPlanner()
    try:
        offset={'position_m':[0.,0.,.24],'quaternion_xyzw':[0.,0.,0.,1.]}
        pick_link=planner.fk([.12,1.70,-.22,.10,1.35,.08]);place_link=planner.fk([-.12,1.80,-.30,-.08,1.25,-.10])
        pick=matrix_pose(pose_matrix(pick_link)@pose_matrix(offset));place=matrix_pose(pose_matrix(place_link)@pose_matrix(offset))
        cfg={'schema_version':1,'mode':'synthetic_test','validated':False,'frame_id':'base_link','tip_link':'Link6',
             'workspace_min_m':[-.5,-.5,-.1],'workspace_max_m':[.5,.5,.6],
             'max_joint_velocity_rad_s':.25,'max_joint_acceleration_rad_s2':.5,
             'gripper':{'tcp_calibrated':False,'link_to_tcp':offset,'collision_boxes':[
                 {'size_m':[.01,.01,.02],'pose':{'position_m':[0.,0.,.215],'quaternion_xyzw':[0.,0.,0.,1.]}}]},
             'scene_boxes':[{'size_m':[.3,.4,.02],'pose':{'position_m':[-.25,0.,.06],'quaternion_xyzw':[0.,0.,0.,1.]}}]}
        profile={'surface_to_tcp_offset_base_m':[0.,0.,0.],'tcp_quaternion_xyzw':pick['quaternion_xyzw'],
                 'clearance_m':.02,'object_size_m':[.01,.015,.008],'surface_to_object_center_base_m':[0.,0.,-.008]}
        stages,obj=make_waypoints(pick['position_m'],profile,{'tcp_pose':place},cfg)
        # Explicitly synthetic camera->base transform exercises the algebra, not a physical calibration.
        T=np.eye(4);T[:3,:3]=[[0.,-1.,0.],[1.,0.,0.],[0.,0.,1.]];T[:3,3]=[.1,-.2,-.3]
        camera=(np.linalg.inv(T)@np.r_[pick['position_m'],1])[:3]
        reconstructed=(T@np.r_[camera,1])[:3]
        assert np.allclose(reconstructed,pick['position_m'])
        request={'schema_version':1,'mode':'synthetic_test','frame_id':'base_link','units':'m','execution_enabled':False,
                 'config':cfg,'config_sha256':digest(cfg),'stages':stages,'object':obj,'point_camera_m':camera.tolist(),
                 'point_base_m':reconstructed.tolist(),'T_base_camera':T.tolist(),'calibration_id':'synthetic_only',
                 'note':'FK-generated poses and synthetic camera transform; no physical calibration or hardware motion.'}
        (out/'synthetic_request.json').write_text(json.dumps(request,indent=2))
        start=planner.current();result=planner.plan(request,lambda name:print('Planning',name,flush=True))
        end=planner.current();assert np.allclose(start,end)
        result.update(camera_opened=False,motor_execution=False,joint_state_unchanged=True,synthetic_coordinate_roundtrip_error_m=float(np.linalg.norm(reconstructed-np.array(pick['position_m']))))
        (out/'synthetic_result.json').write_text(json.dumps(result,indent=2));print(json.dumps({'status':result['status'],'segments':len(result['segments']),'duration_s':result['duration_s'],'joint_state_unchanged':True},indent=2))
    finally:planner.destroy_node();rclpy.shutdown()
if __name__=='__main__':main()
