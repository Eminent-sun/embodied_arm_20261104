# AI PC ↔ ALINX AX7010 PS protocol v1

> 2026-11-03：新增简化的 [桌面拾取 TCP 提交](simple_pickup.md)。`/workbench` 为新入口，原规划页迁至 `/planning`。TCP 7010 接收经一次确认的基座系末端目标；TCP 7011 仍仅传观测。

The current implementation is a tested **software simulator and ROS adapter**.
It does not contain PL RTL, a hardware motor driver, an AXI register implementation,
or a commissioned Linux/Bare-metal firmware image. PS operating system and IP are
not yet selected. The real gripper will be controlled by FPGA.

## Transport and framing

AI PC is the TCP client; PS is the server. Proposed port: 7010. One controlling
session. The Python reference defaults to loopback and can be bound to a test LAN
with `--host <address>`. Python standard library only on the PS simulator side.

Each packet starts with 16 bytes, big endian (`!4sIII`):

| Field | Bytes | Value |
| --- | --- | --- |
| magic | 4 | ASCII `ARM1` |
| version | 4 | unsigned 1 |
| length | 4 | JSON byte count, 1..1,048,576 |
| checksum | 4 | CRC32 of JSON bytes |

Payload: UTF-8 JSON object. No NaN/Infinity. Each request includes a strictly
increasing integer `seq` and `command`; each response echoes `seq`, includes `ok`,
and includes `error` when rejected. TCP fragmentation is handled by exact reads.
CRC detects invalid payloads; it is not authentication. Use a controlled wired
LAN; do not expose this unauthenticated development interface to the Internet.

## Commands

| command | Fields | Result |
| --- | --- | --- |
| `hello` | none | protocol, mode, board, limits, capabilities |
| `status` / `heartbeat` | none | state, six positions, gripper, fault, trajectory_id |
| `upload` | trajectory | validated buffer; SHA256 trajectory_id, no motion |
| `execute` | trajectory_id, confirmed=true | start only that prepared trajectory |
| `gripper` | action=open/close, confirmed=true | simulator gripper state |
| `stop` | none | freeze simulated joints, clear trajectory and latch stopped |

Example upload:

```json
{"seq":2,"command":"upload","trajectory":{"joint_names":["joint1","joint2","joint3","joint4","joint5","joint6"],"points":[{"time_s":0.0,"positions_rad":[0.0,1.57,0.0,0.0,1.57,0.0]},{"time_s":1.0,"positions_rad":[0.1,1.57,0.0,0.0,1.57,0.0]}]}}
```

Position units: rad; time: seconds relative to execution start. Joint order is
fixed. 2..1000 points, first time 0, strictly increasing time, duration <=120 s.
The reference enforces existing URDF joint bounds and segment slope <=0.5 rad/s;
it rejects start positions differing from current feedback by >0.03 rad.
It uses linear interpolation solely for software testing. Real firmware must
implement its own velocity/acceleration/jerk, torque, following-error and hard-limit
checks and deterministic interpolation; uploading this format alone does not
provide those protections.

## Session and execution lifecycle

`idle → prepared → executing → succeeded`. Stop/disconnection/watchdog yields
`stopped`, discards the prepared token and prevents a disconnected client from
resuming an old motion. A fresh, validated upload is required. `confirmed=true`
is an explicit application action, not a security credential. The operator-facing
application must bind confirmation to the actual trajectory and target shown.

Poll/heartbeat at 20 Hz. Reference watchdog is 1 s. A stalled or partial frame
times out and closes the session rather than attempting to reinterpret trailing
bytes. A production PS reader needs a total frame deadline (not only per-read
timeouts) and a separate watchdog task; **PL watchdog must run independently of
Linux networking and scheduling**. Physical emergency stop and limit inputs must
act on PL/motor enable directly. An Ethernet stop is not a replacement.

ROS adapter maps MoveIt `/arm_controller/follow_joint_trajectory` to upload/execute
and publishes `/joint_states` only while fresh status is available. It permits
endpoints advertising `mode=simulation` only in this revision. The adapter polls
at 20 Hz and propagates cancellation. Recognition publishes observations only;
it does not execute trajectories.

## PS → PL boundary to implement after hardware details are settled

Recommended flow: PS validates and buffers a complete bounded trajectory, then
loads a double-buffered AXI BRAM/DMA area. PL checks version/length/checksum, latches
the buffer at an explicit commit, interpolates using its own timebase, and handles
motor CAN scheduling and gripper I/O. Return measured encoder positions, timestamps,
fault bits, queue occupancy and gripper sensor state. Use a sequence/generation
counter for commit/ack to prevent partial-buffer execution.

Register addresses, AXI bus widths, motor CAN controller, gripper electrical
interface, tick frequency and firmware build target are intentionally not invented.
They depend on the AX7010 daughterboard and motor/gripper wiring. The existing
RobStride C++ driver is retained as protocol reference, not run on the AI PC.

## Independent vision channel (TCP 7011)

`communication/robotarm_link/vision_receiver.py` is a PS-side reference process
using only the Python standard library. It uses the same ARM1 header/CRC/seq
framing, on a **separate port and connection** from trajectory control. One
publisher owns the vision session. A second status client is not a concurrent
monitor; use the publisher's `vision_status` request or inspect its status output.

| command | Fields | Reply |
|---|---|---|
| hello | none | channel=vision, capabilities, mode=simulation, execution_enabled=false |
| observe | observation object | accepted, source_frame_id; duplicates/out-of-order rejected without refreshing TTL |
| vision_status | none | fresh, latest observation or null, execution_enabled=false |
| clear | none | invalidate current observation |

Control commands (upload/execute/gripper/stop) are rejected on this port. Vision
messages do not update joint state, execute trajectories, or operate the gripper.
Existing port 7010 behavior remains unchanged.

Observation schema version 1 is built from PC perception schema version 2:

| Field | Meaning |
|---|---|
| source_kind | live_camera / offline_replay / synthetic_test; non-live data must never be treated as current hardware perception |
| source_session_id, frame_id | producer-run identity and increasing frame number; track IDs are scoped to this run |
| camera_serial, image_size | physical camera identity, original full RGB resolution |
| mounting, units | eye_to_hand, m |
| camera_frame, base_frame | camera_color_optical_frame, base_link |
| station_setup_id, calibration_id, camera_model_signature | install-state and calibrated camera-model provenance; required for valid base coordinates |
| base_calibration_valid | true only with matching validated, physically measured transform and fixed mount |
| sender_age_ms, ttl_ms | sender's host-receipt age and remaining residency budget; sum ≤500 ms |
| hand_present | advisory full-image hand flag; not a hardware safety input |
| execution_enabled | always false |
| detections | up to 128 objects; empty list explicitly clears previous targets |

Each detection contains class_id/name (0 screwdriver, 1 pliers, 2 scissors,
3 tweezers), confidence, full-image box_xyxy, track_id, consecutive_hits, stable,
depth_quality, surface_point_camera_m, surface_point_base_m, point_kind and
`grasp_pose:null`. The scissors class includes the user's blue flush cutter.
Depth quality includes valid, valid_fraction, mad_m and spread_m; invalid depth
must have null coordinates. Uncalibrated results must have null base coordinates.
point_kind is explicitly bbox_center_surface_sample, not object center or grasp pose.
All coordinates must be finite; confidence and boxes are bounded. Examples are in
`config/communication/vision_observation.example.json` and tagged synthetic_test.

Producer default is 10 Hz. It skips unchanged frames, clears stale/invalid data,
performs reconnect/hello negotiation and sends status keepalives. Receiver uses a
monotonic local TTL and clears on disconnect. TTL does not bound network flight
time and returns transport_latency_verified=false. Actual PS implementation must
settle synchronization and end-to-end timing before perception can be used by
any commissioned motion planner. Non-live fixtures/replay are for software tests.

Start with `scripts/start_ps_vision_simulator.sh`, then the vision app's optional
`--ps-host ... --ps-port 7011` or standalone `scripts/start_vision_link.sh`.
The vision subprocess is independent of PyTorch and ROS. No firmware or FPGA
logic has been deployed to a physical AX7010 by these scripts.

## 三维滤波与手部扩展

视觉 schema 1 兼容扩展：工具增加 tracking_status、observed_this_frame、coordinate_fresh、
coordinate_usable、coordinate_age_ms、filter_kind。旧消费者不能将缺失这些标志默认为可用于运动。
历史点保留时 surface_point_camera_m/base_m 为最后一次滤波值，但 usable=false。
新 hands 字段最多四条短时轨迹，每条 21 个点，含 camera_m/base_m 与逐点 freshness/age。
发送进程还把实际发送 payload 及 ACK 原子保存到 runtime/vision/link_status.json，供界面显示。
详细状态规则、150/350/200 ms 年龄约束见 docs/temporal_tracking.md。
整个通道仍仅为观测；coordinate_usable 表示观测质量，不表示已获得运动授权或完整抓取位姿。
