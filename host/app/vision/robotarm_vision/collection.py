"""Local RGB-D dataset collection. No detector, ROS import or robot commands.

One worker owns the camera, recorder and dataset writes. HTTP threads submit
serialized commands; the preview and dataset contain clean, unannotated images.
"""
from collections import deque
from datetime import datetime
from zoneinfo import ZoneInfo
from pathlib import Path
import copy
import hashlib
import json
import os
import queue
import re
import secrets
import shutil
import threading
import time
import cv2
import numpy as np

CLASSES = ['screwdriver', 'pliers', 'scissors', 'tweezers']
SPLITS = ['train', 'val', 'test', 'exclude']
ISSUES = ['normal', 'missed', 'wrong_class', 'false_positive', 'occluded']


def atomic_json(path, data):
    temp = path.with_suffix(path.suffix + '.tmp')
    temp.write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False))
    os.replace(temp, path)


def quality(image, depth):
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    p95 = float(np.percentile(gray, 95))
    sharpness = float(cv2.Laplacian(gray, cv2.CV_64F).var())
    return {'mean_luma': float(gray.mean()), 'p95_luma': p95,
            'laplacian_variance': sharpness, 'almost_black': p95 < 12,
            'blur_warning': sharpness < 20,
            'depth_valid_ratio': float(np.mean(np.isfinite(depth) & (depth > .15) & (depth < 3))) if depth is not None else 0.}


class CollectionService:
    def __init__(self, root, camera_factory=None, min_free_bytes=2*1024**3):
        self.root = Path(root)
        self.directory = self.root/'datasets/site_tools/web_sessions'
        self.directory.mkdir(parents=True, exist_ok=True)
        self.camera_factory = camera_factory
        self.min_free_bytes = min_free_bytes
        self.lock = threading.RLock()
        self.commands = queue.Queue(maxsize=12)
        self.stop_event = threading.Event()
        self.thread = None
        self.camera_state = 'stopped'; self.error = ''; self.notice = ''
        self.frame = None; self.frame_id = 0; self.previews = {}; self.frame_quality = {}
        self.stamps = deque(maxlen=90)
        self.session = None; self.folder = None; self.writer = None; self.frame_log = None
        self.record = None; self.last_sample = None; self.last_sample_frame = None
        self.last_auto_sample = 0.; self.last_manifest = 0.; self.last_disk_check = 0.

    def start_preview(self):
        with self.lock:
            if self.thread and self.thread.is_alive():return self.status()
            self.stop_event.clear(); self.frame = None; self.previews = {}; self.stamps.clear()
            self.camera_state = 'starting'; self.error = ''; self.notice = ''
            self.thread = threading.Thread(target=self._run, name='rgbd-collection', daemon=True)
            self.thread.start()
        return self.status()

    def stop_preview(self):
        with self.lock:
            if self.thread and self.thread.is_alive():
                self.camera_state = 'stopping'; self.stop_event.set()
        return self.status()

    def close(self):
        self.stop_preview()
        if self.thread:self.thread.join(timeout=23)

    def submit(self, action, data=None):
        if action not in ['new_session', 'snapshot', 'record_start', 'record_stop']:
            raise ValueError('Unknown collection action')
        with self.lock:
            if self.camera_state != 'running':raise ValueError('请先开启相机并等待新鲜画面')
        command = {'action': action, 'data': data or {}, 'done': threading.Event(),
                   'cancelled': threading.Event(), 'deadline': time.monotonic()+19}
        try:self.commands.put_nowait(command)
        except queue.Full:raise ValueError('采集操作繁忙，请稍后重试')
        if not command['done'].wait(20):
            command['cancelled'].set();raise ValueError('采集响应超时，请检查相机状态')
        if command.get('error'):raise ValueError(command['error'])
        return command['result']

    def status(self):
        with self.lock:
            age = time.monotonic()-self.frame.received_monotonic if self.frame else None
            fresh = self.camera_state == 'running' and age is not None and 0 <= age < .5
            fps = (len(self.stamps)-1)/(self.stamps[-1]-self.stamps[0]) if len(self.stamps)>1 else 0.
            session = copy.deepcopy(self.session)
            if session:
                session['sample_count'] = len(session['samples'])
                session['samples'] = session['samples'][-24:]
            record = copy.deepcopy(self.record)
            if record:record['elapsed_s'] = time.monotonic()-self.record_started
            return {'camera_state': self.camera_state, 'fresh': fresh, 'frame_age_ms': age*1000 if age is not None else None,
                    'frame_id': self.frame_id, 'fps': fps, 'camera_serial': self.frame.serial if self.frame else None,
                    'image_size': list(self.frame.color.shape[1::-1]) if self.frame else None,
                    'quality': copy.deepcopy(self.frame_quality), 'error': self.error, 'notice': self.notice,
                    'session': session, 'recording': record, 'dataset_directory': str(self.directory),
                    'inference_running': False, 'execution_enabled': False}

    def preview(self, kind):
        if kind not in ['color', 'depth']:raise ValueError('Unknown preview kind')
        with self.lock:
            if not self.frame or self.camera_state != 'running' or time.monotonic()-self.frame.received_monotonic > .5:
                return None
            return self.frame_id, self.previews.get(kind)

    def sessions(self):
        result = []
        for path in sorted(self.directory.glob('table_*/session.json'), reverse=True)[:100]:
            try:
                data = json.loads(path.read_text())
                result.append({k: data[k] for k in ['session_id', 'created_at', 'split', 'scene', 'status']} |
                              {'sample_count': len(data['samples']), 'video_count': len(data['videos'])})
            except (OSError, ValueError, KeyError):continue
        return result

    def file_path(self, session_id, name):
        if not re.fullmatch(r'table_\d{8}_\d{6}_[0-9a-f]{8}', session_id or ''):
            raise ValueError('Invalid session ID')
        if not re.fullmatch(r'(session\.json|images/\d{6}\.png|depth/\d{6}\.npz|metadata/\d{6}\.json|videos/\d{4}\.(avi|jsonl))', name or ''):
            raise ValueError('Invalid dataset filename')
        path = self.directory/session_id/name
        if not path.resolve().is_relative_to(self.directory.resolve()) or not path.is_file():
            raise ValueError('File does not exist')
        return path

    def _disk_ok(self):
        if shutil.disk_usage(self.directory).free < self.min_free_bytes:
            raise ValueError('磁盘剩余空间不足 2 GiB，已停止写入，请先整理空间')

    def _save_manifest(self):
        if self.session:
            atomic_json(self.folder/'session.json', self.session)
            self.last_manifest = time.monotonic()

    def _new_session(self, data):
        if self.writer:raise ValueError('请先停止当前录制，再新建采集场次')
        split = data.get('split', 'train'); scene = data.get('scene', '桌面工具')
        expected = data.get('expected_classes', CLASSES)
        if split not in SPLITS or not isinstance(scene, str) or not 1 <= len(scene.strip()) <= 120:
            raise ValueError('场景说明需为 1–120 字，且用途必须有效')
        if not isinstance(expected, list) or any(c not in CLASSES for c in expected) or len(set(expected)) != len(expected):
            raise ValueError('Invalid expected tool classes')
        self._disk_ok()
        if self.session:
            self.session['status'] = 'closed';self._save_manifest()
        sid = 'table_'+datetime.now(ZoneInfo('Asia/Shanghai')).strftime('%Y%m%d_%H%M%S_')+secrets.token_hex(4)
        self.folder = self.directory/sid;self.folder.mkdir(exist_ok=False)
        for name in ['images','depth','metadata','videos']:(self.folder/name).mkdir()
        self.session = {'schema_version': 1, 'session_id': sid, 'group_id': sid,
            'created_at': datetime.now(ZoneInfo('Asia/Shanghai')).isoformat(), 'split': split,
            'scene': scene.strip(), 'expected_classes': expected, 'task_kind': 'tabletop_pickup',
            'source': 'synthetic_test' if self.camera_factory else 'local_gemini_rgbd', 'status': 'open', 'annotation_status': 'unlabelled',
            'split_rule': 'Keep all frames, videos and derivatives of this session together; check duplicates across sessions before splitting.',
            'class_ids': dict(zip(CLASSES, range(4))), 'samples': [], 'videos': [],
            'auto_sample_skips': {'similar': 0, 'quality': 0}, 'recording': False}
        self.last_sample = None;self.last_sample_frame = None;self.notice = '已创建场次；素材待标注，不会自动进入训练'
        self._save_manifest()
        return {'session_id': sid}

    def _fresh_frame(self):
        if not self.frame or not 0 <= time.monotonic()-self.frame.received_monotonic < .5:
            raise ValueError('相机画面已过期，不能保存历史帧')
        return self.frame

    def _save_sample(self, issue='normal', automatic=False):
        if not self.session or self.session['status']!='open':raise ValueError('请先新建采集场次')
        if issue not in ISSUES:raise ValueError('Invalid issue tag')
        if len(self.session['samples']) >= 1000:raise ValueError('本场次已达 1000 张，请停止录制并新建场次')
        frame = self._fresh_frame();q = quality(frame.color, frame.depth_m)
        if q['almost_black'] or (automatic and q['blur_warning']):
            self.session['auto_sample_skips']['quality'] += 1
            if automatic:return None
            raise ValueError('画面接近全黑，请检查镜头与照明后再截图')
        thumb = cv2.resize(cv2.cvtColor(frame.color, cv2.COLOR_BGR2GRAY), (160,120)).astype(np.float32)
        if automatic and self.last_sample is not None and float(np.mean(np.abs(thumb-self.last_sample))) < 3.:
            self.session['auto_sample_skips']['similar'] += 1;return None
        if self.last_sample_frame == self.frame_id:raise ValueError('这一帧已经保存，请等待新画面')
        self._disk_ok()
        # Sequence never reuses a partially written image after an I/O failure.
        index = max([int(p.stem) for p in (self.folder/'images').glob('*.png')], default=0)+1
        stem = f'{index:06d}';image_path = self.folder/'images'/f'{stem}.png'
        ok, encoded = cv2.imencode('.png', frame.color)
        if not ok:raise ValueError('PNG 编码失败')
        image_path.write_bytes(encoded.tobytes())
        depth_file = None
        if frame.depth_m is not None:
            depth_file = f'depth/{stem}.npz'
            np.savez_compressed(self.folder/depth_file, depth_m=frame.depth_m.astype(np.float32))
        metadata = {'sample_id': stem, 'group_id': self.session['group_id'], 'split': self.session['split'],
            'source': self.session['source'],
            'frame_id': self.frame_id, 'captured_at_unix_s': frame.captured_at,
            'device_timestamp_ms': frame.device_timestamp_ms, 'camera_serial': frame.serial,
            'camera_intrinsics': frame.intrinsic, 'camera_distortion': frame.distortion,
            'depth_units': 'm', 'depth_aligned_to': 'color', 'image_size': list(frame.color.shape[1::-1]),
            'image': f'images/{stem}.png', 'depth': depth_file, 'quality': q, 'issue': issue,
            'selection': 'video_candidate' if automatic else 'manual_snapshot', 'annotation_status': 'unlabelled',
            'image_sha256': hashlib.sha256(encoded).hexdigest(),
            'video': self.record['file'] if self.record else None,
            'video_frame_index': self.record['frame_count']-1 if automatic and self.record else None}
        atomic_json(self.folder/'metadata'/f'{stem}.json', metadata)
        self.session['samples'].append({'id': stem, 'image': metadata['image'], 'depth': depth_file,
            'metadata': f'metadata/{stem}.json', 'issue': issue, 'quality': q, 'selection': metadata['selection']})
        self.last_sample = thumb;self.last_sample_frame = self.frame_id;self._save_manifest()
        return metadata

    def _start_recording(self):
        if not self.session or self.session['status']!='open':raise ValueError('请先新建采集场次')
        if self.writer:raise ValueError('当前已在录制')
        frame = self._fresh_frame()
        if quality(frame.color, frame.depth_m)['almost_black']:raise ValueError('画面接近全黑，请检查镜头与照明')
        self._disk_ok();index = len(self.session['videos'])+1
        name = f'videos/{index:04d}.avi'
        writer = cv2.VideoWriter(str(self.folder/name), cv2.VideoWriter_fourcc(*'MJPG'), 30., frame.color.shape[1::-1])
        if not writer.isOpened():writer.release();raise ValueError('视频编码器无法创建录像文件')
        self.writer = writer;self.record_started = time.monotonic()
        self.record = {'file': name, 'timestamps': f'videos/{index:04d}.jsonl', 'frame_count': 0,
                       'nominal_playback_fps': 30., 'status': 'recording', 'started_at_unix_s': time.time(),
                       'max_duration_s': 180, 'candidate_interval_s': 2., 'depth_saved': 'paired candidate/snapshot frames only'}
        try:self.frame_log = (self.folder/self.record['timestamps']).open('x')
        except Exception:self.writer.release();self.writer = None;raise
        self.session['videos'].append(self.record);self.session['recording'] = True
        self.last_auto_sample = -float('inf');self._save_manifest()
        return copy.deepcopy(self.record)

    def _finish_recording(self, reason='user_stop'):
        if not self.writer:return {'stopped': True}
        self.writer.release();self.writer = None
        self.frame_log.close();self.frame_log = None
        elapsed = time.monotonic()-self.record_started
        self.record.update(status='complete' if self.record['frame_count'] else 'empty', elapsed_s=elapsed,
                           capture_fps=self.record['frame_count']/max(elapsed,.001), stop_reason=reason)
        result = copy.deepcopy(self.record);self.record = None;self.session['recording'] = False
        self.notice = '录像已保存；自动筛出的图片仍需标注审核'
        self._save_manifest();return result

    def _record_frame(self):
        if not self.writer:return
        if time.monotonic()-self.record_started >= 180:
            self._finish_recording('duration_limit');return
        if time.monotonic()-self.last_disk_check > 2:
            self._disk_ok();self.last_disk_check = time.monotonic()
        frame = self.frame;self.writer.write(frame.color)
        self.frame_log.write(json.dumps({'index': self.record['frame_count'], 'frame_id': self.frame_id,
            'captured_at_unix_s': frame.captured_at, 'device_timestamp_ms': frame.device_timestamp_ms})+'\n')
        self.record['frame_count'] += 1
        if time.monotonic()-self.last_auto_sample >= 2:
            self.last_auto_sample = time.monotonic();self._save_sample(automatic=True)
        if time.monotonic()-self.last_manifest >= 2:
            self.frame_log.flush();self._save_manifest()

    def _drain_commands(self):
        while True:
            try:command = self.commands.get_nowait()
            except queue.Empty:return
            try:
                if command['cancelled'].is_set() or time.monotonic()>command['deadline']:
                    raise ValueError('操作已过期，未执行')
                if self.stop_event.is_set():raise ValueError('相机正在停止')
                action = command['action'];data = command['data']
                with self.lock:
                    if action == 'new_session':result = self._new_session(data)
                    elif action == 'snapshot':result = self._save_sample(data.get('issue','normal'))
                    elif action == 'record_start':result = self._start_recording()
                    else:result = self._finish_recording()
                    command['result'] = result
            except Exception as exc:command['error'] = str(exc)
            finally:command['done'].set()

    def _run(self):
        camera = None
        try:
            if self.camera_factory:camera = self.camera_factory()
            else:
                from .camera import OrbbecCamera, LatestCamera
                camera = LatestCamera(OrbbecCamera())
            while not self.stop_event.is_set():
                self._drain_commands()
                if self.stop_event.is_set():break
                frame = camera.read()
                if self.stop_event.is_set():break
                ok, color = cv2.imencode('.jpg', frame.color, [cv2.IMWRITE_JPEG_QUALITY,85])
                if not ok:raise RuntimeError('Preview encoding failed')
                depth_jpg = None
                if frame.depth_m is not None:
                    valid = np.isfinite(frame.depth_m)&(frame.depth_m>.15)&(frame.depth_m<3)
                    scaled = np.uint8(np.nan_to_num(np.clip((frame.depth_m-.15)/1.35,0,1))*255)
                    depth = cv2.applyColorMap(scaled,cv2.COLORMAP_TURBO);depth[~valid] = 0
                    _, depth_jpg = cv2.imencode('.jpg',depth,[cv2.IMWRITE_JPEG_QUALITY,80])
                with self.lock:
                    self.frame = frame;self.frame_id += 1;self.stamps.append(time.monotonic())
                    self.previews = {'color': color.tobytes(), 'depth': depth_jpg.tobytes() if depth_jpg is not None else None}
                    self.camera_state = 'running'
                    if self.frame_id%15==1 or not self.frame_quality:self.frame_quality = quality(frame.color,frame.depth_m)
                    try:self._record_frame()
                    except Exception as exc:
                        self._finish_recording('write_error');self.error = str(exc)
        except Exception as exc:
            with self.lock:self.error = str(exc);self.camera_state = 'error'
        finally:
            try:
                with self.lock:
                    self._finish_recording('preview_stopped' if self.stop_event.is_set() else 'camera_error')
                    if self.session:self.session['status'] = 'closed';self._save_manifest()
            except Exception as exc:
                with self.lock:self.error = str(exc)
            if camera:
                try:camera.close()
                except Exception as exc:
                    with self.lock:self.error = str(exc)
            with self.lock:
                self.camera_state = 'error' if self.error else 'stopped'
                self.frame = None;self.previews = {}
            while True:
                try:command = self.commands.get_nowait()
                except queue.Empty:break
                command['error'] = '相机已停止';command['done'].set()
