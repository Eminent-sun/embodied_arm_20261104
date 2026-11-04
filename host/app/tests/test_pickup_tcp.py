"""Synthetic geometry/transport tests only: never open a camera or enable motion."""
import copy
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
import numpy as np
from robotarm_vision.pickup import PickupService
from robotarm_vision.quality import camera_signature
from robotarm_link.cartesian import fingerprint, validate_target
from robotarm_link.protocol import Client, ProtocolError, HOME
from robotarm_link.ps_simulator import serve, Simulator


class PickupTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.k = {'width':640,'height':480,'fx':600.,'fy':600.,'cx':320.,'cy':240.}
        self.contract = {'schema_version':1,'validated':True,'frame_id':'base_link','units':'mm',
            'base_definition':'SYNTHETIC TEST ONLY','robot_model_id':'synthetic','tcp_id':'test-gripper',
            'workspace_min_mm':[-400,-400,0],'workspace_max_mm':[400,400,400],
            'profiles':{'pliers':{'validated':True,'surface_to_tcp_base_mm':[0,0,5],
                'orientation_xyzw':[1,0,0,0],'approach_height_mm':50,'lift_height_mm':60}}}
        self.config = {'ps_host':'127.0.0.1','ps_port':7010,'contract':self.contract}
        self.write('config/pickup_tcp.json',self.config)
        self.write('config/vision_station.json',{'camera_fixed':True,'setup_id':'test-setup'})
        self.cal = {'schema_version':2,'validated':True,'mounting':'eye_to_hand','units':'m',
            'parent_frame':'base_link','child_frame':'camera_color_optical_frame','calibration_id':'a'*64,
            'physically_measured':True,'camera_fixed':True,'setup_id':'test-setup','camera_serial':'test-camera',
            'camera_model_signature':camera_signature(self.k,[0]*8),
            'T_base_camera':[[1,0,0,.2],[0,-1,0,.1],[0,0,-1,.7],[0,0,0,1]]}
        self.write('config/calibration/camera_to_base.json',self.cal)
        self.obs = {'source_kind':'live_camera','source_session_id':'fixture-not-real','units':'m',
            'frame_id':12,'camera_intrinsics':self.k,'camera_distortion':[0]*8,'camera_serial':'test-camera',
            'base_calibration_valid':True,'calibration_id':'a'*64,'station_setup_id':'test-setup','hand_present':False,
            'detections':[{'track_id':7,'class_name':'pliers','stable':True,'box_xyxy':[300,200,400,300],
                'surface_point_camera_m':[.03,.01,.6],'coordinate_age_ms':0,'coordinate_fresh':True,
                'coordinate_usable':True,'observed_this_frame':True}]}
        self.depth = np.full((480,640),.6,np.float32)
        self.refresh(snapshot=True)
        self.service = PickupService(self.root)

    def write(self,path,value):
        file = self.root/path;file.parent.mkdir(parents=True,exist_ok=True)
        file.write_text(json.dumps(value))

    def refresh(self,snapshot=False):
        self.obs['captured_at_unix_s']=time.time()-.001
        self.write('runtime/vision/latest.json',self.obs)
        if snapshot:
            np.savez(self.root/'runtime/vision/depth.npz',depth_m=self.depth,
                     color_bgr=np.zeros((480,640,3),np.uint8),metadata=np.array(json.dumps(self.obs)))

    def choose(self,pixel=None):
        self.refresh(snapshot=True)
        snap=self.service.freeze(7)
        self.refresh()
        return self.service.choose(snap['snapshot_id'],pixel or [330,250])

    def server(self,contract=None):
        ready=threading.Event();stop=threading.Event();ports=[]
        def cb(port):ports.append(port);ready.set()
        t=threading.Thread(target=serve,kwargs={'port':0,'ready':cb,'stop_event':stop,
            'cartesian_contract':contract or self.contract},daemon=True)
        t.start();self.assertTrue(ready.wait(3))
        def cleanup():stop.set();t.join(3)
        self.addCleanup(cleanup)
        self.config['ps_port']=ports[0];self.write('config/pickup_tcp.json',self.config)
        return ports[0]

    def test_transform_direction_mm_tcp_offset_and_projection(self):
        result=self.choose()
        self.assertIsNone(result['blocked'])
        t=result['target']
        np.testing.assert_allclose(t['surface_base_mm'],[210,90,100],atol=.001)
        np.testing.assert_allclose(t['position_mm'],[210,90,105],atol=.001)
        self.assertEqual(t['approach_mm'],[210,90,155])
        self.assertEqual(t['lift_mm'],[210,90,165])
        np.testing.assert_allclose(result['tcp_pixel'],[330.084,250.084],atol=.002)
        self.assertEqual(validate_target(t,self.contract),t)
        self.assertNotEqual(t['position_mm'],[30,10,600])

    def test_unfixed_camera_never_yields_base_goal(self):
        self.write('config/vision_station.json',{'camera_fixed':False,'setup_id':'test-setup'})
        result=self.choose();self.assertIsNone(result['target']);self.assertIsNotNone(result['surface_camera_m'])
        with self.assertRaises(ValueError):self.service.send('x',True)

    def test_bad_serial_or_changed_model_block_binding(self):
        for field,value in [('camera_serial','other'),('calibration_id','b'*64),('station_setup_id','other')]:
            original=self.obs[field];self.obs[field]=value
            self.assertIsNone(self.choose()['target']);self.obs[field]=original
        self.obs['camera_intrinsics']={**self.k,'fx':610.}
        self.assertIsNone(self.choose()['target'])

    def test_snapshot_is_same_frame_and_stale_freeze_rejected(self):
        self.obs['captured_at_unix_s']=time.time()-2
        self.write('runtime/vision/latest.json',self.obs)
        # Snapshot itself is current; latest changes cannot alter its captured RGB-D.
        snap=self.service.freeze(7)
        self.assertEqual(snap['frame_id'],12)
        with self.assertRaises(ValueError):self.service.choose(snap['snapshot_id'],[330,250])
        with np.load(self.root/'runtime/vision/depth.npz') as d:
            color=d['color_bgr']
        np.savez(self.root/'runtime/vision/depth.npz',depth_m=self.depth,color_bgr=color,metadata=np.array(json.dumps(self.obs)))
        with self.assertRaises(ValueError):self.service.freeze(7)

    def test_click_requires_tool_surface_and_good_metric_depth(self):
        self.choose()
        with self.assertRaises(ValueError):self.service.choose(self.service.snapshot['id'],[10,10])
        self.assertIsNone(self.service.candidate)
        self.depth[249:252,329:332]=0
        with self.assertRaises(ValueError):self.choose()
        self.depth[:]=.6;self.depth[250,330]=.8
        with self.assertRaises(ValueError):self.choose()

    def test_live_synthetic_replay_and_held_cannot_be_submitted(self):
        for key,value in [('coordinate_fresh',False),('coordinate_usable',False),('observed_this_frame',False)]:
            self.obs['detections'][0][key]=value
            with self.assertRaises(ValueError):self.choose()
            self.obs['detections'][0][key]=True
        self.obs['source_kind']='offline_replay'
        with self.assertRaises(ValueError):self.choose()

    def test_reject_moving_missing_changed_identity_or_hand_at_send(self):
        t=self.choose()['target'];original=copy.deepcopy(self.obs)
        for change in ('moved','missing','session','hand','box'):
            self.obs=copy.deepcopy(original)
            if change=='moved':self.obs['detections'][0]['surface_point_camera_m'][0]+=.03
            if change=='missing':self.obs['detections']=[]
            if change=='session':self.obs['source_session_id']='new'
            if change=='hand':self.obs['hand_present']=True
            if change=='box':self.obs['detections'][0]['box_xyxy']=[310,210,410,310]
            self.refresh()
            with self.assertRaises(ValueError):self.service.send(t['target_id'],True)
        self.assertIsNone(self.service.last_ack)

    def test_full_tcp_ack_then_dropout_does_not_rewrite_or_resend(self):
        port=self.server();t=self.choose()['target'];self.refresh()
        ack=self.service.send(t['target_id'],True)
        self.assertEqual(ack['target'],t);self.assertFalse(ack['execution_started'])
        self.obs['detections']=[];self.refresh()
        with patch('robotarm_vision.pickup.Client',side_effect=AssertionError('Must not resend')):
            self.assertEqual(self.service.send(t['target_id'],True),ack)
        self.assertEqual(self.service.status()['last_ack'],ack)
        client=Client(port=port)
        try:
            self.assertEqual(client.request('cartesian_status')['target'],t)
            self.assertEqual(client.request('status')['positions_rad'],HOME)
            with self.assertRaises(ProtocolError):client.request('execute',target_id=t['target_id'],confirmed=True)
        finally:client.close()
        self.assertEqual(json.loads((self.root/'runtime/pickup/last_ack.json').read_text())['target'],t)
        self.assertEqual(PickupService(self.root).status()['last_ack'],ack)

    def test_expired_choice_and_mismatched_depth_units_are_rejected(self):
        t=self.choose()['target']
        self.service.snapshot['obs']['captured_at_unix_s']=time.time()-31
        self.refresh()
        with self.assertRaisesRegex(ValueError,'30 秒'):self.service.send(t['target_id'],True)
        self.obs['units']='mm'
        with self.assertRaises(ValueError):self.choose()

    def test_no_confirmation_no_submission(self):
        t=self.choose()['target']
        with self.assertRaises(ValueError):self.service.send(t['target_id'],False)
        with self.assertRaises(ValueError):self.service.send('b'*64,True)

    def test_ps_different_tcp_contract_is_rejected(self):
        other=copy.deepcopy(self.contract);other['tcp_id']='different-gripper'
        self.server(other);t=self.choose()['target'];self.refresh()
        with self.assertRaisesRegex(ValueError,'约定不一致'):self.service.send(t['target_id'],True)
        self.assertIsNone(self.service.last_ack)

    def test_ack_must_echo_exact_payload(self):
        t=self.choose()['target'];self.refresh()
        fake=copy.deepcopy(t);fake['position_mm'][0]+=1
        with patch('robotarm_vision.pickup.Client') as mock:
            mock.return_value.request.side_effect=[{'capabilities':['cartesian_target'],'cartesian_contract_id':fingerprint(self.contract)},
                {'accepted':True,'target':fake,'state':'target_received'}]
            with self.assertRaisesRegex(ValueError,'逐字段'):self.service.send(t['target_id'],True)
        self.assertIsNone(self.service.last_ack)

    def test_receiver_checks_units_frame_pose_bounds_and_digest(self):
        t=self.choose()['target'];sim=Simulator(cartesian_contract=self.contract)
        for key,value in [('units','m'),('frame_id','camera_color_optical_frame'),('position_mm',[900,0,0]),
                          ('orientation_xyzw',[0,0,0,1]),('tcp_id','wrong'),('position_mm',[float('nan'),0,0])]:
            broken=copy.deepcopy(t);broken[key]=value
            with self.assertRaises(ProtocolError):sim.handle({'command':'set_cartesian_target','target':broken,'confirmed':True})
        broken=copy.deepcopy(t);broken['target_id']='b'*64
        with self.assertRaises(ProtocolError):validate_target(broken,self.contract)
        c=copy.deepcopy(self.contract);c['profiles']['pliers']['lift_height_mm']=300
        self.config['contract']=c;self.write('config/pickup_tcp.json',self.config)
        self.assertIsNone(self.choose()['target'])

    def test_changed_contract_or_calibration_before_send_blocks(self):
        t=self.choose()['target']
        self.contract['tcp_id']='changed';self.write('config/pickup_tcp.json',self.config)
        self.refresh()
        with self.assertRaises(ValueError):self.service.send(t['target_id'],True)
        self.cal['calibration_id']='b'*64;self.write('config/calibration/camera_to_base.json',self.cal)
        with self.assertRaises(ValueError):self.service.send(t['target_id'],True)


if __name__=='__main__':unittest.main()
