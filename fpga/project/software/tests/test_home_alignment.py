"""PC-only checks for the provisional RA8P1 URDF HOME mapping."""
import math
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from prepare_home_alignment import candidate, HOME, SIGN, PHYSICAL_MOTOR_DELTA_DEG
from workflow_protocol import save_pose, load_pose


class HomeAlignmentTests(unittest.TestCase):
    def test_candidate_uses_exact_ra8_home_and_source_pose(self):
        raw = (ROOT / 'reports/arm_initial_pose_test.bin').read_bytes()
        with tempfile.TemporaryDirectory() as folder:
            pose_file = Path(folder) / 'pose.json'
            save_pose(pose_file, raw)
            result = candidate(load_pose(pose_file))
        self.assertEqual(result['nominal_urdf_home_joint_rad'], HOME)
        self.assertEqual(result['motor_gain'], SIGN)
        self.assertFalse(result['ready_for_motion'])
        self.assertFalse(result['physical_home_alignment_verified'])
        self.assertEqual(len(result['projected_motor_range_from_urdf_rad']), 6)
        self.assertTrue(result['clockwise_mechpos_increases_confirmed_for_id3_id5'])
        self.assertEqual(result['physical_motor_delta_deg_from_home'], PHYSICAL_MOTOR_DELTA_DEG)
        for i in range(6):
            actual = result['captured_motor_rad'][i]
            self.assertTrue(math.isclose(result['candidate_motor_zero_rad'][i] +
                                         SIGN[i] * HOME[i], actual, abs_tol=1e-7))
            low, high = result['projected_motor_range_from_urdf_rad'][i]
            self.assertLess(low, high)
            self.assertLessEqual(low, actual)
            self.assertGreaterEqual(high, actual)
            safe_low, safe_high = result['candidate_motor_safe_range_intersection_rad'][i]
            self.assertLessEqual(safe_low, actual)
            self.assertGreaterEqual(safe_high, actual)
        for i, span in ((2, 120.0), (4, 100.0)):
            home_motor = result['captured_motor_rad'][i]
            safe_low, safe_high = result['candidate_motor_safe_range_intersection_rad'][i]
            self.assertAlmostEqual(safe_low, home_motor)
            self.assertAlmostEqual(safe_high - home_motor, math.radians(span), places=5)


if __name__ == '__main__':
    unittest.main()
