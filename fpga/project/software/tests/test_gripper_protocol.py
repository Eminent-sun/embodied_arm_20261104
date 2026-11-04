import struct,sys,unittest
from pathlib import Path
from unittest.mock import Mock,patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
from gripper_protocol import gripper_payload,gripper_report
from workflow_protocol import make_request
import workflow_console as console

class GripperProtocolTests(unittest.TestCase):
    def test_original_presets(self):
        for name,value in [('OPEN',1220),('CLOSE',1360),('INIT',1110)]:
            data=gripper_payload([name]);self.assertEqual(len(data),468)
            self.assertEqual(struct.unpack('<6I',data[:24]),(0x47525031,1,2,value,10,5))
            self.assertFalse(any(data[24:]));self.assertEqual(len(make_request(1,111,record=data)),836)
    def test_basic_off_status(self):
        for name,action in [('OFF',1),('STATUS',0)]:
            self.assertEqual(struct.unpack('<6I',gripper_payload([name])[:24]),(0x47525031,1,action,0,0,0))
    def test_ps_speed_and_range(self):
        self.assertEqual(struct.unpack('<6I',gripper_payload(['US','1110','2','40'])[:24]),(0x47525031,1,2,1110,2,2))
        self.assertEqual(struct.unpack('<6I',gripper_payload(['CLOSE','1','1000'])[:24])[-2:],(1,50))
    def test_reject_invalid_commands(self):
        for params in [[],['ANGLE','90'],['US'],['US','1000'],['US','1109'],['US','1491'],['US','nan'],['OPEN','0','20'],['OPEN','11','20'],['OPEN','1','21'],['OPEN','10'],['OFF','extra'],['STATUS','extra']]:
            with self.subTest(params=params),self.assertRaises(ValueError):gripper_payload(params)
    def test_no_false_physical_arrival_claim(self):
        report=gripper_report(struct.pack('<13I',0x53525631,1,7,0,1,1,0,0,1220,1220,10,5,100))
        self.assertTrue(report['pwm_enabled']);self.assertFalse(report['pulse_ramping'])
        self.assertFalse(report['mechanical_position_feedback'])


    def step_state(self,target=1400,**changes):
        state=gripper_report(struct.pack('<13I',0x53525631,1,7,0,1,1,0,0,target,target,10,5,100))
        state.update(changes);return state
    def step_target(self,command,state):
        payload=gripper_payload([command],state)
        self.assertEqual(len(payload),468)
        words=struct.unpack('<6I',payload[:24])
        self.assertEqual(words[:3],(0x47525031,1,2));self.assertEqual(words[4:],(10,5))
        self.assertFalse(any(payload[24:]));return words[3]
    def test_clicks_are_ten_us_and_reversible(self):
        state=self.step_state()
        for command,expected in [('OPENSTEP',1390),('openstep',1380),('CLOSESTEP',1390)]:
            state['target_pulse_us']=self.step_target(command,state)
            self.assertEqual(state['target_pulse_us'],expected)
    def test_full_travel_and_saturated_limits(self):
        state=self.step_state()
        for _ in range(29):state['target_pulse_us']=self.step_target('OPENSTEP',state)
        self.assertEqual(state['target_pulse_us'],1110)
        self.assertEqual(self.step_target('OPENSTEP',state),1110)
        for _ in range(38):state['target_pulse_us']=self.step_target('CLOSESTEP',state)
        self.assertEqual(state['target_pulse_us'],1490)
        self.assertEqual(self.step_target('CLOSESTEP',state),1490)
        for target,command,expected in [(1115,'OPENSTEP',1110),(1485,'CLOSESTEP',1490)]:
            self.assertEqual(self.step_target(command,self.step_state(target)),expected)
    def test_ramping_uses_accepted_target_not_active_pulse(self):
        state=self.step_state(1380,active_pulse_us=1400,pulse_ramping=True)
        self.assertEqual(self.step_target('OPENSTEP',state),1370)
    def test_step_rejects_disabled_expired_absent_and_bad_status(self):
        for changes in [{'pwm_enabled':False},{'lease_expired':True},{'present':False},{'result':42},{'target_pulse_us':0},{'target_pulse_us':1491}]:
            with self.subTest(changes=changes),self.assertRaises(ValueError):
                self.step_target('OPENSTEP',self.step_state(**changes))
        for params in [['OPENSTEP'],['CLOSESTEP','10']]:
            with self.assertRaises(ValueError):gripper_payload(params)
    def test_console_queries_fresh_status_before_resolving_step(self):
        worker=Mock();worker.read.return_value=struct.pack('<13I',0x53525631,1,7,0,1,1,1,0,1400,1380,10,5,100)
        with patch.object(console,'submit_request',return_value=(7,0,111,0)) as submit:
            result=console.gripper_step_payload(worker,7,['OPENSTEP'])
        submit.assert_called_once_with(worker,7,111,record=gripper_payload(['STATUS']))
        worker.read.assert_called_once_with('g_gripper_report',13)
        self.assertEqual(struct.unpack('<6I',result[:24])[3],1370)
    def test_console_rejects_failed_or_stale_query(self):
        for reply,report_seq in [((7,42,111,0),7),((7,0,111,1),7),((7,0,111,0),6)]:
            worker=Mock();worker.read.return_value=struct.pack('<13I',0x53525631,1,report_seq,0,1,1,0,0,1400,1400,10,5,100)
            with patch.object(console,'submit_request',return_value=reply) as submit,self.assertRaises(ValueError):
                console.gripper_step_payload(worker,7,['OPENSTEP'])
            self.assertEqual(submit.call_count,1)
    def test_console_rejects_step_arguments_without_query(self):
        with patch.object(console,'submit_request') as submit,self.assertRaises(ValueError):
            console.gripper_step_payload(Mock(),7,['CLOSESTEP','10'])
        submit.assert_not_called()

if __name__=='__main__':unittest.main()
