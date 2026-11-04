import copy
import json
from pathlib import Path
import sys
import tempfile
import time
import unittest
import numpy as np
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'planning'))
from robotarm_planning.core import (PlanningError,pose_matrix,matrix_pose,link_pose,make_waypoints,
    build_live_request,validate_request,bounded_trajectory)
from robotarm_vision.geometry import Calibration
from robotarm_vision.quality import camera_signature
from robotarm_link.protocol import HOME,JOINTS


def fixture():
    intrinsic={'width':640,'height':480,'fx':500.,'fy':500.,'cx':320.,'cy':240.};dist=[0.]*8
    T=[[0.,-1.,0.,.4],[1.,0.,0.,0.],[0.,0.,1.,-.3],[0.,0.,0.,1.]]
    cal={'schema_version':2,'validated':True,'mounting':'eye_to_hand','units':'m','parent_frame':'base_link','child_frame':'camera_color_optical_frame',
         'calibration_id':'a'*64,'camera_serial':'fixture','physically_measured':True,'camera_fixed':True,'setup_id':'fixture',
         'camera_model_signature':camera_signature(intrinsic,dist),'T_base_camera':T}
    obs={'schema_version':2,'source_kind':'live_camera','source_session_id':'fixture','frame_id':2,'captured_at_unix_s':time.time(),
         'base_calibration_valid':True,'station_setup_id':'fixture','calibration_id':'a'*64,'camera_serial':'fixture','camera_intrinsics':intrinsic,'camera_distortion':dist,'hand_present':False,
         'detections':[{'track_id':4,'class_name':'pliers','coordinate_age_ms':0.,'coordinate_fresh':True,'coordinate_usable':True,
                        'observed_this_frame':True,'stable':True,'depth_quality':{'valid':True},'surface_point_camera_m':[.1,.2,.5],
                        'surface_point_base_m':[9.,9.,9.]}]}
    pose={'position_m':[.3,0.,.2],'quaternion_xyzw':[0.,0.,0.,1.]}
    cfg={'schema_version':1,'mode':'measured','validated':True,'robot_model_reviewed':True,'robot_description_sha256':'b'*64,'frame_id':'base_link','tip_link':'Link6','setup_id':'fixture','calibration_id':'a'*64,
         'workspace_min_m':[-.5,-.5,0.],'workspace_max_m':[.8,.5,.8],'max_joint_velocity_rad_s':.25,'max_joint_acceleration_rad_s2':.5,
         'gripper':{'tcp_calibrated':True,'link_to_tcp':{'position_m':[0.,0.,.05],'quaternion_xyzw':[0.,0.,0.,1.]},
                    'collision_boxes':[{'size_m':[.01,.01,.01],'pose':pose}]},
         'scene_boxes':[{'size_m':[.4,.4,.01],'pose':pose}],
         'grasp_profiles':{'test':{'reviewed':True,'classes':['pliers'],'surface_to_tcp_offset_base_m':[0.,0.,.02],
                                 'tcp_quaternion_xyzw':[0.,0.,0.,1.],'clearance_m':.04,'object_size_m':[.02,.02,.02],
                                 'surface_to_object_center_base_m':[0.,0.,-.01]}},'place_zones':{'bin':{'tcp_pose':pose}}}
    return cal,obs,cfg,{'camera_fixed':True,'setup_id':'fixture'}


class PlanningGeometryTest(unittest.TestCase):
    def test_tabletop_pickup_needs_no_receiver_or_place_zone(self):
        cal,obs,cfg,station=fixture();cfg.update(task_kind='tabletop_pickup',place_zones={})
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cal.json';path.write_text(json.dumps(cal));calibration=Calibration(path)
            req=build_live_request(obs,4,'','test',cfg,calibration,station);validate_request(req)
            self.assertEqual([s['name'] for s in req['stages']],['approach','grasp','lift'])
            self.assertIsNone(req['handover']);self.assertFalse(req['execution_enabled'])
            obs['hand_present']=True
            with self.assertRaises(PlanningError):build_live_request(obs,4,'','test',cfg,calibration,station)
            req['stages'].append(copy.deepcopy(req['stages'][-1]))
            with self.assertRaises(PlanningError):validate_request(req)

    def test_tcp_offset_and_rotation_roundtrip(self):
        pose={'position_m':[.2,.3,.4],'quaternion_xyzw':[0.,0.,float(np.sqrt(.5)),float(np.sqrt(.5))]}
        offset={'position_m':[.1,0.,0.],'quaternion_xyzw':[0.,0.,0.,1.]}
        actual=link_pose(pose,offset)
        np.testing.assert_allclose(actual['position_m'],[.2,.2,.4],atol=1e-8)
        np.testing.assert_allclose(pose_matrix(matrix_pose(pose_matrix(pose))),pose_matrix(pose),atol=1e-8)
        with self.assertRaises(PlanningError):pose_matrix({**pose,'quaternion_xyzw':[0,0,0,0]})

    def test_live_conversion_recomputes_base_and_does_not_trust_cached_xyz(self):
        cal,obs,cfg,station=fixture()
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cal.json';path.write_text(json.dumps(cal));calibration=Calibration(path)
            req=build_live_request(obs,4,'bin','test',cfg,calibration,station)
            np.testing.assert_allclose(req['point_base_m'],[.2,.1,.2]);validate_request(req)
            self.assertEqual(len(req['stages']),6);self.assertFalse(req['execution_enabled'])
            self.assertAlmostEqual(req['stages'][1]['link_pose_base']['position_m'][2],.17)
            self.assertTrue(req['target_lock']['measurement_qualified'])
            obs['detections'][0]['surface_point_camera_m'][0]=2
            self.assertEqual(req['target_lock']['surface_point_camera_m'],[.1,.2,.5])

    def test_refuses_uncalibrated_stale_hands_and_unreviewed_grasp(self):
        cal,obs,cfg,station=fixture()
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'cal.json';path.write_text(json.dumps(cal));c=Calibration(path)
            mutations=[('stale',lambda o,s,g:o.update(captured_at_unix_s=time.time()-1)),
                       ('hand',lambda o,s,g:o.update(hand_present=True)),
                       ('unfixed',lambda o,s,g:s.update(camera_fixed=False)),
                       ('profile',lambda o,s,g:g['grasp_profiles']['test'].update(reviewed=False)),
                       ('tcp',lambda o,s,g:g['gripper'].update(tcp_calibrated=False)),
                       ('lost',lambda o,s,g:o['detections'][0].update(track_id=5)),
                       ('held',lambda o,s,g:o['detections'][0].update(coordinate_fresh=False)),
                       ('offline',lambda o,s,g:o.update(source_kind='offline_replay'))]
            for name,mutate in mutations:
                with self.subTest(name=name):
                    o,s,g=copy.deepcopy(obs),copy.deepcopy(station),copy.deepcopy(cfg);mutate(o,s,g)
                    with self.assertRaises(PlanningError):build_live_request(o,4,'bin','test',g,c,s)

    def test_workspace_and_config_tampering_are_rejected(self):
        cal,obs,cfg,station=fixture()
        with self.assertRaises(PlanningError):make_waypoints([2.,0.,.2],cfg['grasp_profiles']['test'],cfg['place_zones']['bin'],cfg)
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'c.json';path.write_text(json.dumps(cal));req=build_live_request(obs,4,'bin','test',cfg,Calibration(path),station)
            req['stages'][0]['link_pose_base']['position_m'][2]+=.1
            with self.assertRaises(PlanningError):validate_request(req)
            req['config']['max_joint_velocity_rad_s']=10
            with self.assertRaises(PlanningError):validate_request(req)

    def test_export_respects_ps_joint_order_and_sampled_speed_limits(self):
        q=HOME.copy();q[0]+=.1;q[2]-=.05
        path=[{'positions':HOME,'time_s':0.},{'positions':q,'time_s':.01},{'positions':HOME,'time_s':.02}]
        out=bounded_trajectory(JOINTS,path,.25,.5)
        self.assertLessEqual(out['sampled_peak_velocity_rad_s'],.25)
        self.assertLessEqual(out['sampled_peak_acceleration_rad_s2'],.5)
        self.assertGreater(out['points'][-1]['time_s'],.02)
        path[1]['positions'][2]=10.
        with self.assertRaises(ValueError):bounded_trajectory(JOINTS,path,.25,.5)
