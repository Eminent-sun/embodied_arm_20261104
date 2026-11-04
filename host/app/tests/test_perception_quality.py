import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from robotarm_vision.quality import sample_depth,DetectionStability,camera_signature
from robotarm_vision.geometry import Calibration

INTR={'width':640,'height':480,'fx':520.,'fy':520.,'cx':320.,'cy':240.}

class QualityTest(unittest.TestCase):
    def test_depth_edges_and_holes_are_not_coordinates(self):
        d=np.full((21,21),.6)
        self.assertTrue(sample_depth(d,[10,10],INTR)['valid'])
        d[:,11:]=1.0
        self.assertEqual(sample_depth(d,[10,10],INTR)['reason'],'depth_discontinuity')
        d[:]=.6;d[10,10]=0
        self.assertIsNone(sample_depth(d,[10,10],INTR)['point_camera_m'])
        d[:]=0;d[10,10]=.6
        self.assertFalse(sample_depth(d,[10,10],INTR)['valid'])

    def test_current_frame_only_and_adjacent_objects(self):
        tracker=DetectionStability()
        def frame():return [{'class_name':'tweezers','box_xyxy':[10,10,30,100]}, {'class_name':'tweezers','box_xyxy':[35,10,55,100]}]
        for i in range(3):r=tracker.update(frame(),i*.04)
        self.assertTrue(all(d['stable'] for d in r));self.assertEqual(len(set(d['track_id'] for d in r)),2)
        self.assertEqual(tracker.update([],.12),[])
        self.assertFalse(tracker.update(frame(),.16)[0]['stable'])
        self.assertFalse(tracker.update(frame(),1.)[0]['stable'])

    def test_binding_rejects_moved_mount_and_resolution_change(self):
        data={'schema_version':2,'validated':True,'physically_measured':True,'camera_fixed':True,
              'parent_frame':'base_link','child_frame':'camera_color_optical_frame','calibration_id':'a'*64,
              'mounting':'eye_to_hand','units':'m','camera_serial':'test','setup_id':'mount_a',
              'camera_model_signature':camera_signature(INTR,[0]*8),'T_base_camera':np.eye(4).tolist()}
        context={'camera_fixed':True,'setup_id':'mount_a','intrinsic':INTR,'distortion':[0]*8}
        with tempfile.TemporaryDirectory() as d:
            p=Path(d)/'cal.json';p.write_text(json.dumps(data));c=Calibration(p)
            self.assertEqual(c.point_in_base([0,0,.6],'test',context),[0,0,.6])
            self.assertIsNone(c.point_in_base([0,0,.6],'test'))
            self.assertFalse(c.compatible('test',{**context,'setup_id':'mount_b'}))
            self.assertFalse(c.compatible('test',{**context,'camera_fixed':False}))
            self.assertFalse(c.compatible('test',{**context,'intrinsic':{**INTR,'width':1280}}))
            self.assertFalse(c.compatible('different_serial',context))
