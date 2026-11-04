import copy
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest
from robotarm_link.protocol import Client,ProtocolError,HOME
from robotarm_link.ps_simulator import serve as serve_control
from robotarm_link.vision_protocol import observation_payload,validate_observation
from robotarm_link.vision_receiver import serve,ObservationStore
from robotarm_link.vision_bridge import relay_once


def observation(frame_id=1):
    return {'schema_version':2,'source_kind':'synthetic_test','source_session_id':'fixture_session','frame_id':frame_id,'camera_serial':'fixture_camera',
            'captured_at_unix_s':time.time(),'mounting':'eye_to_hand','image_size':[640,480],
            'camera_frame':'camera_color_optical_frame','base_frame':'base_link','units':'m',
            'station_setup_id':None,'calibration_id':None,'camera_model_signature':'a'*64,
            'base_calibration_valid':False,'hand_present':False,
            'detections':[{'class_name':'tweezers','confidence':.8,'box_xyxy':[100.,100.,120.,180.],
                           'track_id':1,'stable':True,'consecutive_hits':3,
                           'surface_point_camera_m':[.1,.1,.6],'surface_point_base_m':None,
                           'depth_quality':{'valid':True,'valid_fraction':1.,'mad_m':.001,'spread_m':.003},
                           'point_kind':'bbox_center_surface_sample','grasp_pose':None}]}


class VisionSchemaTest(unittest.TestCase):
    def test_stale_and_future_are_rejected(self):
        o=observation();o['captured_at_unix_s']=time.time()-1
        with self.assertRaises(ProtocolError):observation_payload(o)
        o['captured_at_unix_s']=time.time()+5
        with self.assertRaises(ProtocolError):observation_payload(o)

    def test_invalid_coordinates_quality_and_motion_are_rejected(self):
        good=observation_payload(observation())
        changes=[('confidence',float('nan')),('class_id',True),('surface_point_base_m',[0,0,.1]),
                 ('grasp_pose',{'position':[0,0,0]}),('box_xyxy',[100,100,900,150]),('consecutive_hits',1)]
        for field,value in changes:
            with self.subTest(field=field):
                data=copy.deepcopy(good);data['detections'][0][field]=value
                with self.assertRaises(ProtocolError):validate_observation(data)
        data=copy.deepcopy(good);data['execution_enabled']=True
        with self.assertRaises(ProtocolError):validate_observation(data)
        data=copy.deepcopy(good);data['detections'][0]['depth_quality']['valid']=False
        with self.assertRaises(ProtocolError):validate_observation(data)

    def test_ttl_and_duplicate_cannot_refresh_old_frame(self):
        store=ObservationStore();p=observation_payload(observation());p['ttl_ms']=20
        self.assertTrue(store.accept(p)['accepted']);self.assertTrue(store.status()['fresh'])
        time.sleep(.03)
        self.assertFalse(store.accept(p)['accepted']);self.assertFalse(store.status()['fresh'])
        self.assertIsNone(store.status()['observation'])


class VisionTransportTest(unittest.TestCase):
    def setUp(self):
        self.stop=threading.Event();ready=threading.Event();self.port=None
        def callback(port):self.port=port;ready.set()
        self.thread=threading.Thread(target=serve,kwargs={'port':0,'ready':callback,'stop_event':self.stop},daemon=True)
        self.thread.start();self.assertTrue(ready.wait(3));self.client=Client(port=self.port)

    def tearDown(self):
        self.client.close();self.stop.set();self.thread.join(3)

    def test_file_to_ps_and_no_control_commands(self):
        self.assertEqual(self.client.request('hello')['channel'],'vision')
        with tempfile.TemporaryDirectory() as d:
            path=Path(d)/'latest.json';path.write_text(json.dumps(observation()))
            key,reply=relay_once(self.client,path)
            self.assertTrue(reply['accepted'])
            _,duplicate=relay_once(self.client,path,key);self.assertIsNone(duplicate)
            result=self.client.request('vision_status')
            self.assertTrue(result['fresh']);self.assertEqual(result['observation']['detections'][0]['class_name'],'tweezers')
            self.assertFalse(result['execution_enabled'])
            for cmd in ['upload','execute','gripper','stop']:
                with self.assertRaises(ProtocolError):self.client.request(cmd,confirmed=True)
            path.write_text(json.dumps({**observation(),'captured_at_unix_s':time.time()-1}))
            with self.assertRaises(ProtocolError):relay_once(self.client,path)
            self.client.request('clear');self.assertFalse(self.client.request('vision_status')['fresh'])

    def test_disconnect_clears_observation_and_reconnect_rejects_replay(self):
        p=observation_payload(observation());self.client.request('observe',observation=p)
        self.client.close();time.sleep(.03);self.client=Client(port=self.port)
        self.assertFalse(self.client.request('vision_status')['fresh'])
        self.assertFalse(self.client.request('observe',observation=p)['accepted'])
        p=observation_payload(observation(2));self.assertTrue(self.client.request('observe',observation=p)['accepted'])

    def test_vision_does_not_occupy_motion_control_connection(self):
        stopped=threading.Event();ready=threading.Event();ports=[]
        def bound(port):ports.append(port);ready.set()
        thread=threading.Thread(target=serve_control,kwargs={'port':0,'ready':bound,'stop_event':stopped},daemon=True)
        thread.start();self.assertTrue(ready.wait(3));control=Client(port=ports[0])
        try:
            self.client.request('observe',observation=observation_payload(observation()))
            self.assertEqual(control.request('hello')['mode'],'simulation')
            status=control.request('status')
            self.assertEqual(status['positions_rad'],HOME);self.assertEqual(status['state'],'idle')
        finally:control.close();stopped.set();thread.join(3)
