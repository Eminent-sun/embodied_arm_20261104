#!/usr/bin/env python3
"""Verify the three-stage tabletop pickup using isolated MoveIt, without motion."""
import json
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'planning'),str(ROOT/'vision'),str(ROOT/'communication')]
import rclpy
import numpy as np
from robotarm_planning.core import make_waypoints,digest
from robotarm_planning.moveit_backend import MoveItPlanner


def main():
    if os.environ.get('ROS_DOMAIN_ID')!='74':raise SystemExit('Use isolated ROS domain 74')
    req=json.loads((ROOT/'runtime/planning/synthetic_request.json').read_text())
    cfg=req['config'];cfg['task_kind']='tabletop_pickup'
    profile={'surface_to_tcp_offset_base_m':[0.,0.,0.],
             'tcp_quaternion_xyzw':req['stages'][1]['tcp_pose_base']['quaternion_xyzw'],
             'clearance_m':.02,'object_size_m':[.01,.015,.008],
             'surface_to_object_center_base_m':[0.,0.,-.008]}
    cfg['grasp_profiles']={'synthetic_tool':profile}
    stages,obj=make_waypoints(req['point_base_m'],profile,None,cfg,pickup_only=True)
    req.update(task_kind='tabletop_pickup',profile='synthetic_tool',config_sha256=digest(cfg),stages=stages,object=obj,
               handover=None,note='Synthetic tabletop pickup fixture, not physical calibration')
    folder=ROOT/'runtime/planning';(folder/'pickup_request.json').write_text(json.dumps(req,indent=2))
    rclpy.init();planner=MoveItPlanner()
    try:
        start=planner.current();result=planner.plan(req,lambda stage:print(stage,flush=True))
        assert [s['name'] for s in result['segments']]==['approach','grasp','lift']
        assert result['terminal_state']=='hold_tool' and not result['automatic_release']
        assert np.allclose(start,planner.current())
        assert all(s['cartesian_fraction']>=.999999 for s in result['segments'] if s['method']=='cartesian')
        assert not any(e.get('gripper')=='open' and 'after' in e for e in result['events'])
        result.update(joint_state_unchanged=True,planner_camera_access=False,motor_execution=False)
        (folder/'pickup_result.json').write_text(json.dumps(result,indent=2))
        print(json.dumps({'status':result['status'],'segments':len(result['segments']),
                          'duration_s':result['duration_s'],'terminal_state':result['terminal_state']}))
    finally:planner.destroy_node();rclpy.shutdown()

if __name__=='__main__':main()
