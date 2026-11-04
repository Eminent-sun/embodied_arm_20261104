import time
import threading
from dataclasses import dataclass

import cv2
import numpy as np


@dataclass
class Capture:
    color: np.ndarray
    depth_m: object
    intrinsic: object
    distortion: object
    serial: str
    captured_at: float
    received_monotonic: float = 0.0
    device_timestamp_ms: float | None = None


class LatestCamera:
    """Continuously drain RGB-D pairs; bound latency by dropping old pairs together."""
    def __init__(self, camera):
        self.camera = camera
        self.condition = threading.Condition()
        self.frame = None
        self.sequence = 0
        self.consumed = 0
        self.error = None
        self.stopped = threading.Event()
        self.thread = threading.Thread(target=self._capture, daemon=True)
        self.thread.start()

    def _capture(self):
        try:
            while not self.stopped.is_set():
                frame = self.camera.read()
                with self.condition:
                    self.frame = frame
                    self.sequence += 1
                    self.condition.notify_all()
        except Exception as exc:
            with self.condition:
                self.error = exc
                self.condition.notify_all()

    def read(self):
        with self.condition:
            if not self.condition.wait_for(lambda: self.sequence > self.consumed or self.error, timeout=20):
                raise RuntimeError('Camera capture thread timed out')
            if self.error:
                raise RuntimeError('Camera capture failed') from self.error
            self.consumed = self.sequence
            return self.frame

    def close(self):
        self.stopped.set()
        self.thread.join(timeout=17)
        self.camera.close()


class UVCCamera:
    """Explicit RGB-only fallback. No invented depth or camera calibration."""
    def __init__(self, device):
        self.cap = cv2.VideoCapture(device, cv2.CAP_V4L2)
        if not self.cap.isOpened():
            raise RuntimeError(f'Cannot open UVC camera {device}')
        self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        self.cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

    def read(self):
        ok, image = self.cap.read()
        if not ok:
            raise RuntimeError('UVC frame acquisition failed')
        return Capture(image, None, None, None, '', time.time(), time.monotonic())

    def close(self):
        self.cap.release()


class OrbbecCamera:
    def __init__(self):
        import fcntl
        from pathlib import Path
        path=Path(__file__).resolve().parents[2]/'runtime/camera.lock'
        path.parent.mkdir(parents=True,exist_ok=True)
        self._device_lock=path.open('a');self._closed=False
        try:
            fcntl.flock(self._device_lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        except BlockingIOError:
            self._device_lock.close()
            raise RuntimeError('Gemini 正由项目中的另一个程序使用，请先关闭采集预览或视觉进程')
        try:self._open()
        except Exception:
            self._device_lock.close();raise

    def _open(self):
        import pyorbbecsdk as ob
        self.ob = ob
        context = ob.Context()
        devices = context.query_devices()
        if devices.get_count() == 0:
            raise RuntimeError('No accessible Orbbec camera. Check USB permissions/udev rules.')
        self.pipeline = ob.Pipeline(devices.get_device_by_index(0))
        info = self.pipeline.get_device().get_device_info()
        self.serial = info.get_serial_number()
        print(f'Orbbec: {info.get_name()}, serial={self.serial}, firmware={info.get_firmware_version()}', flush=True)
        config = ob.Config()
        colors = self.pipeline.get_stream_profile_list(ob.OBSensorType.COLOR_SENSOR)
        depths = self.pipeline.get_stream_profile_list(ob.OBSensorType.DEPTH_SENSOR)
        # Prefer bounded bandwidth; Gemini 2 is currently attached over USB 2.
        color = None
        for fmt in [ob.OBFormat.MJPG, ob.OBFormat.RGB, ob.OBFormat.YUYV]:
            try:
                color = colors.get_video_stream_profile(640, 480, fmt, 30)
                break
            except Exception:
                pass
        if color is None:
            color = colors.get_default_video_stream_profile()
        try:
            depth = depths.get_video_stream_profile(640, 400, ob.OBFormat.Y16, 30)
        except Exception:
            depth = depths.get_default_video_stream_profile()
        config.enable_stream(color)
        config.enable_stream(depth)
        config.set_frame_aggregate_output_mode(ob.OBFrameAggregateOutputMode.FULL_FRAME_REQUIRE)
        self.align = ob.AlignFilter(align_to_stream=ob.OBStreamType.COLOR_STREAM)
        self.pipeline.start(config)
        self.pipeline.enable_frame_sync()
        self._intrinsics = None

    def read(self):
        ob = self.ob
        for _ in range(15):
            frames = self.pipeline.wait_for_frames(1000)
            received_at, received_monotonic = time.time(), time.monotonic()
            if frames is None:
                continue
            aligned = self.align.process(frames)
            if aligned is None:
                continue
            frames = aligned.as_frame_set()
            color, depth = frames.get_color_frame(), frames.get_depth_frame()
            if color is None or depth is None:
                continue
            width, height, fmt = color.get_width(), color.get_height(), color.get_format()
            raw = np.frombuffer(color.get_data(), dtype=np.uint8)
            if fmt == ob.OBFormat.MJPG:
                image = cv2.imdecode(raw, cv2.IMREAD_COLOR)
            elif fmt == ob.OBFormat.RGB:
                image = cv2.cvtColor(raw.reshape(height, width, 3), cv2.COLOR_RGB2BGR)
            elif fmt == ob.OBFormat.BGR:
                image = raw.reshape(height, width, 3).copy()
            elif fmt == ob.OBFormat.YUYV:
                image = cv2.cvtColor(raw.reshape(height, width, 2), cv2.COLOR_YUV2BGR_YUY2)
            else:
                raise RuntimeError(f'Unsupported camera format: {fmt}')
            if image is None:
                raise RuntimeError('Cannot decode color frame')
            depth_m = np.frombuffer(depth.get_data(), dtype=np.uint16).reshape(depth.get_height(), depth.get_width()).astype(np.float32) * depth.get_depth_scale() / 1000.0
            if depth_m.shape != image.shape[:2]:
                raise RuntimeError('Aligned depth does not match color resolution')
            if self._intrinsics is None:
                profile = color.get_stream_profile().as_video_stream_profile()
                intr, dist = profile.get_intrinsic(), profile.get_distortion()
                intrinsic = {key: float(getattr(intr, key)) for key in ['fx', 'fy', 'cx', 'cy']}
                intrinsic.update(width=width, height=height)
                distortion = [float(getattr(dist, k)) for k in ['k1', 'k2', 'p1', 'p2', 'k3', 'k4', 'k5', 'k6']]
                self._intrinsics = intrinsic, distortion
            return Capture(image, depth_m, *self._intrinsics, self.serial,
                           received_at, received_monotonic, float(color.get_timestamp()))
        raise RuntimeError('Timed out waiting for aligned RGB-D frames')

    def close(self):
        if self._closed:return
        self._closed=True
        try:self.pipeline.stop()
        finally:self._device_lock.close()
