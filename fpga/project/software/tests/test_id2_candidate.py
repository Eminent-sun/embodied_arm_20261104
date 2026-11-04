"""Explicit direction-profile preparation and admission; offline only."""
import json,math,struct,sys,tempfile,unittest,zlib
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
from prepare_home_alignment import SIGN,HOME,ID2_POSITIVE_CANDIDATE
from prepare_machine_config import prepare_for_home_calibration
from workflow_protocol import load_record,pack_config

OLD=load_record(ROOT/'tests/fixtures/old_direction_calibration.json')
MOTOR=struct.unpack_from('<6f',OLD,392)
AXES=[struct.unpack_from('<3I10f',OLD,56+a*52) for a in range(6)]
POSE=struct.pack('<4I6I6I6f6f',0x504f5331,1,1,63,*[a[1] for a in AXES],*[a[2] for a in AXES],*MOTOR,*([0.]*6))
POSE+=struct.pack('<I',zlib.crc32(POSE))

def candidate_record():
    config=prepare_for_home_calibration(POSE,ID2_POSITIVE_CANDIDATE)
    config['calibration']=0x43414c31
    data=bytearray(OLD);data[24:368]=pack_config(config)
    struct.pack_into('<I',data,464,zlib.crc32(data[:464]))
    return bytes(data)

class ID2CandidateTests(unittest.TestCase):
    def test_default_profile_unchanged(self):
        c=prepare_for_home_calibration(POSE)
        self.assertEqual(tuple(a['gain'] for a in c['axis']),SIGN)

    def test_home_preserved_and_limits_reprojected(self):
        c=prepare_for_home_calibration(POSE,ID2_POSITIVE_CANDIDATE)
        self.assertEqual(c['calibration'],0)
        for i,a in enumerate(c['axis']):
            self.assertAlmostEqual(a['motor_zero_rad']+a['gain']*HOME[i],MOTOR[i],places=6)
        a=c['axis'][1]
        self.assertEqual(a['gain'],1)
        self.assertAlmostEqual(a['safe_min_rad'],MOTOR[1]-HOME[1]+.395710,places=6)
        self.assertAlmostEqual(a['safe_max_rad'],MOTOR[1]+math.pi/2,places=6)
        for deg in (-30,30):
            target=a['motor_zero_rad']+HOME[1]+math.radians(deg)
            self.assertAlmostEqual(target-MOTOR[1],math.radians(deg),places=6)
            self.assertLessEqual(a['safe_min_rad'],target)
            self.assertLessEqual(target,a['safe_max_rad'])

    def test_old_profile_rejected_new_record_accepted(self):
        with self.assertRaisesRegex(ValueError,'NEW CONFIGHOME'):console.require_id2_positive_record(OLD)
        console.require_id2_positive_record(candidate_record())
        corrupt=bytearray(candidate_record());corrupt[120]^=1
        with self.assertRaisesRegex(ValueError,'CRC'):console.require_id2_positive_record(bytes(corrupt))

    def exercise(self,commands):
        operations=[]
        class Worker:
            def __init__(self,*args):self.thread=type('Thread',(),{'join':lambda self,**kw:None})()
            def read(self,name,count):
                if name=='g_arm_reply':return bytes(4)
                if name=='g_arm_calibration':return OLD
                if name=='g_arm_report':return struct.pack('<12I18f',0x57465231,1,*([0]*10),*([0.]*18))
                raise AssertionError(name)
            def stop(self):operations.append('STOP')
        def capture(worker,seq,path,folder):operations.append('CAPTURE');return POSE
        def submit(worker,seq,op,*args,**kwargs):
            operations.append(op)
            if op==100:
                c=kwargs['config'];self.assertEqual(c['axis'][1]['gain'],1)
                self.assertEqual(c['calibration'],0)
                self.assertEqual(c['mapping_profile'],'ID2_POSITIVE_PHOTO_CANDIDATE')
            return (seq,0,op,0)
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            for rel in ('build/arm_workflow.elf','reports/workflow_symbols.json'):
                (root/rel).parent.mkdir(parents=True,exist_ok=True)
                (root/rel).write_bytes((ROOT/rel).read_bytes())
            (root/'config').mkdir()
            with patch.object(console,'ROOT',root),patch.object(console,'Worker',Worker),patch.object(console,'capture_to_file',capture),patch.object(console,'submit_request',submit),patch.object(console,'load_record',return_value=OLD),patch('builtins.input',side_effect=commands),patch.object(sys,'argv',['console','--connect','--id2-positive']),patch('builtins.print'):
                console.main()
        return operations

    def test_old_runtime_record_cannot_enable_or_move(self):
        ops=self.exercise(['BEGIN','CAL 2 1.57','RESUME','MOVETO 180 0 100 0 0 0','GOHOME','QUIT'])
        self.assertEqual(ops,['STOP','STOP'])

    def test_old_file_restore_rejected_before_submission(self):
        self.assertEqual(self.exercise(['RESTORE "old.json"','QUIT']),['STOP','STOP'])

    def test_candidate_config_home_captures_first_and_never_enables(self):
        self.assertEqual(self.exercise(['CONFIGHOME','QUIT']),['CAPTURE',100,'STOP','STOP'])

if __name__=='__main__':unittest.main()
