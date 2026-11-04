import time
import unittest
from robotarm_vision.dashboard import proposal


class TaskGateTest(unittest.TestCase):
    def test_missing_training_and_calibration_cannot_execute(self):
        result=proposal('pliers','bin_a',{'captured_at_unix_s':time.time(),'supported_tool_classes':['scissors']},
                        {'validated':False,'place_zones':{},'gripper':{}})
        self.assertFalse(result['execution_enabled'])
        self.assertTrue(any('权重' in s for s in result['blockers']))
        self.assertTrue(any('外参' in s for s in result['blockers']))

    def test_stale_and_hand_observations_block(self):
        result=proposal('scissors','bin_a',{'captured_at_unix_s':time.time()-10,'hand_present':True},
                        {'validated':False,'place_zones':{},'gripper':{}})
        self.assertTrue(any('0.5秒' in s for s in result['blockers']))
        self.assertTrue(any('检测到手' in s for s in result['blockers']))


if __name__=='__main__':unittest.main()
