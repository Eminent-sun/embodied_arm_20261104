"""Offline calibration-only configuration; never connects to hardware."""
import json,struct,subprocess,sys,tempfile,unittest
from unittest.mock import patch
from pathlib import Path
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'tools'))
from workflow_protocol import pack_config,load_pose
import workflow_console as console

class CalibrationConfig(unittest.TestCase):
    def test_status_archives_fault_without_extra_control(self):
        operations=[]
        report=struct.pack('<12I18f',0x57465231,1,226,11,63,63,1,42,121,11,0,9,
                           *([0,2,0,3,1,.18855]+[0,0,0,0,0,.3]+[0,2,0,3,1,.29208]))
        trace=struct.pack('<28I',0x53545031,1,300,63,*([48]*6+[49]*6+[0x20001+a for a in range(6)]+[32767]*6))
        timing=struct.pack('<16I',0x54494d31,1,42,7000,6800,200,40,30,70,80,6750,6800,2,1,50,0)
        class Worker:
            def __init__(self,*args):self.thread=type('Thread',(),{'join':lambda self,**kw:None})()
            def read(self,name,count):
                return {'g_arm_reply':struct.pack('<I',11),'g_arm_report':report,'g_arm_stop_trace':trace,'g_arm_timing':timing}[name]
            def stop(self):operations.append('STOP')
        with tempfile.TemporaryDirectory() as folder:
            copied=Path(folder);(copied/'reports').mkdir();(copied/'build').mkdir()
            for name in ['build/arm_workflow.elf','reports/workflow_symbols.json']:(copied/name).write_bytes((root/name).read_bytes())
            with patch.object(console,'ROOT',copied),patch.object(console,'Worker',Worker),patch('builtins.input',side_effect=['STATUS','QUIT']),patch.object(sys,'argv',['console','--connect']),patch('builtins.print'):
                console.main()
            files=list((copied/'operator_logs').glob('*/fault_snapshots.jsonl'));self.assertEqual(len(files),1)
            saved=json.loads(files[0].read_text())
            self.assertEqual(saved['status']['frames'],'42/121')
            self.assertAlmostEqual(saved['status']['saved_position_minus_target_rad'][5],-.10353,places=5)
            self.assertEqual(saved['stop_trace']['before_count'],[48]*6)
            self.assertEqual(saved['timing']['fault_reason'],'frame_dispatch_late')
        self.assertEqual(operations,['STOP','STOP'])
    def test_console_config_home_has_no_enable_operation(self):
        pose=load_pose(root/'config/home_stopfix_20261104.json');operations=[]
        class Worker:
            def __init__(self,*args):
                self.thread=type('Thread',(),{'join':lambda self,**kw:None})()
            def read(self,name,count):
                if name=='g_arm_reply':return bytes(4)
                if name=='g_arm_report':return struct.pack('<12I18f',0x57465231,1,*([0]*10),*([0.]*18))
                raise AssertionError(name)
            def stop(self):operations.append('STOP')
        def capture(worker,sequence,path,folder):
            operations.append('CAPTURE');Path(path).write_text('fixture');return pose
        def submit(worker,seq,op,**kwargs):
            operations.append(op)
            self.assertEqual(struct.unpack_from('<I',pack_config(kwargs['config']))[0],0)
            return (seq,0,op,0)
        with tempfile.TemporaryDirectory() as folder:
            copied=Path(folder);(copied/'reports').mkdir();(copied/'build').mkdir()
            (copied/'build/arm_workflow.elf').write_bytes((root/'build/arm_workflow.elf').read_bytes())
            (copied/'reports/workflow_symbols.json').write_bytes((root/'reports/workflow_symbols.json').read_bytes())
            (copied/'config').mkdir()
            with patch.object(console,'ROOT',copied),patch.object(console,'Worker',Worker),patch.object(console,'capture_to_file',capture),patch.object(console,'submit_request',submit),patch('builtins.input',side_effect=['CONFIGHOME','QUIT']),patch.object(sys,'argv',['console','--connect']),patch('builtins.print'):
                console.main()
        self.assertEqual(operations,['CAPTURE',100,'STOP','STOP'])
    def test_opt_in_stays_uncalibrated(self):
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)/'config.json'
            command=[sys.executable,str(root/'tools/prepare_machine_config.py'),str(root/'config/home_stopfix_20261104.json'),str(output)]
            subprocess.run(command,check=True,capture_output=True)
            candidate=json.loads(output.read_text())
            self.assertIsNone(candidate['stop_policy'])
            with self.assertRaises(ValueError):pack_config(candidate)
            subprocess.run(command+['--for-home-calibration'],check=True,capture_output=True)
            config=json.loads(output.read_text());payload=pack_config(config)
            self.assertEqual(struct.unpack_from('<2I',payload),(0,0x53544f31))
            self.assertFalse(config['ready_for_motion'])
            self.assertFalse(config['physical_home_alignment_verified'])
            self.assertEqual(config['axis'],candidate['axis'])
            self.assertEqual(config['source_home_pose_sha256'],candidate['source_home_pose_sha256'])
    def test_corrupt_pose_creates_no_config(self):
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'bad.json';output=Path(folder)/'config.json'
            source.write_text('{"format":"ZYNQ_ARM_INITIAL_POSE_V1","record_hex":"00","sha256":"wrong"}')
            result=subprocess.run([sys.executable,str(root/'tools/prepare_machine_config.py'),str(source),str(output),'--for-home-calibration'],capture_output=True)
            self.assertNotEqual(result.returncode,0);self.assertFalse(output.exists())

if __name__=='__main__':unittest.main()
