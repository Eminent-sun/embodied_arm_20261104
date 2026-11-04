"""Confirmed TCP goals; standard-library contract shared by AI PC and AX7010 PS."""
import hashlib
import json
import math
from .protocol import ProtocolError


def fingerprint(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()).hexdigest()


def vector(value, size, label):
    if not isinstance(value, list) or len(value) != size or any(type(x) not in (int, float) or not math.isfinite(x) for x in value):
        raise ProtocolError(f'Invalid {label}')
    return value


def validate_contract(c):
    if not isinstance(c, dict) or c.get('schema_version') != 1 or c.get('validated') is not True or c.get('frame_id') != 'base_link' or c.get('units') != 'mm':
        raise ProtocolError('请先实测并确认基座、TCP、工作区和抓取配置')
    if any(not isinstance(c.get(k), str) or not c[k].strip() for k in ('tcp_id','robot_model_id','base_definition')):
        raise ProtocolError('TCP / PS robot model / base definition missing')
    lo = vector(c.get('workspace_min_mm'), 3, 'workspace minimum')
    hi = vector(c.get('workspace_max_mm'), 3, 'workspace maximum')
    if any(not -5000 <= a < b <= 5000 for a, b in zip(lo, hi)):
        raise ProtocolError('Invalid measured workspace')
    if not isinstance(c.get('profiles'), dict):
        raise ProtocolError('Grasp profiles must be an object')
    for name, profile in c['profiles'].items():
        if name not in ('screwdriver', 'pliers', 'scissors', 'tweezers'):
            raise ProtocolError('Unknown tool class')
        if not isinstance(profile, dict) or profile.get('validated') is not True:
            raise ProtocolError('抓取偏移/姿态尚未实测')
        vector(profile.get('surface_to_tcp_base_mm'), 3, 'surface-to-TCP offset')
        q = vector(profile.get('orientation_xyzw'), 4, 'TCP quaternion')
        if abs(sum(x*x for x in q)-1) > 1e-5:
            raise ProtocolError('TCP quaternion must be unit length')
        for k in ('approach_height_mm', 'lift_height_mm'):
            h = profile.get(k)
            if type(h) not in (int, float) or not math.isfinite(h) or not 1 <= h <= 300:
                raise ProtocolError('Invalid approach/lift height')
    if not c.get('profiles'):
        raise ProtocolError('No measured grasp profiles')
    return c


def validate_target(t, contract):
    validate_contract(contract)
    if not isinstance(t, dict) or t.get('schema_version') != 1 or t.get('task') != 'tabletop_pickup':
        raise ProtocolError('Invalid Cartesian target schema')
    for k, expected in [('frame_id', 'base_link'), ('units', 'mm'), ('tcp_id', contract['tcp_id']),
                        ('contract_id', fingerprint(contract)), ('orientation_convention', 'R_base_tcp_xyzw')]:
        if t.get(k) != expected:
            raise ProtocolError(f'Cartesian contract mismatch: {k}')
    for k in ('target_id', 'calibration_id'):
        value = t.get(k)
        if not isinstance(value, str) or len(value) != 64 or any(ch not in '0123456789abcdef' for ch in value):
            raise ProtocolError(f'Invalid {k}')
    if not isinstance(t.get('source_session_id'), str) or not t['source_session_id'] or type(t.get('track_id')) is not int:
        raise ProtocolError('Missing explicit target identity')
    if t.get('point_kind') != 'manual_surface_with_measured_tcp_offset':
        raise ProtocolError('Box centres are not grasp poses')
    p = contract['profiles'].get(t.get('class_name'))
    if not p:
        raise ProtocolError('No profile for this tool')
    q = vector(t.get('orientation_xyzw'), 4, 'orientation')
    if q != p['orientation_xyzw']:
        raise ProtocolError('Orientation differs from measured profile')
    goal = vector(t.get('position_mm'), 3, 'TCP position')
    surface = vector(t.get('surface_base_mm'), 3, 'surface point')
    if any(abs(x-s-d) > .002 for x,s,d in zip(goal,surface,p['surface_to_tcp_base_mm'])):
        raise ProtocolError('TCP offset mismatch')
    for key, height in [('approach_mm', p['approach_height_mm']), ('lift_mm', p['lift_height_mm'])]:
        v = vector(t.get(key), 3, key)
        if any(abs(x-y) > .002 for x,y in zip(v, [goal[0], goal[1], goal[2]+height])):
            raise ProtocolError('Approach/lift must follow measured base +Z')
    for key in ('position_mm', 'approach_mm', 'lift_mm'):
        if any(not a <= x <= b for x,a,b in zip(t[key], contract['workspace_min_mm'], contract['workspace_max_mm'])):
            raise ProtocolError(f'{key} outside measured workspace')
    unsigned = {k:v for k,v in t.items() if k != 'target_id'}
    if fingerprint(unsigned) != t['target_id']:
        raise ProtocolError('Target digest mismatch')
    return t
