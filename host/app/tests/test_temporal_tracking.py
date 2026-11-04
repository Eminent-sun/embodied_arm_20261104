import copy
import json
import tempfile
import time
import unittest
from pathlib import Path
import numpy as np
from robotarm_vision.tracking import TemporalTracker,HandTracker
from robotarm_vision.target_lock import lock_target,review_lock
from robotarm_link.vision_protocol import observation_payload,validate_observation
from robotarm_link.protocol import ProtocolError
from test_vision_link import observation


def detection(x=.1,box=None):
    d=observation()['detections'][0]
    d['surface_point_camera_m']=[x,.1,.6]
    if box is not None:d['box_xyxy']=box
    return d


class TemporalTests(unittest.TestCase):
    def test_jitter_reduction_and_outlier_rejection(self):
        tracker=TemporalTracker();raw=[];filtered=[]
        for i in range(90):
            x=.1+(.004 if i%2 else -.004)
            d=tracker.update([detection(x)],i/30)[0]
            if i>10:raw.append(x);filtered.append(d['surface_point_camera_m'][0])
        self.assertLess(np.std(filtered),np.std(raw)*.4)
        previous=d['surface_point_camera_m'];bad=tracker.update([detection(.25)],3.)[0]
        self.assertEqual(bad['surface_point_camera_m'],previous)
        self.assertEqual(bad['tracking_status'],'jump_rejected');self.assertFalse(bad['coordinate_usable'])

    def test_hold_reacquisition_expiry_and_time_reset(self):
        tracker=TemporalTracker()
        for i in range(3):d=tracker.update([detection()],i*.03)[0]
        self.assertTrue(d['coordinate_usable']);key=d['track_id']
        held=tracker.update([],.1)[0]
        self.assertEqual(held['track_id'],key);self.assertFalse(held['coordinate_fresh'])
        self.assertFalse(held['coordinate_usable']);self.assertGreater(held['coordinate_age_ms'],0)
        self.assertEqual(tracker.update([detection()],.15)[0]['track_id'],key)
        self.assertFalse(tracker.update([detection()],.18)[0]['coordinate_usable'])
        self.assertTrue(tracker.update([detection()],.21)[0]['coordinate_usable'])
        self.assertEqual(tracker.update([],.7),[])
        new=tracker.update([detection()],.75)[0];self.assertNotEqual(new['track_id'],key)
        self.assertNotEqual(tracker.update([detection()],.74)[0]['track_id'],new['track_id'])

    def test_repeated_jump_reinitializes_and_requires_three_measurements(self):
        tracker=TemporalTracker()
        for i in range(3):tracker.update([detection()],i*.03)
        for i in range(3,5):self.assertFalse(tracker.update([detection(.2)],i*.03)[0]['coordinate_fresh'])
        d=tracker.update([detection(.2)],.15)[0]
        self.assertEqual(d['tracking_status'],'reacquiring');self.assertFalse(d['coordinate_usable'])
        self.assertAlmostEqual(d['surface_point_camera_m'][0],.2)
        tracker.update([detection(.2)],.18)
        self.assertTrue(tracker.update([detection(.2)],.21)[0]['coordinate_usable'])

    def test_two_similar_objects_and_low_confidence_hysteresis(self):
        tracker=TemporalTracker();a=detection(box=[100,100,120,180]);b=detection(.15,box=[125,100,145,180])
        first=tracker.update([a,b],0);next_=tracker.update([b,a],.03)
        self.assertEqual([d['track_id'] for d in first],[d['track_id'] for d in next_])
        self.assertEqual(next_[0]['raw_box_xyxy'],a['box_xyxy'])
        weak=copy.deepcopy(a);weak['confidence']=.2
        self.assertEqual(tracker.update([weak],.06)[0]['track_id'],1)
        self.assertEqual(TemporalTracker().update([weak],0),[])

    def test_no_depth_is_not_fake_z_and_hold_is_bounded(self):
        tracker=TemporalTracker()
        for i in range(3):tracker.update([detection()],i*.03)
        d=detection();d['surface_point_camera_m']=None;d['depth_quality']['valid']=False
        for i in range(3,20):out=tracker.update([d],i*.03)[0]
        self.assertIsNone(out['surface_point_camera_m']);self.assertFalse(out['coordinate_usable'])

    def test_held_wire_points_cannot_be_used_and_age_includes_send_delay(self):
        tracker=TemporalTracker()
        for i in range(3):tracker.update([detection()],i*.03)
        o=observation();o['detections']=tracker.update([],.1)
        p=observation_payload(o,now=o['captured_at_unix_s']+.02)
        self.assertAlmostEqual(p['detections'][0]['coordinate_age_ms'],60,places=2)
        p['detections'][0]['coordinate_usable']=True
        with self.assertRaises(ProtocolError):validate_observation(p)
        o['detections']=tracker.update([],.38)
        p=observation_payload(o,now=o['captured_at_unix_s']+.05)
        self.assertIsNone(p['detections'][0]['surface_point_camera_m'])

    def test_hand_point_filter_and_presence_hold(self):
        tracker=HandTracker()
        hand={'handedness':'Left','confidence':.9,'keypoints':[
            {'id':i,'pixel':[100+i*2,100+i*3],'camera_m':[.1,.1,.6],
             'depth_quality':{'valid':True,'valid_fraction':1.,'mad_m':0.,'spread_m':0.}} for i in range(21)]}
        for i in range(3):hands,present,state=tracker.update([copy.deepcopy(hand)],i*.03)
        self.assertTrue(present);key=hands[0]['track_id']
        hand['keypoints'][8]['camera_m']=[1.,1.,1.]
        hands,_,_=tracker.update([hand],.09)
        self.assertEqual(hands[0]['keypoints'][8]['camera_m'],[.1,.1,.6])
        self.assertFalse(hands[0]['keypoints'][8]['coordinate_fresh'])
        hands,present,state=tracker.update([],.15)
        self.assertTrue(present);self.assertEqual(state,'recently_seen');self.assertEqual(hands[0]['track_id'],key)
        self.assertFalse(hands[0]['keypoints'][0]['coordinate_fresh'])
        o=observation();o.update(hands=hands,hand_present=present,hand_status=state)
        validate_observation(observation_payload(o))
        hands,present,_=tracker.update([],.7);self.assertEqual(hands,[]);self.assertFalse(present)

    def test_locked_target_never_switches_to_other_instance(self):
        o=observation();o.update(source_kind='live_camera',base_calibration_valid=True,calibration_id='abc',station_setup_id='desk')
        d=o['detections'][0];d.update(coordinate_usable=True,coordinate_fresh=True,coordinate_age_ms=0,observed_this_frame=True,surface_point_base_m=[.2,.2,.1])
        lock=lock_target(o,d)
        self.assertEqual(review_lock(lock,o)['state'],'observation_consistent')
        d['track_id']=2
        self.assertEqual(review_lock(lock,o)['state'],'waiting')
        d['track_id']=1;d['surface_point_base_m']=[.3,.2,.1]
        self.assertEqual(review_lock(lock,o)['state'],'requires_review')
        self.assertEqual(lock['surface_point_base_m'],[.2,.2,.1])
        o['source_session_id']='restart'
        self.assertIn('会话',review_lock(lock,o)['reason'])

class ReceiverAgingTest(unittest.TestCase):
    def test_ps_expires_coordinate_before_frame_ttl(self):
        from robotarm_link.vision_receiver import ObservationStore
        from unittest.mock import patch
        tracker=TemporalTracker()
        for i in range(3):detections=tracker.update([detection()],i*.03)
        obs=observation();obs['detections']=detections
        wire=observation_payload(obs,now=obs['captured_at_unix_s'])
        store=ObservationStore()
        with patch('robotarm_link.vision_receiver.time.monotonic',return_value=100.):store.accept(wire)
        with patch('robotarm_link.vision_receiver.time.monotonic',return_value=100.2):status=store.status()
        self.assertTrue(status['fresh']);self.assertFalse(status['observation']['detections'][0]['coordinate_usable'])
        self.assertTrue(status['received_payload']['detections'][0]['coordinate_usable'])
        with patch('robotarm_link.vision_receiver.time.monotonic',return_value=100.4):status=store.status()
        self.assertTrue(status['fresh']);self.assertIsNone(status['observation']['detections'][0]['surface_point_camera_m'])
        with patch('robotarm_link.vision_receiver.time.monotonic',return_value=100.6):self.assertFalse(store.status()['fresh'])

    def test_ambiguity_holds_instead_of_switching_identity(self):
        tracker=TemporalTracker()
        a=detection(box=[100,100,130,180]);b=detection(.15,box=[120,100,150,180])
        for i in range(3):tracker.update([a,b],i*.03)
        ambiguous=detection(box=[110,100,140,180]);out=tracker.update([ambiguous],.09)
        self.assertEqual(len(out),2)
        self.assertTrue(all(not d['observed_this_frame'] and not d['coordinate_usable'] for d in out))

    def test_lock_point_is_an_immutable_copy(self):
        obs=observation();obs['base_calibration_valid']=True
        d=obs['detections'][0];d.update(coordinate_fresh=True,coordinate_usable=True,surface_point_base_m=[.2,.3,.4])
        lock=lock_target(obs,d);d['surface_point_base_m'][0]=.9
        self.assertEqual(lock['surface_point_base_m'],[.2,.3,.4])

class TargetAgeTest(unittest.TestCase):
    def test_camera_latency_and_offline_data_cannot_qualify_a_target(self):
        from robotarm_vision.target_lock import current_point
        obs=observation();d=obs['detections'][0]
        d.update(coordinate_fresh=True,coordinate_usable=True,coordinate_age_ms=0,observed_this_frame=True)
        self.assertFalse(current_point(obs,d))
        obs['source_kind']='live_camera'
        self.assertTrue(current_point(obs,d,obs['captured_at_unix_s']+.02))
        self.assertFalse(current_point(obs,d,obs['captured_at_unix_s']+.2))
