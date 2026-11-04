"""Simple, manually chosen grasp point -> latched base-frame TCP goal.

No camera ownership, inference, ROS, automatic target replacement or execution.
"""
import copy
import json
from pathlib import Path
import secrets
import threading
import time
import cv2
import numpy as np
from robotarm_link.cartesian import fingerprint, validate_contract, validate_target
from robotarm_link.protocol import Client
from .geometry import Calibration
from .quality import sample_depth, box_iou
from .target_lock import current_point


class PickupService:
    def __init__(self, root):
        self.root = Path(root)
        self.lock = threading.RLock()
        self.snapshot = None
        self.candidate = None
        self.last_ack = None
        self.last_error = None
        try:
            self.last_ack = self.read('runtime/pickup/last_ack.json')
        except (OSError, ValueError):pass

    def read(self, path):
        return json.loads((self.root/path).read_text())

    def config(self):
        return self.read('config/pickup_tcp.json')

    def binding(self, obs):
        station = self.read('config/vision_station.json')
        context = {'setup_id':station.get('setup_id'), 'camera_fixed':station.get('camera_fixed'),
                   'intrinsic':obs['camera_intrinsics'], 'distortion':obs['camera_distortion']}
        cal = Calibration(self.root/'config/calibration/camera_to_base.json')
        if not cal.compatible(obs.get('camera_serial'), context) or not obs.get('base_calibration_valid') or obs.get('calibration_id') != cal.data.get('calibration_id') or obs.get('station_setup_id') != station.get('setup_id'):
            raise ValueError('相机未固定/外参绑定无效；先标定并重新启动视觉，不能发送相机坐标')
        return cal, context

    def selected(self, obs, track_id, now):
        rows = [d for d in obs.get('detections', []) if d.get('track_id') == track_id]
        if len(rows) != 1 or not rows[0].get('stable') or not current_point(obs, rows[0], now):
            raise ValueError('所选 ID 缺失、暂存或三维点尚未稳定，请等待新鲜观测')
        if obs.get('hand_present') is not False:
            raise ValueError('请把手移出作业区后再确认')
        return rows[0]

    def freeze(self, track_id):
        with self.lock:
            if type(track_id) is not int:
                raise ValueError('请选择工具 ID')
            with np.load(self.root/'runtime/vision/depth.npz', allow_pickle=False) as data:
                obs = json.loads(str(data['metadata']))
                depth, color = data['depth_m'].copy(), data['color_bgr'].copy()
            age = time.time()-obs.get('captured_at_unix_s', 0)
            if not 0 <= age <= .35:
                raise ValueError('RGB-D 过期；请主动启动视觉后再冻结')
            # The 5 Hz snapshot must be valid at capture, not relabelled as a current frame.
            target = self.selected(obs, track_id, obs['captured_at_unix_s'])
            if color.shape[:2] != depth.shape:
                raise ValueError('RGB / depth size mismatch')
            k = obs['camera_intrinsics']
            if obs.get('units') != 'm' or depth.shape != (k['height'], k['width']):
                raise ValueError('RGB-D metric units or factory image dimensions mismatch')
            ok, encoded = cv2.imencode('.jpg', color)
            if not ok:
                raise ValueError('Cannot encode frozen frame')
            self.snapshot = {'id':secrets.token_hex(16), 'obs':obs, 'target':copy.deepcopy(target),
                             'depth':depth, 'jpeg':encoded.tobytes()}
            self.candidate = None
            return {'snapshot_id':self.snapshot['id'], 'frame_id':obs['frame_id'],
                    'track_id':track_id, 'box_xyxy':target['box_xyxy'],
                    'image_size':[depth.shape[1], depth.shape[0]]}

    def snapshot_for(self, snapshot_id):
        s = self.snapshot
        if not s or s['id'] != snapshot_id:
            raise ValueError('冻结画面已被替换，请重新冻结')
        return s

    def image(self, snapshot_id):
        with self.lock:
            return self.snapshot_for(snapshot_id)['jpeg']

    def check_current(self, snapshot):
        old = snapshot['obs']
        if not 0 <= time.time()-old['captured_at_unix_s'] <= 30:
            raise ValueError('冻结超过 30 秒，请重新冻结和点选')
        obs = self.read('runtime/vision/latest.json')
        if any(old.get(k) != obs.get(k) for k in ('source_session_id', 'calibration_id', 'station_setup_id')):
            raise ValueError('视觉会话或标定改变，请重新选择')
        current = self.selected(obs, snapshot['target']['track_id'], time.time())
        before = snapshot['target']
        if current['class_name'] != before['class_name'] or box_iou(current['box_xyxy'], before['box_xyxy']) < .8:
            raise ValueError('所选工具姿态/检测框改变，请重新点选')
        a, b = before.get('surface_point_camera_m'), current.get('surface_point_camera_m')
        if a is None or b is None or not np.isfinite([a,b]).all() or np.linalg.norm(np.array(a)-b) > .005:
            raise ValueError('所选工具移动超过 5 mm，请重新点选')
        return obs

    def choose(self, snapshot_id, pixel):
        with self.lock:
            self.candidate = None
            s = self.snapshot_for(snapshot_id)
            self.check_current(s)
            if not isinstance(pixel, list) or len(pixel) != 2 or any(type(x) is not int for x in pixel):
                raise ValueError('请选择图内整数像素')
            u,v = pixel
            x1,y1,x2,y2 = s['target']['box_xyxy']
            if not x1 <= u <= x2 or not y1 <= v <= y2:
                raise ValueError('请点在所选工具的实际夹持表面；不要点桌面或检测框中心空隙')
            obs = s['obs']
            q = sample_depth(s['depth'], pixel, obs['camera_intrinsics'], obs['camera_distortion'], radius=1,
                             min_valid_fraction=.8, max_mad_m=.002, max_spread_m=.006)
            if not q['valid']:
                raise ValueError('夹持点真实深度不合格：'+q['reason'])
            # Preview camera measurements even before commissioning; never send them as base coordinates.
            result = {'snapshot_id':s['id'], 'pixel':pixel, 'surface_camera_m':q['point_camera_m'],
                      'depth_quality':q, 'target':None, 'blocked':None}
            try:
                cal, context = self.binding(obs)
                c = validate_contract(self.config()['contract'])
                p = c['profiles'].get(s['target']['class_name'])
                if not p:
                    raise ValueError('此类别尚无实测的夹持偏移/姿态配置')
                surface = np.array(cal.point_in_base(q['point_camera_m'], obs['camera_serial'], context))*1000
                goal = surface+np.array(p['surface_to_tcp_base_mm'])
                target = {'schema_version':1, 'task':'tabletop_pickup', 'frame_id':'base_link', 'units':'mm',
                          'tcp_id':c['tcp_id'], 'contract_id':fingerprint(c),
                          'calibration_id':obs['calibration_id'], 'source_session_id':obs['source_session_id'],
                          'track_id':s['target']['track_id'], 'class_name':s['target']['class_name'],
                          'point_kind':'manual_surface_with_measured_tcp_offset',
                          'orientation_convention':'R_base_tcp_xyzw', 'orientation_xyzw':p['orientation_xyzw'],
                          'surface_base_mm':surface.round(3).tolist(), 'position_mm':goal.round(3).tolist(),
                          'approach_mm':(goal+[0,0,p['approach_height_mm']]).round(3).tolist(),
                          'lift_mm':(goal+[0,0,p['lift_height_mm']]).round(3).tolist(),
                          'snapshot_id':s['id'], 'pixel':pixel}
                target['target_id'] = fingerprint(target)
                result['target'] = validate_target(target, c)
                # Project the TCP itself, not a bounding-box centre, into the frozen view.
                pc = np.linalg.inv(cal.matrix) @ np.r_[goal/1000, 1]
                k = obs['camera_intrinsics']
                if pc[2] > 0:
                    uv, _ = cv2.projectPoints(pc[:3].reshape(1,3), np.zeros(3), np.zeros(3),
                        np.array([[k['fx'],0,k['cx']],[0,k['fy'],k['cy']],[0,0,1.]]), np.array(obs['camera_distortion'],float))
                    result['tcp_pixel'] = uv.reshape(2).tolist()
            except (ValueError, KeyError) as exc:
                result['blocked'] = str(exc)
            self.candidate = copy.deepcopy(result)
            return result

    def send(self, target_id, confirmed):
        with self.lock:
            if confirmed is not True or not self.candidate or not self.candidate.get('target') or self.candidate['target']['target_id'] != target_id:
                raise ValueError('请先点选有效夹持位置，再确认当前目标')
            target = self.candidate['target']
            # Repeat UI clicks acknowledge the same immutable goal; never resend a stale goal.
            if self.last_ack and self.last_ack['target'] == target:
                return copy.deepcopy(self.last_ack)
            obs = self.check_current(self.snapshot)
            self.binding(obs)
            config = self.config()
            contract = config['contract']
            validate_target(target, contract)
            client = None
            try:
                client = Client(config['ps_host'], config['ps_port'])
                hello = client.request('hello')
                if 'cartesian_target' not in hello.get('capabilities', []) or hello.get('cartesian_contract_id') != fingerprint(contract):
                    raise ValueError('PS 不支持该坐标接口或基座/TCP/工作区约定不一致')
                reply = client.request('set_cartesian_target', target=target, confirmed=True)
                if (reply.get('accepted') is not True or reply.get('target') != target
                        or fingerprint(reply.get('target')) != fingerprint(target)
                        or reply.get('state') != 'target_received' or reply.get('execution_started') is not False):
                    raise ValueError('PS 未逐字段确认相同目标，不能显示为已接收')
                self.last_ack = {'target':copy.deepcopy(reply['target']), 'received_at_unix_s':time.time(),
                                 'receiver_mode':hello.get('mode'), 'state':'target_received',
                                 'snapshot_id':self.snapshot['id'], 'pixel':self.candidate['pixel'],
                                 'tcp_pixel':self.candidate.get('tcp_pixel'), 'execution_started':False}
                folder = self.root/'runtime/pickup';folder.mkdir(parents=True, exist_ok=True)
                tmp = folder/'last_ack.tmp'
                tmp.write_text(json.dumps(self.last_ack, ensure_ascii=False, indent=2, allow_nan=False))
                tmp.replace(folder/'last_ack.json')
                self.last_error = None
                return copy.deepcopy(self.last_ack)
            except (OSError, ValueError, ConnectionError) as exc:
                self.last_error = str(exc)
                raise
            finally:
                if client:
                    client.close()

    def status(self):
        with self.lock:
            try:
                validate_contract(self.config()['contract'])
                config_error = None
            except (OSError, ValueError, KeyError) as exc:
                config_error = str(exc)
            return copy.deepcopy({'candidate':self.candidate, 'last_ack':self.last_ack,
                                  'last_error':self.last_error, 'config_error':config_error,
                                  'execution_enabled':False})
