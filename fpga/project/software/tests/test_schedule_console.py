"""Timing diagnostics decode; no debugger or motor connection."""
from pathlib import Path
import struct,sys,unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from workflow_console import timing_details

class TimingTests(unittest.TestCase):
    def test_dispatch_limit_is_distinct_from_sample_interval(self):
        d=timing_details(struct.pack('<16I',0x54494d31,1,255,15070,14969,101,4,5,9,13,14919,14969,2,1,50,100))
        self.assertEqual(d['dispatch_late_limit_ms'],100)
        self.assertEqual(d['sample_ms'],50)
        self.assertEqual(d['fault_reason'],'frame_dispatch_late')
    def test_uninitialized_or_wrong_version_not_interpreted(self):
        self.assertIsNone(timing_details(bytes(64)))
        self.assertIsNone(timing_details(struct.pack('<16I',0x54494d31,2,*([0]*14))))
    def test_frame_lateness_and_elapsed_are_distinct(self):
        d=timing_details(struct.pack('<16I',0x54494d31,1,191,23000,22800,200,40,30,70,83,22750,22800,2,1,50,0))
        self.assertEqual(d['fault_reason'],'frame_dispatch_late')
        self.assertEqual(d['elapsed_ms'],23000)
        self.assertEqual(d['lateness_ms'],200)
        self.assertEqual(d['max_service_ms'],83)
        self.assertEqual(d['schedule'],'verified_completion_plus_interval')
    def test_total_deadline(self):
        d=timing_details(struct.pack('<16I',0x54494d31,1,200,55001,0,0,0,0,0,0,0,0,1,1,50,0))
        self.assertEqual(d['fault_reason'],'total_job_deadline')

if __name__=='__main__':unittest.main()
