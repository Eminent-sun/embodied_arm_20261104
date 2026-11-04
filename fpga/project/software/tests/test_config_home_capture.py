"""Recovered CONFIGURED HOME capture and disabled reconnect; no devices."""
import json,struct,sys,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
from workflow_protocol import pose_from_readback,pose_info,load_pose

def report(state=1,active=0,stopped=1,error=0):
    return struct.pack('<12I18f',0x57465231,1,state,error,active,63,1,0,0,0,stopped,0,*([0.]*18))

def readback(axis=None,field=None,value=None):
    rows=[[a+1,1,0 if a==3 else 1,0,.25*a,0.] for a in range(6)]
    if axis is not None:rows[axis][field]=value
    return b''.join(struct.pack('<4I2f',*r) for r in rows)

class MemoryWorker:
    def __init__(self,before=None,after=None,stop=0,data=None):
        self.reports=[before or report(),after or before or report()]
        self.stop=stop;self.data=data or readback()
    def read(self,name,count):
        if name=='g_arm_report':return self.reports.pop(0)
        if name=='g_arm_stop':return struct.pack('<I',self.stop)
        if name=='g_arm_readback':return self.data
        raise AssertionError('Unexpected read '+name)

class HomeCaptureTests(unittest.TestCase):
    def test_readback_conversion_preserves_new_positions_zero_and_offset(self):
        p=pose_info(pose_from_readback(readback(axis=4,field=3,value=0x12345678),19))
        self.assertEqual(p['position_rad'],[.25*a for a in range(6)])
        self.assertEqual(p['zero_state'],[1,1,1,0,1,1])
        self.assertEqual(p['offset_bits'][4],0x12345678)
        self.assertEqual(p['generation'],19)

    def test_bad_or_moving_motor_data_rejected(self):
        for field,value in [(0,6),(1,2),(2,2),(4,float('nan')),(4,15.9),(5,float('inf')),(5,.02001)]:
            with self.subTest(field=field,value=value),self.assertRaises(ValueError):
                pose_from_readback(readback(1,field,value),1)
        for data,seq in [(b'',1),(readback(),0)]:
            with self.assertRaises(ValueError):pose_from_readback(data,seq)

    def test_configured_fresh_read_saved_without_capture_config_or_enable(self):
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);path=root/'home.json';path.write_text('previous backup')
            with patch.object(console,'submit_request',return_value=(19,0,8,0)) as submit,patch('builtins.print'):
                data=console.capture_home_to_file(MemoryWorker(),19,path,root)
            self.assertEqual(submit.call_args.args[1:],(19,8))
            self.assertEqual(submit.call_count,1)
            self.assertEqual(load_pose(path),data)
            self.assertEqual((root/'previous_initial_pose_19.json').read_text(),'previous backup')
            evidence=json.loads((root/'home_capture_reads.jsonl').read_text())
            self.assertFalse(evidence['enable_requested'])
            self.assertFalse(evidence['PS_raw_reference_written'])

    def test_failed_read_does_not_use_old_cache_or_overwrite_file(self):
        for reply in [(19,5,8,0),(19,0,102,0),(19,0,8,1)]:
            with self.subTest(reply=reply),tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'home.json';path.write_text('previous backup')
                with patch.object(console,'submit_request',return_value=reply),self.assertRaises(ValueError):
                    console.capture_home_to_file(MemoryWorker(),19,path,Path(tmp))
                self.assertEqual(path.read_text(),'previous backup')

    def test_active_or_pending_stop_blocks_before_query(self):
        for worker in [MemoryWorker(before=report(active=1)),MemoryWorker(before=report(error=11)),MemoryWorker(stop=1)]:
            with patch.object(console,'submit_request') as submit,self.assertRaises(ValueError):
                console.capture_home_to_file(worker,19,Path('unused'),Path('unused'))
            submit.assert_not_called()

    def test_state_change_or_bad_data_blocks_save(self):
        workers=[MemoryWorker(after=report(state=226)),MemoryWorker(after=report(active=63)),MemoryWorker(data=readback(2,5,.03))]
        for worker in workers:
            with tempfile.TemporaryDirectory() as tmp:
                path=Path(tmp)/'home.json'
                with patch.object(console,'submit_request',return_value=(19,0,8,0)),self.assertRaises(ValueError):
                    console.capture_home_to_file(worker,19,path,Path(tmp))
                self.assertFalse(path.exists())

    def test_cold_boot_uses_original_capture(self):
        worker=MemoryWorker(before=report(state=0))
        with patch.object(console,'capture_to_file',return_value=b'captured') as capture:
            self.assertEqual(console.capture_home_to_file(worker,19,Path('a'),Path('b')),b'captured')
        capture.assert_called_once()

class ReconnectTests(unittest.TestCase):
    def attempt(self,changes=None,busy=0):
        snapshot={'application_matched':True,'state_number':1,'active_mask':0,'stop_confirmed':True,
                  'error':0,'fault_cause':0,'request_go':0,'stop_flag':1}
        snapshot.update(changes or {})
        class Bridge:
            def __init__(self):self.writes=[]
            def write(self,address,data):self.writes.append((address,data))
            def read(self,address,count):return struct.pack('<4I',0,0,0,busy) if count==4 else bytes(4)
        bridge=Bridge();symbols={'g_arm_reply':{'address':'0x100'},'g_arm_stop':{'address':'0x200'}}
        with patch.object(console,'application_snapshot',return_value=snapshot):
            console.reconnect_confirmed_disabled(bridge,symbols)
        return bridge.writes

    def test_only_confirmed_disabled_reconnect_clears_single_stop_word(self):
        self.assertEqual(self.attempt(),[(0x200,bytes(4))])
        self.assertEqual(self.attempt({'stop_flag':0}),[])

    def test_reconnect_never_clears_fault_active_unknown_or_pending_state(self):
        for changes in [{'state_number':s} for s in (0,3,11,226)]+[
                {'active_mask':1},{'stop_confirmed':False},{'error':11},{'fault_cause':9},
                {'request_go':1},{'application_matched':False},{'stop_flag':2}]:
            with self.subTest(changes=changes),self.assertRaises(RuntimeError):self.attempt(changes)
        with self.assertRaises(RuntimeError):self.attempt(busy=1)

if __name__=='__main__':unittest.main()
