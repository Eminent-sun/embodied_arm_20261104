"""Coordinates are metres; never substitute an identity hand-eye calibration."""
import json
from pathlib import Path

import cv2
import numpy as np
from .quality import camera_signature


def depth_point(depth_m, pixel, intrinsic, distortion=None, radius=3):
    if depth_m is None or intrinsic is None:
        return None
    u, v = [int(round(x)) for x in pixel]
    h, w = depth_m.shape
    if not (0 <= u < w and 0 <= v < h):
        return None
    patch = depth_m[max(0, v-radius):min(h, v+radius+1), max(0, u-radius):min(w, u+radius+1)]
    valid = patch[np.isfinite(patch) & (patch > 0.15) & (patch < 3.0)]
    if len(valid) < 5:
        return None
    z = float(np.median(valid))
    matrix = np.array([[intrinsic['fx'], 0, intrinsic['cx']],
                       [0, intrinsic['fy'], intrinsic['cy']], [0, 0, 1]], dtype=float)
    ray = cv2.undistortPoints(np.array([[[u, v]]], dtype=float), matrix,
                             np.asarray(distortion or [0]*8, dtype=float))[0, 0]
    return [float(ray[0]*z), float(ray[1]*z), z]


class Calibration:
    def __init__(self, path):
        self.data = json.loads(Path(path).read_text())
        self.matrix = None
        if self.data.get('validated') is True:
            m = np.asarray(self.data.get('T_base_camera'), dtype=float)
            if m.shape != (4, 4) or not np.isfinite(m).all():
                raise ValueError('T_base_camera must be a finite 4x4 matrix')
            if not np.allclose(m[3], [0, 0, 0, 1]) or not np.allclose(m[:3, :3].T @ m[:3, :3], np.eye(3), atol=1e-5) or not np.isclose(np.linalg.det(m[:3, :3]), 1, atol=1e-5):
                raise ValueError('Invalid rigid transform')
            self.matrix = m

    def compatible(self, serial, context):
        if self.matrix is None or self.data.get('schema_version')!=2 or context is None:return False
        if self.data.get('mounting')!='eye_to_hand' or self.data.get('units')!='m':return False
        if self.data.get('parent_frame')!='base_link' or self.data.get('child_frame')!='camera_color_optical_frame':return False
        if not isinstance(self.data.get('calibration_id'),str) or len(self.data['calibration_id'])!=64:return False
        if self.data.get('physically_measured') is not True or self.data.get('camera_fixed') is not True:return False
        if context.get('camera_fixed') is not True or not context.get('setup_id'):return False
        if context['setup_id']!=self.data.get('setup_id') or not serial or serial!=self.data.get('camera_serial'):return False
        try:signature=camera_signature(context['intrinsic'],context['distortion'])
        except (KeyError,TypeError,ValueError):return False
        return signature==self.data.get('camera_model_signature')

    def point_in_base(self, point, serial, context=None):
        if point is None or self.matrix is None:
            return None
        if not self.compatible(serial,context):
            return None
        if np.asarray(point).shape!=(3,) or not np.isfinite(point).all():return None
        return (self.matrix @ np.array([*point, 1.0]))[:3].tolist()
