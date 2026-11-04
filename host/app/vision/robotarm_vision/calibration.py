"""Camera calibration math. Coordinates and transforms use metres, column vectors."""
import cv2
import numpy as np
import hashlib
import json
from .quality import camera_signature


def board_points(columns=9, rows=6, square_m=0.02):
    if columns < 3 or rows < 3 or not 0.001 <= square_m <= 0.2:
        raise ValueError('Invalid checkerboard dimensions / square size')
    points = np.zeros((columns * rows, 3), np.float32)
    points[:, :2] = np.mgrid[:columns, :rows].T.reshape(-1, 2) * square_m
    return points


def intrinsic_matrix(intrinsic):
    return np.array([[intrinsic['fx'], 0, intrinsic['cx']],
                     [0, intrinsic['fy'], intrinsic['cy']], [0, 0, 1]], float)


def rigid_fit(camera, base):
    camera, base = np.asarray(camera, float), np.asarray(base, float)
    if camera.shape != base.shape or camera.ndim != 2 or camera.shape[1] != 3 or len(camera) < 4:
        raise ValueError('Need at least four matched camera/base 3D points')
    if not np.isfinite(camera).all() or not np.isfinite(base).all():
        raise ValueError('Points must be finite metres')
    a, b = camera - camera.mean(axis=0), base - base.mean(axis=0)
    if np.linalg.svd(a, compute_uv=False)[1] < 0.02 or np.linalg.svd(b, compute_uv=False)[1] < 0.02:
        raise ValueError('Points are collinear or insufficiently spread; cover the workspace')
    u, _, vt = np.linalg.svd(a.T @ b)
    correction = np.diag([1, 1, np.linalg.det(vt.T @ u.T)])
    rotation = vt.T @ correction @ u.T
    transform = np.eye(4)
    transform[:3, :3] = rotation
    transform[:3, 3] = base.mean(axis=0) - rotation @ camera.mean(axis=0)
    return transform


def residuals(transform, camera, base):
    return np.linalg.norm(np.asarray(camera) @ transform[:3, :3].T + transform[:3, 3] - np.asarray(base), axis=1)


def robust_rigid_fit(camera, base, threshold_m=.01):
    """Fit on training correspondences only; never discard validation failures."""
    camera,base=np.asarray(camera,float),np.asarray(base,float)
    rigid_fit(camera,base)  # dimensions, finiteness and spread
    rng=np.random.default_rng(73);best=None;best_score=None
    for _ in range(256):
        subset=rng.choice(len(camera),4,replace=False)
        try:matrix=rigid_fit(camera[subset],base[subset])
        except ValueError:continue
        errors=residuals(matrix,camera,base);inside=errors<=threshold_m
        score=(int(inside.sum()),-float(np.median(errors)))
        if best_score is None or score>best_score:best,best_score=inside,score
    minimum=max(6,int(np.ceil(.75*len(camera))))
    if best is None or best.sum()<minimum:
        raise ValueError('Insufficient consistent fitting points; remeasure correspondences')
    for _ in range(5):
        matrix=rigid_fit(camera[best],base[best])
        inside=residuals(matrix,camera,base)<=threshold_m
        if inside.sum()<minimum:raise ValueError('Unstable calibration consensus')
        if np.array_equal(best,inside):return matrix,best
        best=inside
    return rigid_fit(camera[best],base[best]),best


def solve_external(data, rms_limit_m=0.01, max_limit_m=0.02):
    if not 0<rms_limit_m<=max_limit_m<=.02:
        raise ValueError('Thresholds must satisfy 0 < RMS <= max <= 0.02 m')
    if data.get('units') != 'm' or not data.get('camera_serial'):
        raise ValueError('Specify units=m and the physical camera serial')
    fit, check = data['fit'], data['validation']
    if len(fit) < 6 or len(check) < 4:
        raise ValueError('Need >=6 fitting and >=4 separately measured validation points')
    camera = np.asarray([p['camera_m'] for p in fit], float)
    base = np.asarray([p['base_m'] for p in fit], float)
    cval = np.asarray([p['camera_m'] for p in check], float)
    bval = np.asarray([p['base_m'] for p in check], float)
    if camera.shape != (len(fit),3) or base.shape != camera.shape:
        raise ValueError('Each fitting point must have three camera and three base coordinates')
    if cval.shape != (len(check),3) or bval.shape != cval.shape or not np.isfinite(cval).all() or not np.isfinite(bval).all():
        raise ValueError('Invalid validation points')
    if any(np.linalg.norm(camera - p,axis=1).min() < 0.005 for p in cval):
        raise ValueError('Validation points overlap fitting points; measure independent locations')
    if any(np.linalg.norm(base-p,axis=1).min()<.005 for p in bval):
        raise ValueError('Validation base locations overlap fitting points')
    for points in [base,bval]:
        if not np.isfinite(points).all() or np.max(np.abs(points))>5:
            raise ValueError('Base coordinates exceed this desktop project metric range; check units')
    for points in [camera, cval]:
        if not np.isfinite(points).all() or np.any((points[:,2]<0.15)|(points[:,2]>3)):
            raise ValueError('Camera points must be finite metres with depth 0.15 to 3 m')
        distances=np.linalg.norm(points[:,None,:]-points[None,:,:],axis=2)
        np.fill_diagonal(distances,np.inf)
        if distances.min()<0.005:
            raise ValueError('Repeated measurement locations; use spatially distinct points')
    # Validation must span an area, not just lie along a line.
    for points in [cval,bval]:
        if np.linalg.svd(points-points.mean(axis=0),compute_uv=False)[1]<.02:
            raise ValueError('Validation points must independently span the work area')
    transform,inliers = robust_rigid_fit(camera, base, threshold_m=rms_limit_m)
    fit_error, val_error = residuals(transform,camera,base), residuals(transform,cval,bval)
    rms = float(np.sqrt(np.mean(val_error**2)))
    measured = data.get('physically_measured') is True
    binding_reasons=[];signature=None
    if data.get('camera_fixed') is not True:binding_reasons.append('camera_not_fixed')
    if not isinstance(data.get('setup_id'),str) or not data['setup_id'].strip():binding_reasons.append('missing_setup_id')
    try:signature=camera_signature(data['factory_intrinsic'],data['factory_distortion'])
    except (KeyError,TypeError,ValueError):binding_reasons.append('missing_or_invalid_camera_model')
    passed = measured and not binding_reasons and rms <= rms_limit_m and float(val_error.max()) <= max_limit_m
    calibration_id=hashlib.sha256(json.dumps({'measurements':data,'matrix':transform.tolist()},sort_keys=True,allow_nan=False).encode()).hexdigest()
    return {'schema_version':2,'camera_serial':data['camera_serial'], 'units':'m',
            'mounting':'eye_to_hand','parent_frame':'base_link','child_frame':'camera_color_optical_frame',
            'setup_id':data.get('setup_id'),'camera_fixed':data.get('camera_fixed') is True,
            'camera_model_signature':signature,'calibration_id':calibration_id,'binding_errors':binding_reasons,
            'convention':'p_base = T_base_camera @ [p_camera, 1]',
            'T_base_camera':transform.tolist(), 'validated':passed,
            'physically_measured':measured, 'fit_rms_m':float(np.sqrt(np.mean(fit_error**2))),
            'fit_inlier_rms_m':float(np.sqrt(np.mean(fit_error[inliers]**2))),
            'fit_inlier_indices':np.flatnonzero(inliers).tolist(),
            'fit_excluded_indices':np.flatnonzero(~inliers).tolist(),
            'fit_errors_m':fit_error.tolist(),
            'validation_rms_m':rms,'validation_max_m':float(val_error.max()),
            'validation_errors_m':val_error.tolist(), 'rms_limit_m':rms_limit_m,'max_limit_m':max_limit_m}


def solve_intrinsic(corners, image_size, object_points):
    if len(corners) < 15:
        raise ValueError('Capture at least 15 distinct views (12 fitting + >=3 held out)')
    train = [i for i in range(len(corners)) if i % 5 != 0]
    heldout = [i for i in range(len(corners)) if i % 5 == 0]
    if len(train) < 12:
        raise ValueError('Not enough fitting views')
    rms, matrix, distortion, rotations, translations = cv2.calibrateCamera(
        [object_points]*len(train), [corners[i] for i in train], image_size, None, None)
    errors = []
    for i in heldout:
        ok, rvec, tvec = cv2.solvePnP(object_points, corners[i], matrix, distortion)
        if not ok:
            raise ValueError('Held-out pose estimation failed')
        projected, _ = cv2.projectPoints(object_points,rvec,tvec,matrix,distortion)
        errors.append(float(np.sqrt(np.mean(np.sum((projected-corners[i])**2,axis=2)))))
    centers = np.array([c.reshape(-1,2).mean(axis=0) for c in corners])
    cells = {(min(2,int(x/image_size[0]*3)),min(2,int(y/image_size[1]*3))) for x,y in centers}
    normals = [cv2.Rodrigues(r)[0][:,2] for r in rotations]
    angle = float(max(np.degrees(np.arccos(np.clip(abs(a@b),0,1))) for a in normals for b in normals))
    passed = bool(rms < 0.8 and max(errors)<1.0 and len(cells)>=4 and angle>=15)
    return {'matrix':matrix.tolist(),'distortion':distortion.ravel().tolist(),
            'image_size':list(image_size),'fit_rms_px':float(rms),'heldout_rms_px':errors,
            'fitting_views':train,'heldout_views':heldout,'covered_grid_cells':len(cells),
            'max_normal_angle_deg':angle,'quality_passed':passed,
            'note':'Color intrinsic diagnostic only; SDK RGB-D alignment continues using factory calibration.'}
