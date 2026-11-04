"""No hardware. Verify launcher boundaries and explicit reconnect rules."""
import struct,sys,unittest
from pathlib import Path
from unittest.mock import patch,Mock
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'tools'))
import control_center as center
import workflow_console as console
import download_gripper
from test_workflow_bridge import MemoryBridge,LAYOUT

class ControlCenterTests(unittest.TestCase):
    def test_menu_and_guide_never_connect(self):
        for arguments,inputs in [(['center'],['0']),(['center','--guide'],[])]:
            with patch.object(sys,'argv',arguments),patch('builtins.input',side_effect=inputs),patch('builtins.print'),patch.object(center.subprocess,'run') as run,patch.object(console,'Bridge') as bridge:
                center.main();run.assert_not_called();bridge.assert_not_called()
    def test_failed_download_not_followed_by_connection_or_motion(self):
        with patch.object(download_gripper,'verify',return_value='0x100040'),patch.object(center.subprocess,'run',return_value=Mock(returncode=1)) as run:
            self.assertEqual(center.run_action('1','test-xsct'),1)
            self.assertEqual(run.call_count,1)
            self.assertIn('--download',run.call_args.args[0]);self.assertNotIn('--connect',run.call_args.args[0])
    def test_daily_control_never_downloads(self):
        with patch.object(download_gripper,'verify'),patch.object(center.subprocess,'run',return_value=Mock(returncode=0)) as run:
            self.assertEqual(center.run_action('2','test-xsct'),0)
            command=run.call_args.args[0]
            self.assertIn('--connect',command);self.assertIn('--id2-positive',command)
            self.assertNotIn('--download',command)
    def test_package_mismatch_prevents_child_launch(self):
        with patch.object(download_gripper,'verify',side_effect=ValueError('mismatch')),patch.object(center.subprocess,'run') as run:
            with self.assertRaises(ValueError):center.run_action('1','test-xsct')
            run.assert_not_called()
    def test_reconnect_never_clears_fault(self):
        bridge=MemoryBridge(state=226,stop=1,active=63)
        center.reconnect_cleanup(bridge,LAYOUT);self.assertEqual(bridge.writes,[])
    def test_reconnect_requires_PWM_disabled(self):
        bridge=MemoryBridge(stop=1);bridge.set_words('g_gripper_report',[0x53525631,1,0,0,1,1]+[0]*7)
        with self.assertRaisesRegex(RuntimeError,'PWM'):center.reconnect_cleanup(bridge,LAYOUT)
        self.assertEqual(bridge.writes,[])
    def test_idle_cleanup_only_clears_stop_word(self):
        bridge=MemoryBridge(stop=1)
        center.reconnect_cleanup(bridge,LAYOUT)
        self.assertEqual(bridge.writes,[(int(LAYOUT['g_arm_stop']['address'],0),[0])])
    def test_configured_reconnect_retains_calibration(self):
        bridge=MemoryBridge(stop=1,state=1)
        bridge.set_words('g_arm_report',[0x57465231,1,1,0,0,63,1,0,0,0,1,0])
        center.reconnect_cleanup(bridge,LAYOUT)
        self.assertEqual(bridge.writes,[(int(LAYOUT['g_arm_stop']['address'],0),[0])])

if __name__=='__main__':unittest.main()
