#!/usr/bin/env python3
"""Exercise real MoveIt rejection paths and upload-only protocol compatibility."""
import copy
import json
import os
from pathlib import Path
import sys
import threading
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path[:0]=[str(ROOT/'planning'),str(ROOT/'vision'),str(ROOT/'communication')]
import rclpy
from robotarm_planning.moveit_backend import MoveItPlanner
from robotarm_planning.core import PlanningError,digest
from robotarm_link.protocol import Client,HOME,validate_trajectory
from robotarm_link.ps_simulator import serve


def main():
    if os.environ.get('ROS_DOMAIN_ID')!='74':raise SystemExit('Use isolated domain 74')
    folder=ROOT/'runtime/planning';request=json.loads((folder/'synthetic_request.json').read_text());plan=json.loads((folder/'synthetic_result.json').read_text())
    rclpy.init();node=MoveItPlanner();report={}
    try:
        start=node.current();node.configure_scene(request)
        try:node.ik({'position_m':[2.,2.,2.],'quaternion_xyzw':[0.,0.,0.,1.]},start)
        except PlanningError as e:report['unreachable_ik_rejected']=str(e)
        else:raise AssertionError('Unreachable IK accepted')
        stage=copy.deepcopy(request['stages'][1]);stage['link_pose_base']['position_m']=[.49,.49,.5]
        try:node.segment(stage,start,request['config'])
        except PlanningError as e:
            assert 'Cartesian path incomplete' in str(e);report['partial_cartesian_rejected']=str(e)
        else:raise AssertionError('Partial path accepted')
        blocked=copy.deepcopy(request);blocked['config']['scene_boxes'].append({'size_m':[.05,.05,.05],'pose':node.fk(start)})
        node.configure_scene(blocked)
        try:node.valid(start)
        except PlanningError as e:report['collision_rejected']=str(e)
        else:raise AssertionError('Collision accepted')
        report['joint_state_unchanged']=bool(np.allclose(node.current(),start))
    finally:node.configure_scene(request);node.destroy_node();rclpy.shutdown()
    exports=folder/'export';exports.mkdir(exist_ok=True)
    for stage in plan['segments']:
        validate_trajectory(stage['trajectory']);(exports/(stage['name']+'.json')).write_text(json.dumps(stage['trajectory'],indent=2))
    (exports/'manifest.json').write_text(json.dumps({'mode':'synthetic_test','execution_enabled':False,'plan_sha256':digest(plan),
        'frame_id':'base_link','joint_units':'rad','time_units':'s','stages':[s['name'] for s in plan['segments']],
        'gripper_events':plan['events'],'note':'Individual stage uploads require actual current feedback matching each stage start; gripper event acknowledgement and human execution confirmation are separate.'},indent=2))
    stop=threading.Event();ready=threading.Event();ports=[]
    def bound(port):ports.append(port);ready.set()
    server=threading.Thread(target=serve,kwargs={'port':0,'ready':bound,'stop_event':stop},daemon=True);server.start();assert ready.wait(3)
    client=Client(port=ports[0])
    try:
        assert client.request('hello')['mode']=='simulation'
        ack=client.request('upload',trajectory=plan['segments'][0]['trajectory']);status=client.request('status')
        assert status['state']=='prepared' and np.allclose(status['positions_rad'],HOME)
        report.update(first_stage_upload_ack=ack,ps_state=status['state'],execution_command_sent=False,exported_segments=6)
    finally:client.close();stop.set();server.join(3)
    (folder/'rejection_checks.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
if __name__=='__main__':main()
