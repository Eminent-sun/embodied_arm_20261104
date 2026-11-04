"""Fixed region, measured moving hand, frozen plan target. Never commands a robot."""
import copy
import math
import time
import numpy as np
from .core import PlanningError, vector, pose_matrix, link_pose, make_waypoints

PALM_IDS = (0, 5, 9, 13, 17)


def region_config(cfg, name):
    region = cfg.get('handover_regions', {}).get(name)
    if not region or region.get('reviewed') is not True:
        raise PlanningError('交接区域、递送方向和人体隔离场景尚未测量审核')
    lo, hi = vector(region['min_m'], 3, 'region min'), vector(region['max_m'], 3, 'region max')
    if np.any(hi <= lo) or np.any(lo < cfg['workspace_min_m']) or np.any(hi > cfg['workspace_max_m']):
        raise PlanningError('交接区域必须在基座工作区内')
    offset = vector(region['palm_to_tcp_offset_base_m'], 3, 'palm to TCP offset')
    approach = vector(region['approach_offset_base_m'], 3, 'handover approach offset')
    if not .03 <= np.linalg.norm(offset) <= .3 or not .01 <= np.linalg.norm(approach) <= .3:
        raise PlanningError('交接目标必须留有经审核的手边偏移和接近距离')
    pose_matrix({'position_m': [0., 0., 0.], 'quaternion_xyzw': region['tcp_quaternion_xyzw']})
    for name, low, high in [('hand_margin_m', .01, .1), ('max_deviation_m', .002, .02)]:
        value = region.get(name)
        if type(value) not in (int, float) or not math.isfinite(value) or not low <= value <= high:
            raise PlanningError('Invalid handover ' + name)
    if region.get('body_scene_reviewed') is not True:
        raise PlanningError('手部之外的前臂/人体隔离和障碍场景尚未审核')
    return region


def inside(point, region):
    p = vector(point, 3, 'handover point')
    return bool(np.all(p >= region['min_m']) and np.all(p <= region['max_m']))


def hand_geometry(camera_points, raw_camera_points, transform, region):
    """Recompute metric base points; cached base coordinates are not trusted."""
    if len(camera_points) != 21 or len(raw_camera_points) != 21:
        raise PlanningError('交接需要完整且新鲜的 21 点真实深度')
    def convert(points):
        metric=[vector(p, 3, 'hand camera point') for p in points]
        if any(not .15 < p[2] < 3 for p in metric):
            raise PlanningError('手部真实深度不在有效范围内')
        return np.array([(transform @ np.r_[p, 1])[:3] for p in metric])
    points, raw = convert(camera_points), convert(raw_camera_points)
    if any(not inside(p.tolist(), region) for p in np.vstack([points, raw])):
        raise PlanningError('手部不在固定交接区域内')
    palm = np.mean(points[list(PALM_IDS)], axis=0)
    tcp = palm + vector(region['palm_to_tcp_offset_base_m'], 3, 'handover offset')
    if not inside(tcp.tolist(), region):
        raise PlanningError('手边 TCP 目标超出固定交接区域')
    all_points = np.vstack([points, raw]); margin = region['hand_margin_m']
    low, high = all_points.min(0) - margin, all_points.max(0) + margin
    box = {'size_m': (high-low).tolist(), 'pose': {
        'position_m': ((low+high)/2).tolist(), 'quaternion_xyzw': [0., 0., 0., 1.]}}
    if np.all(tcp >= low) and np.all(tcp <= high):
        raise PlanningError('递送 TCP 落入手部保守包络，请调整交接偏移')
    return {'palm_camera_m': np.mean(np.asarray(camera_points)[list(PALM_IDS)], axis=0).tolist(),
            'palm_base_m': palm.tolist(), 'points_base_m': points.tolist(), 'raw_points_base_m': raw.tolist(),
            'tcp_pose_base': {'position_m': tcp.tolist(), 'quaternion_xyzw': region['tcp_quaternion_xyzw']},
            'hand_collision_box': box}


def freeze_hand(obs, cfg, region_name, transform, hand_track_id=None, now=None):
    now = time.time() if now is None else now
    region = region_config(cfg, region_name)
    age = now - obs.get('captured_at_unix_s', 0)
    if obs.get('source_kind') != 'live_camera' or not 0 <= age < .15 or obs.get('base_calibration_valid') is not True:
        raise PlanningError('交接需要新鲜、已标定的真实手部观测')
    hands = obs.get('hands', [])
    # Until multi-person/body tracking is commissioned, any second or held hand
    # is ambiguous. Do not silently choose a different hand of the same handedness.
    if len(hands) != 1 or obs.get('hand_present') is not True:
        raise PlanningError('需要唯一接收手；多手、丢手或暂存手需重新确认')
    hand = hands[0]
    if type(hand.get('track_id')) is not int or (hand_track_id is not None and hand['track_id'] != hand_track_id):
        raise PlanningError('接收手 ID 改变，不自动切换')
    if hand.get('observed_this_frame') is not True or hand.get('palm_stable') is not True:
        raise PlanningError('接收手尚未停稳或正在暂存')
    points = hand.get('keypoints', [])
    if len(points) != 21 or [k.get('id') for k in points] != list(range(21)):
        raise PlanningError('手部关键点不完整')
    for k in points:
        a = k.get('coordinate_age_ms')
        if k.get('coordinate_fresh') is not True or type(a) not in (int, float) or not math.isfinite(a) or not 0 <= a+age*1000 <= 150:
            raise PlanningError('手部深度过期或缺失，不使用历史点生成交接目标')
    camera = [k.get('camera_m') for k in points]
    raw = [k.get('raw_camera_m') for k in points]
    geometry = hand_geometry(camera, raw, np.asarray(transform), region)
    lock = {k: obs.get(k) for k in ['source_session_id', 'calibration_id', 'station_setup_id', 'frame_id']}
    if not all(lock.get(k) for k in ['source_session_id', 'calibration_id', 'station_setup_id']):
        raise PlanningError('Missing hand identity/calibration provenance')
    lock.update(track_id=hand['track_id'], created_at_unix_s=now, camera_points=camera,
                raw_camera_points=raw, **geometry)
    return copy.deepcopy({'region_name': region_name, 'hand_lock': lock, **geometry})


def make_handover_waypoints(surface, profile, handover, cfg):
    region = region_config(cfg, handover['region_name'])
    tcp = handover['tcp_pose_base']
    pickup, obj = make_waypoints(surface, profile, {'tcp_pose': tcp}, cfg, pickup_only=True)
    stages = pickup[:3]
    for name, offset, method in [('transfer', region['approach_offset_base_m'], 'ompl'),
                                  ('present', [0., 0., 0.], 'cartesian')]:
        pose = copy.deepcopy(tcp)
        pose['position_m'] = (np.array(pose['position_m'])+offset).tolist()
        if not inside(pose['position_m'], region):
            raise PlanningError('交接接近点超出固定区域')
        stages.append({'name': name, 'method': method, 'tcp_pose_base': pose,
                       'link_pose_base': link_pose(pose, cfg['gripper']['link_to_tcp'])})
    return stages, obj


def review_hand(handover, obs, cfg, transform, now=None):
    lock = handover['hand_lock']
    try:
        if any(obs.get(k) != lock.get(k) for k in ['source_session_id', 'calibration_id', 'station_setup_id']):
            raise PlanningError('手部会话、标定或安装位改变')
        current = freeze_hand(obs, cfg, handover['region_name'], transform, lock['track_id'], now)
        before = np.asarray(lock['points_base_m'])
        after = np.asarray(current['points_base_m'])
        raw = np.asarray(current['raw_points_base_m'])
        # Raw points catch motion hidden by smoothing; fingers as well as palm matter.
        deviation = max(float(np.max(np.linalg.norm(after-before, axis=1))),
                        float(np.max(np.linalg.norm(raw-before, axis=1))))
        if deviation > region_config(cfg, handover['region_name'])['max_deviation_m']:
            raise PlanningError('接收手移动，冻结目标失效，需要停稳后重新规划确认')
        return {'state': 'observation_consistent', 'reason': '区域内接收手与冻结目标一致',
                'deviation_m': deviation, 'execution_enabled': False}
    except (ValueError, KeyError, TypeError) as exc:
        return {'state': 'requires_review', 'reason': str(exc), 'execution_enabled': False}


def review_plan_targets(req, obs, now=None, phase='pickup'):
    from robotarm_vision.target_lock import review_lock
    if phase not in ['pickup', 'delivery']:
        raise PlanningError('Unknown task phase')
    if req.get('task_kind') != 'tool_handover':
        return review_lock(req['target_lock'], obs, now)
    hand = review_hand(req['handover'], obs, req['config'], req['T_base_camera'], now)
    if hand['state'] != 'observation_consistent' or phase == 'delivery':
        return hand
    # Only the checked sole hand in the fixed region is expected. MoveIt still
    # treats its entire envelope as an obstacle, including during tool pickup.
    checked = copy.deepcopy(obs); checked['hand_present'] = False
    try:
        for target in checked.get('detections', []):
            if target.get('track_id') == req['target_lock'].get('track_id'):
                camera = vector(target.get('surface_point_camera_m'), 3, 'tool camera point')
                target['surface_point_base_m'] = (np.asarray(req['T_base_camera']) @ np.r_[camera, 1])[:3].tolist()
    except (ValueError, KeyError, TypeError) as exc:
        return {'state': 'requires_review', 'reason': str(exc), 'execution_enabled': False}
    return review_lock(req['target_lock'], checked, now)


class HandoverGuard:
    """Advisory integration guard. Invalidations latch until a NEW plan/confirmation.

    No I/O, no release command, no proof of receiver grip. Controller/force and
    operator confirmation integration remains commissioning work.
    """
    def __init__(self, request):
        if request.get('task_kind') != 'tool_handover':
            raise PlanningError('Handover request required')
        self.request = copy.deepcopy(request)
        self.invalidated = False

    def update(self, obs, phase='delivery', now=None):
        review = review_plan_targets(self.request, obs, now, phase)
        self.invalidated |= review['state'] != 'observation_consistent'
        return {**review, 'state': 'requires_replan' if self.invalidated else 'observation_consistent',
                'reason': '交接目标已失效，必须重新规划并确认' if self.invalidated else review['reason'],
                'hold_required': self.invalidated, 'automatic_release': False,
                'controller_commands_sent': False}


def handover_events():
    return [{'before': 'approach', 'gripper': 'open', 'requires': ['operator_task_confirmation']},
            {'after': 'grasp', 'gripper': 'close', 'requires': ['grasp_reached']},
            {'after': 'lift', 'barrier': 'confirm_delivery',
             'requires': ['grip_feedback', 'fresh_hand_review', 'current_encoder_state', 'operator_delivery_confirmation']},
            {'after': 'present', 'barrier': 'await_handover', 'automatic_release': False,
             'requires': ['robot_stopped', 'explicit_receiver_grip_confirmation', 'operator_release_confirmation'],
             'next': 'separate_gripper_open_ack_then_replan_retreat'}]
