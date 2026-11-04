#!/usr/bin/env python3
"""Two positions inside one FIXED synthetic region; actual MoveIt, no execution."""
import copy
import json
import os
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(ROOT/'planning'),str(ROOT/'vision'),str(ROOT/'communication')]
import numpy as np
import rclpy
from moveit_msgs.msg import PlanningScene
from robotarm_planning.core import digest, PlanningError
from robotarm_planning.handover import hand_geometry, make_handover_waypoints, PALM_IDS
from robotarm_planning.moveit_backend import MoveItPlanner


def request_fixture(shift=0.):
    req=json.loads((ROOT/'runtime/planning/synthetic_request.json').read_text())
    cfg=req['config'];cfg['task_kind']='tool_handover'
    target=copy.deepcopy(req['stages'][4]['tcp_pose_base']);target['position_m'][0]+=shift
    region={'reviewed':True,'body_scene_reviewed':True,'min_m':[-.3,-.3,.12],'max_m':[.05,.1,.45],
            'palm_to_tcp_offset_base_m':[0.,.15,0.],'tcp_quaternion_xyzw':target['quaternion_xyzw'],
            'approach_offset_base_m':[0.,0.,.02],'hand_margin_m':.025,'max_deviation_m':.01}
    cfg['handover_regions']={'synthetic_region':region}
    profile={'surface_to_tcp_offset_base_m':[0.,0.,0.],'tcp_quaternion_xyzw':req['stages'][1]['tcp_pose_base']['quaternion_xyzw'],
             'clearance_m':.02,'object_size_m':[.01,.015,.008],'surface_to_object_center_base_m':[0.,0.,-.008]}
    cfg['grasp_profiles']={'synthetic_tool':profile}
    palm=np.array(target['position_m'])-region['palm_to_tcp_offset_base_m']
    offsets=np.array([[(i%5-2)*.008,0.,(i//5-2)*.006] for i in range(21)])
    offsets-=np.mean(offsets[list(PALM_IDS)],axis=0)
    transform=np.array(req['T_base_camera'])
    camera=[(np.linalg.inv(transform)@np.r_[palm+p,1])[:3].tolist() for p in offsets]
    geometry=hand_geometry(camera,camera,transform,region)
    lock={'source_session_id':'synthetic_only','calibration_id':'synthetic_only','station_setup_id':'synthetic_only',
          'track_id':1,'frame_id':1,'camera_points':camera,'raw_camera_points':copy.deepcopy(camera),**copy.deepcopy(geometry)}
    handover={'region_name':'synthetic_region','hand_lock':lock,**geometry}
    stages,obj=make_handover_waypoints(req['point_base_m'],profile,handover,cfg)
    req.update(task_kind='tool_handover',handover=handover,profile='synthetic_tool',config_sha256=digest(cfg),
               stages=stages,object=obj,note='Synthetic hand and fixed region; not human handover commissioning. No camera or motor access.')
    return req


def main():
    if os.environ.get('ROS_DOMAIN_ID')!='74':raise SystemExit('Use isolated ROS domain 74')
    out=ROOT/'runtime/planning';rclpy.init();planner=MoveItPlanner()
    try:
        start=planner.current();results=[]
        for shift,suffix in [(0.,''),(.005,'_shifted')]:
            request=request_fixture(shift)
            (out/f'handover{suffix}_request.json').write_text(json.dumps(request,indent=2))
            result=planner.plan(request,lambda name:print('Planning handover',suffix,name,flush=True))
            assert [s['name'] for s in result['segments']]==['approach','grasp','lift','transfer','present']
            assert result['terminal_state']=='await_handover' and not result['automatic_release']
            assert np.allclose(start,planner.current())
            scene=planner.scene();assert 'aipc_hand' in [o.id for o in scene.world.collision_objects]
            acm=scene.allowed_collision_matrix
            # MoveIt serializes sparse exceptions: all-false rows may be absent.
            assert acm.default_entry_values[acm.default_entry_names.index('aipc_hand')] is False
            if 'aipc_hand' in acm.entry_names:
                assert not any(acm.entry_values[acm.entry_names.index('aipc_hand')].enabled)
            planner.contact(True);contact=planner.scene().allowed_collision_matrix
            assert contact.default_entry_values[contact.default_entry_names.index('aipc_hand')] is False
            if 'aipc_hand' in contact.entry_names:
                assert not any(contact.entry_values[contact.entry_names.index('aipc_hand')].enabled)
            planner.contact(False)
            result.update(camera_opened=False,motor_execution=False,joint_state_unchanged=True)
            (out/f'handover{suffix}_result.json').write_text(json.dumps(result,indent=2));results.append(result)
        np.testing.assert_allclose(np.array(results[1]['handover']['palm_base_m'])-results[0]['handover']['palm_base_m'],[.005,0.,0.],atol=1e-10)
        assert results[0]['handover_region']==results[1]['handover_region']
        # Prove the hand obstacle has NOT received grasp contact exemptions.
        block={'size_m':[.08,.08,.08],'pose':planner.fk(start)}
        scene=PlanningScene();scene.world.collision_objects=[planner.box('aipc_hand',block)];planner.apply(scene)
        rejected=False
        try:planner.valid(start)
        except PlanningError:rejected=True
        assert rejected,'Hand collision was not rejected'
        planner.configure_scene(request_fixture())
        export=out/'handover_export';export.mkdir(exist_ok=True)
        for i,segment in enumerate(results[0]['segments']):
            (export/f'{i+1:02d}_{segment["name"]}.json').write_text(json.dumps(segment['trajectory'],indent=2))
        (export/'manifest.json').write_text(json.dumps({'task_kind':'tool_handover','mode':'synthetic_test',
            'frame_id':'base_link','units':'m','handover':results[0]['handover'],'events':results[0]['events'],
            'execution_enabled':False,'controller_commands_sent':False,
            'note':'Separate segments; never concatenate across grasp/delivery/handover barriers.'},indent=2))
        report={'passed':True,'positions_tested':2,'fixed_region_unchanged':True,'hand_displacement_m':.005,
                'hand_collision_rejected':rejected,'segments_per_plan':5,'automatic_release':False,
                'joint_state_unchanged':True,'camera_opened':False,'controller_commands_sent':False,
                'duration_s':[r['duration_s'] for r in results]}
        (out/'handover_verification.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
    finally:planner.destroy_node();rclpy.shutdown()

if __name__=='__main__':main()
