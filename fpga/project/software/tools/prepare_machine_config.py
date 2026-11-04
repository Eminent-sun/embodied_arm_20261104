"""Prepare a configuration from a freshly captured, supported HOME pose.

This only reads and writes PC files. It does not confirm physical HOME or the
board's stop behavior. Default output leaves stop_policy unset. The explicit
--for-home-calibration mode selects the previously adopted supported-arm
stop/disable policy, but keeps calibration=0 and requires real CAL/SAVEINITIAL.
"""
import argparse
import json
from pathlib import Path

from prepare_home_alignment import candidate, SIGN
from workflow_protocol import load_pose, pose_info

GAIN = SIGN


def prepare(record, gains=GAIN):
    pose = pose_info(record)
    home = candidate(record, gains)
    axes = []
    for i, (low, high) in enumerate(home['candidate_motor_safe_range_intersection_rad']):
        # ID3/ID5 sit on a one-sided HOME boundary. A 0.01 rad startup
        # measurement allowance avoids rejecting tiny encoder variation;
        # the PS planner has separate exact joint-target bounds.
        if i in (2, 4):
            low -= .01
        axes.append({
            'motor_id': i + 1,
            'model': 'RS00' if i == 1 else 'EL05',
            'expected_zero_state': pose['zero_state'][i],
            'expected_offset_bits': pose['offset_bits'][i],
            'gain': gains[i],
            'motor_zero_rad': home['candidate_motor_zero_rad'][i],
            'safe_min_rad': low,
            'safe_max_rad': high,
            'speed_rad_s': .5,
            'accel_rad_s2': .5,
            'velocity_trip_rad_s': .75,
            'following_error_rad': .099,
            'arrival_position_rad': .02,
            'arrival_velocity_rad_s': .03,
        })
    return {
        'calibration': 0,
        'stop_policy': None,
        'sample_ms': 50,
        'command_timeout_ms': 50,
        'arrival_timeout_ms': 1000,
        'max_job_ms': 55000,
        'start_joint_tolerance_rad': .01,
        'max_cartesian_error_mm': .5,
        'axis': axes,
        'source_home_pose_sha256': home['source_pose_sha256'],
        'nominal_home_joint_rad': list(home['nominal_urdf_home_joint_rad']),
        'configuration_status': 'NOT_LOADABLE_STOP_POLICY_AND_BOARD_VALIDATION_PENDING',
        'physical_home_alignment_verified': False,
        'ready_for_motion': False,
        'note': 'Software thresholds are first-motion proposals. Never copy an old '
                'HOME motor position to a new startup without a fresh READ/SAVEPOSE.'
    }


def prepare_for_home_calibration(record, gains=GAIN):
    config=prepare(record, gains)
    config['stop_policy']=0x53544f31
    config['configuration_status']='CONFIG_ONLY_REQUIRES_PHYSICAL_HOME_AND_CAL_SAVEINITIAL'
    config['stop_policy_basis']='Previously selected emergency disable with mechanical support; baseline user STOP confirmation passed in 26 ms; new Cartesian ELF retains stop logic with offline regression.'
    config['note']='Input pose must be freshly captured at the operator-selected URDF HOME. This file does not establish physical alignment or model calibration. CONFIG alone does not enable motion; explicit BEGIN/CAL/SAVEINITIAL remain required.'
    return config


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('home_pose_file', type=Path)
    parser.add_argument('output_file', type=Path)
    parser.add_argument('--for-home-calibration',action='store_true',
                        help='Prepare CONFIG/BEGIN/CAL input for an arm physically set at the selected URDF HOME; does not calibrate or enable motors')
    args = parser.parse_args()
    record=load_pose(args.home_pose_file)
    config = prepare_for_home_calibration(record) if args.for_home_calibration else prepare(record)
    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output_file.with_name(args.output_file.name + '.tmp')
    temporary.write_text(json.dumps(config, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.output_file)
    print(json.dumps({'configuration': str(args.output_file),
                      'source_home_pose_sha256': config['source_home_pose_sha256'],
                      'ready_for_motion': False}))


if __name__ == '__main__':
    main()
