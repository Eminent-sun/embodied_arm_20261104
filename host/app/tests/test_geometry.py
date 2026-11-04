import json
import tempfile
import unittest
from pathlib import Path
import numpy as np
from robotarm_vision.geometry import Calibration,depth_point
from robotarm_vision.quality import camera_signature


class GeometryTest(unittest.TestCase):
    def test_depth_and_invalid_depth(self):
        intr={'fx':100.,'fy':100.,'cx':10.,'cy':10.}
        self.assertEqual(depth_point(np.ones((30,30)),[20,10],intr),[.1,0.,1.])
        self.assertIsNone(depth_point(np.zeros((30,30)),[20,10],intr))
        self.assertIsNone(depth_point(None,[20,10],intr))

    def test_calibration_gate_and_serial(self):
        with tempfile.TemporaryDirectory() as directory:
            p=Path(directory)/'calibration.json'
            p.write_text(json.dumps({'validated':False}))
            self.assertIsNone(Calibration(p).point_in_base([1,2,3],'123'))
            m=np.eye(4);m[0,3]=.1
            intr={'width':640,'height':480,'fx':520.,'fy':520.,'cx':320.,'cy':240.}
            context={'camera_fixed':True,'setup_id':'a','intrinsic':intr,'distortion':[0]*8}
            p.write_text(json.dumps({'parent_frame':'base_link','child_frame':'camera_color_optical_frame','calibration_id':'a'*64,'schema_version':2,'validated':True,'physically_measured':True,'camera_fixed':True,'setup_id':'a','units':'m','mounting':'eye_to_hand','camera_serial':'123','camera_model_signature':camera_signature(intr,[0]*8),'T_base_camera':m.tolist()}))
            c=Calibration(p)
            self.assertEqual(c.point_in_base([1,2,3],'123',context),[1.1,2.,3.])
            self.assertIsNone(c.point_in_base([1,2,3],'wrong-camera',context))
            m[0,0]=2
            p.write_text(json.dumps({'validated':True,'T_base_camera':m.tolist()}))
            with self.assertRaises(ValueError):Calibration(p)


if __name__=='__main__':unittest.main()
