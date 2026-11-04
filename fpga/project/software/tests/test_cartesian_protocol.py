"""Pure host payload and presentation checks; no board or external tools."""
from pathlib import Path
import json,math,struct,sys,unittest,zlib
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from workflow_protocol import cartesian_payload,cartesian_report,make_request,OPS

class CartesianProtocol(unittest.TestCase):
    def test_payload_frame_units_and_crc(self):
        p=cartesian_payload(['200','-20','100','10','-45','30'])
        self.assertEqual(len(p),468)
        self.assertEqual(struct.unpack_from('<4I',p),(0x43504f31,1,1,1))
        self.assertEqual(struct.unpack_from('<6f',p,16),(200,-20,100,10,-45,30))
        self.assertFalse(any(p[40:]))
        r=make_request(7,OPS['MOVETO'],record=p)
        self.assertEqual(struct.unpack_from('<I',r,832)[0],zlib.crc32(r[:832]))
    def test_invalid_values(self):
        for p in ([1,2,3],[1,2,3,4,5,6,7],[math.nan,0,0,0,0,0],[0,0,0,math.inf,0,0],[0,0,0,361,0,0]):
            with self.assertRaises(ValueError):cartesian_payload(p)
    def test_report_model_only_not_motor_command(self):
        r=struct.pack('<10I26f',0x43505231,1,7,0,1,0,0,0,1,2,*([0.]*26))
        d=cartesian_report(r)
        self.assertIsNone(d['target_motor_rad']);self.assertFalse(d['plan_valid'])
        self.assertEqual(d['solver'],'Pieper spherical wrist')
    def test_report_matching(self):
        with self.assertRaises(ValueError):cartesian_report(bytes(144))
        with self.assertRaises(ValueError):cartesian_report(bytes(136))

if __name__=='__main__':
    suite=unittest.defaultTestLoader.loadTestsFromTestCase(CartesianProtocol)
    result=unittest.TextTestRunner(verbosity=2).run(suite)
    (root/'reports/cartesian_protocol_tests.json').write_text(json.dumps({'status':'PASS_OFFLINE_ONLY' if result.wasSuccessful() else 'FAIL','checks':result.testsRun})+'\n')
    sys.exit(not result.wasSuccessful())
