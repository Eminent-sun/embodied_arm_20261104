"""Prepare a review-only RA8P1 URDF HOME alignment from a fresh motor pose.

This tool reads a PC file only. It never connects to XSCT or changes a motor.
The physical pose was described as approximately HOME, so the result cannot
be submitted as a confirmed motion configuration.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path

from workflow_protocol import load_pose, pose_info

HOME = (0.0, 1.57, 0.0, 0.0, 1.57, 0.0)
SIGN = (-1.0, -1.0, -1.0, -1.0, -1.0, 1.0)
ID2_POSITIVE_CANDIDATE = (-1.0, 1.0, -1.0, -1.0, -1.0, 1.0)
JOINT_MIN = (-3.14, 0.395710, -3.027351, -3.14, -1.545172, -3.14)
JOINT_MAX = (3.14, 3.223736, 0.074481, 3.14, 1.57, 3.14)
# Physical travel from the captured HOME motor position, in the operator's
# front-facing view. ID3 and ID5 clockwise mechPos increase was confirmed by
# separate manual read-only measurements on 2026-11-04. ID1/2/4 are symmetric;
# ID6 has no additional operator limit and keeps the URDF motor projection.
PHYSICAL_MOTOR_DELTA_DEG = ((-100.0, 100.0), (-90.0, 90.0),
                            (0.0, 120.0), (-120.0, 120.0),
                            (0.0, 100.0), None)


def candidate(record, gains=SIGN):
    if len(gains)!=6 or any(g not in (-1.0,1.0) for g in gains):
        raise ValueError('A verified direct-drive direction is required for all six axes')
    pose = pose_info(record)
    motor_zero = [pose['position_rad'][i] - gains[i] * HOME[i] for i in range(6)]
    projected_limits = [sorted((motor_zero[i] + gains[i] * JOINT_MIN[i],
                                motor_zero[i] + gains[i] * JOINT_MAX[i]))
                        for i in range(6)]
    physical_limits = [None if delta is None else
                       [pose['position_rad'][i] + math.radians(delta[0]),
                        pose['position_rad'][i] + math.radians(delta[1])]
                       for i, delta in enumerate(PHYSICAL_MOTOR_DELTA_DEG)]
    allowed_limits = [[max(projected_limits[i][0], physical_limits[i][0]) if physical_limits[i] else projected_limits[i][0],
                       min(projected_limits[i][1], physical_limits[i][1]) if physical_limits[i] else projected_limits[i][1]]
                      for i in range(6)]
    for i, (lo, hi) in enumerate(allowed_limits):
        # The same decimal HOME constant is represented by float32 motor data;
        # snap only rounding-level differences, never a physical displacement.
        if 0 < lo - pose['position_rad'][i] < 1e-6:
            allowed_limits[i][0] = pose['position_rad'][i]
        if 0 < pose['position_rad'][i] - hi < 1e-6:
            allowed_limits[i][1] = pose['position_rad'][i]
    if any(not lo < hi or not lo <= pose['position_rad'][i] <= hi
           for i, (lo, hi) in enumerate(allowed_limits)):
        raise ValueError('HOME pose lies outside the intersection of physical and URDF ranges')
    return {
        'format': 'ZYNQ_ARM_URDF_HOME_CANDIDATE_V1',
        'source_pose_sha256': hashlib.sha256(record).hexdigest(),
        'motor_ids': list(range(1, 7)),
        'captured_motor_rad': pose['position_rad'],
        'nominal_urdf_home_joint_rad': HOME,
        'home_as_nominal_trajectory_origin': True,
        'motor_gain': tuple(gains),
        'candidate_motor_zero_rad': motor_zero,
        'urdf_joint_min_rad': JOINT_MIN,
        'urdf_joint_max_rad': JOINT_MAX,
        'projected_motor_range_from_urdf_rad': projected_limits,
        'physical_motor_delta_deg_from_home': PHYSICAL_MOTOR_DELTA_DEG,
        'clockwise_mechpos_increases_confirmed_for_id3_id5': True,
        'physical_motor_range_from_home_rad': physical_limits,
        'candidate_motor_safe_range_intersection_rad': allowed_limits,
        'physical_home_alignment_verified': False,
        'physical_safe_range_verified': False,
        'ready_for_motion': False,
        'storage': 'PC file only; regenerate from a fresh motor capture after power/program reset',
        'note': 'The captured physical pose was only approximately RA8P1 HOME. '
                'User-provided physical travel and URDF limits are intersected, '
                'but this record does not certify current board state, stop behavior or actual HOME alignment.'
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('pose_file', type=Path)
    parser.add_argument('output_file', type=Path)
    args = parser.parse_args()
    record = load_pose(args.pose_file)
    result = candidate(record)
    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    temporary = args.output_file.with_name(args.output_file.name + '.tmp')
    temporary.write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
    temporary.replace(args.output_file)
    print(json.dumps({'candidate': str(args.output_file), 'ready_for_motion': False,
                      'source_pose_sha256': result['source_pose_sha256']}))


if __name__ == '__main__':
    main()
