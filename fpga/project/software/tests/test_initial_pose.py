"""Raw-pose file integrity and save-before-enable ordering. Fake worker only."""
from pathlib import Path
import contextlib,hashlib,io,json,shutil,struct,sys,tempfile,unittest
from unittest.mock import patch
from types import SimpleNamespace
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
from workflow_protocol import pose_info,save_pose,load_pose,load_record
POSE=(ROOT/'reports/arm_initial_pose_test.bin').read_bytes()
class FakeWorker:
    def __init__(self,file):self.file=file;self.operations=[];self.sequence=0;self.stopping=False;self.thread=SimpleNamespace(join=lambda **kwargs:None);self.stops=0
    def read(self,name,count):
        if name=='g_initial_pose':return POSE
        if name=='g_arm_reply':return struct.pack('<4I',self.sequence,0,self.operations[-1] if self.operations else 0,0)[:count*4]
        raise AssertionError(name)
    def request(self,data):
        seq,go,op,axis=struct.unpack_from('<4I',data);self.sequence=seq;self.operations.append(op)
        if op==103:
            # This is the actual transition to the firmware enable request.
            # The persistent file must already exist and verify bit-for-bit.
            assert load_pose(self.file)==POSE
            assert data[364:480]==POSE and data[480:832]==bytes(352)
    def stop(self):self.stops+=1
    def write_word(self,*args):self.stops+=1

class PoseTests(unittest.TestCase):
    def test_actual_ARM_record_format(self):
        info=pose_info(POSE);self.assertFalse(info['URDF_model_calibrated']);self.assertEqual(info['zero_state'][3],0)
    def test_file_roundtrip_and_wrong_calibration_format(self):
        with tempfile.TemporaryDirectory() as d:
            file=Path(d)/'pose.json';save_pose(file,POSE);self.assertEqual(load_pose(file),POSE)
            with self.assertRaisesRegex(ValueError,'Wrong calibration format'):load_record(file)
    def test_SHA_tampering_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            file=Path(d)/'pose.json';save_pose(file,POSE);data=json.loads(file.read_text());data['sha256']='0'*64;file.write_text(json.dumps(data))
            with self.assertRaisesRegex(ValueError,'SHA mismatch'):load_pose(file)
    def test_bad_record_CRC_rejected(self):
        data=bytearray(POSE);data[64]^=1
        with self.assertRaisesRegex(ValueError,'CRC/header'):pose_info(data)
    def run_console(self,command,fail_save=False):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);(root/'reports').mkdir();(root/'build').mkdir()
            shutil.copy2(ROOT/'reports/workflow_symbols.json',root/'reports/workflow_symbols.json')
            shutil.copy2(ROOT/'build/arm_workflow.elf',root/'build/arm_workflow.elf')
            file=root/'pose.json';worker=FakeWorker(file);inputs=iter([f'{command} "{file}"','QUIT'])
            with patch.object(console,'ROOT',root),patch.object(console,'Worker',return_value=worker),patch('sys.argv',['console','--connect']),patch('builtins.input',side_effect=lambda _:next(inputs)),contextlib.redirect_stdout(io.StringIO()):
                if fail_save:
                    with patch.object(console,'save_pose',side_effect=OSError('disk full')):
                        with self.assertRaisesRegex(OSError,'disk full'):console.main()
                else:console.main()
            return worker.operations,file.exists(),worker.stops
    def test_save_only_never_enables(self):
        operations,saved,_=self.run_console('SAVEPOSE');self.assertTrue(saved);self.assertEqual(operations,[102])
    def test_save_precedes_hold_without_machine_config_or_preview(self):
        operations,saved,_=self.run_console('HOLDINITIAL');self.assertTrue(saved);self.assertEqual(operations,[102,103])
    def test_file_error_prevents_hold(self):
        operations,saved,stops=self.run_console('HOLDINITIAL',fail_save=True)
        self.assertEqual(operations,[102]);self.assertFalse(saved);self.assertGreater(stops,0)

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(PoseTests))
    (ROOT/'reports/initial_pose_host_tests.json').write_text(json.dumps({'status':'PASS_OFFLINE_ONLY' if result.wasSuccessful() else 'FAIL','checks':result.testsRun,'hardware_access':False,'save_before_enable_verified':result.wasSuccessful()},indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
