import copy
import json
import tempfile
import time
import unittest
from unittest.mock import patch
from pathlib import Path
import numpy as np
from test_aipc_planning import fixture
from robotarm_vision.geometry import Calibration
from robotarm_vision.tracking import HandTracker
from robotarm_planning.core import build_live_request, validate_request, PlanningError
from robotarm_planning.handover import freeze_hand, review_hand, review_plan_targets, HandoverGuard, handover_events


def hand_fixture():
    cal, obs, cfg, station = fixture()
    cfg['task_kind'] = 'tool_handover'
    cfg['handover_regions'] = {'desk': {
        'reviewed': True, 'body_scene_reviewed': True,
        'min_m': [.25, -.3, .05], 'max_m': [.65, .05, .5],
        'palm_to_tcp_offset_base_m': [0., 0., .1], 'approach_offset_base_m': [0., 0., .02],
        'tcp_quaternion_xyzw': [0., 0., 0., 1.], 'hand_margin_m': .025, 'max_deviation_m': .01}}
    transform = np.array(cal['T_base_camera'])
    camera = []
    for i in range(21):
        point = np.array([.40+(i%5-2)*.005, -.15+(i//5-2)*.005, .2])
        camera.append((np.linalg.inv(transform) @ np.r_[point, 1])[:3].tolist())
    hand = {'track_id': 8, 'handedness': 'Left', 'observed_this_frame': True,
            'palm_stable': True, 'keypoints': [
        {'id': i, 'camera_m': p, 'raw_camera_m': p.copy(), 'base_m': [9.,9.,9.],
         'coordinate_fresh': True, 'coordinate_age_ms': 0.} for i,p in enumerate(camera)]}
    obs.update(hand_present=True, hands=[hand])
    return cal, obs, cfg, station


class HandoverTest(unittest.TestCase):
    def request(self):
        cal, obs, cfg, station = hand_fixture()
        folder = tempfile.TemporaryDirectory(); self.addCleanup(folder.cleanup)
        path = Path(folder.name)/'cal.json'; path.write_text(json.dumps(cal))
        req = build_live_request(obs,4,'desk','test',cfg,Calibration(path),station,hand_track_id=8)
        return req, obs

    def test_region_fixed_but_hand_target_moves(self):
        req, obs = self.request(); validate_request(req)
        first = copy.deepcopy(req['handover'])
        for k in obs['hands'][0]['keypoints']:
            k['camera_m'][0] += .025; k['raw_camera_m'][0] += .025
        second = freeze_hand(obs,req['config'],'desk',req['T_base_camera'],8)
        np.testing.assert_allclose(np.array(second['palm_base_m'])-first['palm_base_m'],[0.,.025,0.],atol=1e-10)
        np.testing.assert_allclose(np.array(second['tcp_pose_base']['position_m'])-first['tcp_pose_base']['position_m'],[0.,.025,0.],atol=1e-10)
        self.assertNotEqual(second['palm_base_m'],[9.,9.,9.])
        self.assertEqual(req['handover'], first)
        self.assertEqual([s['name'] for s in req['stages']],['approach','grasp','lift','transfer','present'])

    def test_lost_moved_stale_second_hand_and_session_change_latch(self):
        req, obs = self.request()
        changes = [lambda o:o.update(hands=[]), lambda o:o.update(captured_at_unix_s=time.time()-1),
                   lambda o:o.update(source_session_id='restart'),
                   lambda o:o['hands'].append(copy.deepcopy(o['hands'][0])),
                   lambda o:o['hands'][0].update(observed_this_frame=False),
                   lambda o:o['hands'][0].update(track_id=9),
                   lambda o:o['hands'][0]['keypoints'][8].update(coordinate_fresh=False),
                   lambda o:o['hands'][0]['keypoints'][8].update(raw_camera_m=[.5,.5,.5])]
        for mutate in changes:
            with self.subTest(mutation=mutate):
                guard = HandoverGuard(req)
                self.assertFalse(guard.update(obs)['hold_required'])
                bad=copy.deepcopy(obs); mutate(bad)
                self.assertTrue(guard.update(bad)['hold_required'])
                # Reappearance at the old point cannot silently resume a plan.
                recovered=guard.update(obs)
                self.assertEqual(recovered['state'],'requires_replan')
                self.assertFalse(recovered['automatic_release'])

    def test_gripped_tool_disappearing_only_allowed_in_delivery_review(self):
        req,obs=self.request()
        # Both tool and hand guards must recompute base points, not trust cache.
        self.assertEqual(obs['detections'][0]['surface_point_base_m'],[9.,9.,9.])
        self.assertEqual(review_plan_targets(req,obs)['state'],'observation_consistent')
        obs['detections']=[]
        self.assertNotEqual(review_plan_targets(req,obs,phase='pickup')['state'],'observation_consistent')
        self.assertEqual(review_plan_targets(req,obs,phase='delivery')['state'],'observation_consistent')

    def test_region_exit_unreviewed_body_and_tampered_target_rejected(self):
        req,obs=self.request()
        bad=copy.deepcopy(obs)
        for k in bad['hands'][0]['keypoints']:
            k['camera_m'][0]+=1; k['raw_camera_m'][0]+=1
        with self.assertRaises(PlanningError):freeze_hand(bad,req['config'],'desk',req['T_base_camera'],8)
        cfg=copy.deepcopy(req['config']);cfg['handover_regions']['desk']['body_scene_reviewed']=False
        with self.assertRaises(PlanningError):freeze_hand(obs,cfg,'desk',req['T_base_camera'],8)
        req['handover']['tcp_pose_base']['position_m'][0]+=.02
        with self.assertRaises(PlanningError):validate_request(req)

    def test_no_automatic_release_or_retreat_across_handover_barrier(self):
        req,_=self.request();events=handover_events()
        self.assertEqual([e for e in events if e.get('gripper')=='open'],[events[0]])
        self.assertFalse(events[-1]['automatic_release'])
        self.assertIn('operator_release_confirmation',events[-1]['requires'])
        self.assertEqual(events[2]['barrier'],'confirm_delivery')
        self.assertNotIn('retreat',[s['name'] for s in req['stages']])

    def test_dashboard_review_persists_invalidation_across_polls(self):
        from robotarm_vision import planning_client
        req,obs=self.request();cal,_,_,station=hand_fixture()
        obs['detections'][0]['surface_point_base_m']=req['point_base_m']
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);job='a'*16
            def save(name,data):
                path=root/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(data))
            save('config/calibration/camera_to_base.json',cal)
            save('config/vision_station.json',station);save('config/planning.json',req['config'])
            save(f'runtime/planning/jobs/{job}/request.json',req)
            save(f'runtime/planning/jobs/{job}/result.json',{'status':'planned_for_review','mode':'measured','task_kind':'tool_handover','execution_enabled':False})
            save('runtime/vision/latest.json',obs)
            with patch.object(planning_client,'ROOT',root):
                self.assertEqual(planning_client.load_job(job)['status'],'planned_for_review')
                bad=copy.deepcopy(obs);bad['hands']=[];save('runtime/vision/latest.json',bad)
                self.assertEqual(planning_client.load_job(job)['status'],'requires_review')
                save('runtime/vision/latest.json',obs)
                self.assertTrue(planning_client.load_job(job)['target_review']['hold_required'])


class PalmStabilityTest(unittest.TestCase):
    def hand(self,x=.1):
        return {'handedness':'Left','confidence':.9,'keypoints':[
            {'id':i,'pixel':[100+i*2,100+i*3],'camera_m':[x,.1,.6],
             'depth_quality':{'valid':True}} for i in range(21)]}

    def test_real_depth_stability_and_hold_not_new_samples(self):
        tracker=HandTracker()
        for i in range(15):hands,_,_=tracker.update([self.hand()],i*.03)
        self.assertTrue(hands[0]['palm_stable'])
        np.testing.assert_allclose(hands[0]['palm_camera_m'],[.1,.1,.6])
        hands,_,_=tracker.update([],.45)
        self.assertFalse(hands[0]['palm_stable']);self.assertIsNone(hands[0]['palm_camera_m'])
        hands,_,_=tracker.update([self.hand()],.48)
        self.assertFalse(hands[0]['palm_stable'])

    def test_raw_motion_cannot_hide_behind_ema_or_invalid_depth(self):
        tracker=HandTracker()
        for i in range(15):tracker.update([self.hand()],i*.03)
        hands,_,_=tracker.update([self.hand(.12)],.45)
        self.assertFalse(hands[0]['palm_stable'])
        invalid=self.hand();invalid['keypoints'][5]['camera_m']=None
        invalid['keypoints'][5]['depth_quality']['valid']=False
        hands,_,_=tracker.update([invalid],.48)
        self.assertFalse(hands[0]['palm_stable'])

if __name__=='__main__':unittest.main()
