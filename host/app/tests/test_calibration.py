import unittest
import numpy as np
import cv2
from robotarm_vision.calibration import board_points, rigid_fit, residuals, solve_external, solve_intrinsic


class CalibrationTest(unittest.TestCase):
    def test_transform_direction_and_independent_validation(self):
        rng=np.random.default_rng(73)
        camera=rng.uniform(-0.25,0.25,(20,3));camera[:,2]+=0.65
        rotation=cv2.Rodrigues(np.array([0.2,-0.4,0.1]))[0]
        base=camera@rotation.T+np.array([0.1,-0.3,0.25])
        pairs=[{'camera_m':a.tolist(),'base_m':b.tolist()} for a,b in zip(camera,base)]
        data={'units':'m','camera_serial':'synthetic-test','physically_measured':True,'fit':pairs[:12],'validation':pairs[12:]}
        data.update(camera_fixed=True,setup_id='synthetic_mount',factory_intrinsic={'width':640,'height':480,'fx':520.,'fy':520.,'cx':320.,'cy':240.},factory_distortion=[0]*8)
        result=solve_external(data)
        self.assertTrue(result['validated'])
        self.assertLess(result['validation_max_m'],1e-10)
        data['validation'][0]['base_m'][0]+=0.08
        self.assertFalse(solve_external(data)['validated'])

    def test_reject_degenerate_or_reused_points(self):
        points=np.array([[i*0.1,0,1] for i in range(6)])
        with self.assertRaises(ValueError):rigid_fit(points,points)
        rng=np.random.default_rng(5);points=rng.normal(size=(8,3))
        pairs=[{'camera_m':p.tolist(),'base_m':p.tolist()} for p in points]
        with self.assertRaises(ValueError):solve_external({'units':'m','camera_serial':'test','fit':pairs,'validation':pairs[:4]})

    def test_reject_mm_values_and_repeated_validation(self):
        rng=np.random.default_rng(8);points=rng.uniform(-0.2,0.2,(12,3));points[:,2]+=0.7
        pairs=[{'camera_m':p.tolist(),'base_m':p.tolist()} for p in points]
        data={'units':'m','camera_serial':'test','fit':pairs[:8],'validation':[pairs[8]]*4}
        with self.assertRaises(ValueError):solve_external(data)
        data['validation']=pairs[8:]
        data['fit'][0]['camera_m'][2]=700
        with self.assertRaises(ValueError):solve_external(data)

    def test_robust_fit_excludes_bad_fit_but_never_validation(self):
        rng=np.random.default_rng(30);c=rng.uniform(-.2,.2,(20,3));c[:,2]+=.7
        b=c+np.array([.1,.2,-.5]);pairs=[{'camera_m':a.tolist(),'base_m':v.tolist()} for a,v in zip(c,b)]
        data={'units':'m','camera_serial':'synthetic','physically_measured':True,'camera_fixed':True,'setup_id':'fixture',
              'factory_intrinsic':{'width':640,'height':480,'fx':520.,'fy':520.,'cx':320.,'cy':240.},'factory_distortion':[0]*8,
              'fit':pairs[:14],'validation':pairs[14:]}
        data['fit'][0]['base_m'][0]+=.1
        r=solve_external(data,.005,.01)
        self.assertTrue(r['validated']);self.assertIn(0,r['fit_excluded_indices'])
        self.assertLess(r['validation_max_m'],1e-9)
        data['validation'][0]['base_m'][0]+=.04
        self.assertFalse(solve_external(data,.005,.01)['validated'])
        data['camera_fixed']=False
        self.assertFalse(solve_external(data,.005,.01)['validated'])

    def test_intrinsic_recovers_synthetic_camera(self):
        obj=board_points();matrix=np.array([[520.,0,320],[0,518,240],[0,0,1]])
        corners=[]
        for i in range(20):
            rotation=np.array([0.25*((i%3)-1),0.3*((i%4)-1.5),0.05*(i%2)])
            translation=np.array([-0.16+0.06*(i%4),-0.12+0.06*(i%3),0.5+0.025*(i%3)])
            corners.append(cv2.projectPoints(obj,rotation,translation,matrix,np.zeros(5))[0])
        result=solve_intrinsic(corners,(640,480),obj)
        self.assertLess(result['fit_rms_px'],0.01)
        np.testing.assert_allclose(result['matrix'],matrix,atol=0.1)
        with self.assertRaises(ValueError):solve_intrinsic(corners[:5],(640,480),obj)


if __name__=='__main__':unittest.main()
