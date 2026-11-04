# 桌面拾取：AI PC 发送基座系 TCP，PS 负责逆解

> R2状态说明：下文保留原技术记录与配置快照。用户已补充现场测试反馈，最新情况见 [现场更新](field_test_update.md)；请勿将历史“未测试/未固定”表述用于否定当前反馈。

2026-11-03：按用户要求简化，不再要求先运行 MoveIt、同步审查 PS 轨迹，才能提交一个拾取目标。
网页入口 http://127.0.0.1:8080/workbench （也可 /pickup）；原规划预览保留在 /planning。
首页仍是数据采集。当前相机推理保持暂停，真实外参和夹爪配置仍未完成，真实 AX7010 未连接。
本次完成程序、协议、离线转换与 TCP 模拟联调；没有宣称已经取得实机可执行坐标。

## 日常操作

1. 需要实时使用时，由用户主动启动 `./scripts/start_vision.sh --headless`；若采集预览还在运行，先在采集首页停止预览，避免抢占相机。
2. 在拾取页选择具体工具 ID，点击“冻结所选工具”。彩色和深度来自同一份原子 RGB-D，而不是点击时另外找一幅深度图。
3. 点工具的**真实可夹持表面**。细镊子中间的空隙、反光金属缺深度的区域、检测框中的桌面不能作为夹持位置。
   本版先用人工点选消除“检测框中心就是抓取位姿”的错误假设，不声称已经自动理解工具抓取轴向。
4. 查看黄色表面点、蓝色 TCP 预览、基座 XYZ / mm、姿态和接近/抬升点。
   确认工具未移动且姿态正确，点“确认并发送”。PS 回显匹配后显示绿色 TCP 和实际接收坐标。
   无有效外参时可以看相机测量值，但发送禁用。
5. 固定目标交给 PS 本地逆解、检查并决定是否开始执行。此页只提交目标，不启动电机、不自动闭爪。
   所有位置以夹爪 TCP 为参照，动作顺序为接近 → 下探 → 闭爪并核实夹持 → 抬升保持。

冻结最长 30 秒。提交前只检查一次新鲜度、相同 ID/会话/标定、目标移动不超过 5 mm、框 IoU≥0.8、手部退出；
无需持续跨进程同步审核。框和中心的检查不能识别所有旋转/换物，仍需人工确认现场未改变。
目前每类工具使用一个实测固定姿态；工具需摆在适合该姿态的位置。任意朝向的自动轴向估计不在本版能力内。
PS 是否能逆解、是否与桌面/机械臂自身碰撞，不能由坐标消息校验代替。

## 怎样确定相对坐标与标定

**只需要相机到机械臂基座的相对关系，不必知道两者在房间里的绝对位置。仿真不能代替实物标定。**

### 1. 固定安装，统一基座和 TCP

- 先固定 Gemini 2 和机械臂底座，保证采集时不会晃动。安装位命名如 `desk_mount_01`。
  固定完成后才在 `config/vision_station.json` 设置 `camera_fixed=true` 和对应 `setup_id`。
- 与 PS 的机械臂模型对齐 `base_link` 的**物理原点、右手 XYZ 方向、单位、各关节零位/正方向**。
  不要把桌角随意定义成原点，而 PS 仍以机械臂底座中心为原点。具体原点必须按 PS 模型落实，当前没有替您虚构。
- 将夹爪两指实际夹持中心定义为 TCP，实测其相对末端法兰的位置/朝向，并配置到 PS 模型。
  如果 PS 逆解器以法兰为末端，内部要用 `T_base_flange = T_base_tcp × inverse(T_flange_tcp)`；
  这属于工具模型处理。AI PC 发送的仍是 TCP，PS 不再做相机坐标变换。
- 先确认实际夹爪 CAD、指长、张开宽度和 TCP；现有 URDF Link6 的旧工具几何不能直接作为新夹爪依据。

### 2. 实测相机与基座的同名点

在工作区放置清晰、不反光的标记。至少 6 个（建议 10–15 个）拟合点，另取至少 4 个独立验证点，
覆盖左右、前后，不可共线；能增加不同已知高度更好。每个点都要取得同一物理位置的：

- `camera_m`：Gemini 工厂内参 + 对齐真实深度计算的光学坐标，米。
- `base_m`：以 PS 基座原点/轴为参照的实测坐标，米。
  可用经校准的机器人 TCP 触碰标记后读取 PS 正运动学坐标，或用固定测量夹具/量具测量。
  前一种方法必须先保证关节零位、几何和 TCP 正确；不能用不准的机器人模型给相机制造“标定真值”。

按同帧冻结方式逐点取得相机值：

```bash
# 在需要标定时主动启动视觉。每次输出使用新文件名。
./scripts/start_vision.sh --headless
# 另一个终端：
.venv-vision/bin/python scripts/calibrate_camera.py freeze \
  --output runtime/calibration/snapshots/marker_a.npz
.venv-vision/bin/python scripts/calibrate_camera.py sample \
  --input runtime/calibration/snapshots/marker_a.npz --pixel 320 240 \
  --output runtime/calibration/marker_a.json
```

`320 240` 只是格式示例，需在对应冻结 PNG 上选择真实标记位置。把 `point_camera_m` 与实测 `base_m`
填入 `config/calibration/correspondences.template.json` 的副本，保存为 `runtime/calibration/measured_points.json`。
同时填写实际序列号、工厂内参/畸变、setup_id 等绑定信息；真实测量完成后才设 `physically_measured=true`。

```bash
.venv-vision/bin/python scripts/calibrate_camera.py extrinsics \
  --input runtime/calibration/measured_points.json --rms-mm 5 --max-mm 10
# 独立验证合格后安装外参；原文件自动备份：
.venv-vision/bin/python scripts/calibrate_camera.py extrinsics \
  --input runtime/calibration/measured_points.json --rms-mm 5 --max-mm 10 --activate
```

完成后重新启动视觉以加载外参。软件变换方向为 `p_base = R_base_camera × p_camera + t_base_camera`。
默认 RMS≤5 mm、最大≤10 mm 只是粗定位验收；夹细镊子可能远远不够，要按夹爪容差收紧并实测。
相机固定后通常无需每次抓取重标；每天可用几个固定标记复核误差。相机或底座移动须重标；
换夹爪须重标 TCP；桌面高度/障碍变化须更新工作区并复核。移动桌面只有在连带改变相机到基座关系时才必须重做外参。

### 3. 实测表面点到夹爪 TCP 的偏移

深度读到的是物体朝向相机的表面，通常不是两指的夹持中心。对各类工具实测表面点到目标 TCP 的差值，
以**基座 XYZ / mm** 填 `surface_to_tcp_base_mm`；固定姿态填写 `orientation_xyzw`。
这是 `R_base_tcp` 的单位四元数，顺序 x,y,z,w，不是欧拉角、不是 wxyz，也不是相机朝向。
不要假定姿态 `[0,0,0,1]` 就是向下——必须按实际 TCP 轴验证。

在 `config/pickup_tcp.json` 中填写实际 `ps_host`、`ps_port`，以及 `contract`：

| 字段 | 实测/双方约定内容 |
|---|---|
| `base_definition` | 原点和右手轴的物理定义，Z 必须向上，接近/抬升沿 +Z |
| `robot_model_id` | PS 实际机械臂/零位/末端模型的版本或校验值 |
| `tcp_id` | 实际夹爪 TCP 标定版本 |
| `workspace_min_mm/max_mm` | 测量后允许的 TCP 区域，接近/抬升端点也必须在内 |
| `profiles.<类别>.validated` | 真实确认该类抓取配置后设 true |
| `profiles.<类别>.surface_to_tcp_base_mm` | 表面点到抓取 TCP 的实测三维偏移 |
| `profiles.<类别>.orientation_xyzw` | 实测固定抓取姿态 |
| `profiles.<类别>.approach_height_mm/lift_height_mm` | 沿基座 +Z 的实测接近/抬升高度 |
| `contract.validated` | 全部实测并与 PS 核对后设 true |

类别键为 screwdriver / pliers / scissors / tweezers；只需填已经验收的类别。未配置类别不能发送。
这里不提供可误装成真机配置的数值模板；配置文件保留未标定状态。应用不靠 validated 字段替代实物检查。

## 发送协议：PS 可以直接取什么值

TCP 7010，沿用 ARM1 16 字节帧头（网络大端 magic/version/JSON 字节数/CRC32）和 UTF-8 JSON。
实现 `communication/robotarm_link/cartesian.py` 仅依赖 Python 标准库，可移植到 PS；无需安装 ROS 或 YOLO。
本页不使用 7011 观测数据当运动指令；7011 原实时观测链路保持独立。

1. `hello` 必须返回 `capabilities` 中含 `cartesian_target`，并给出 `cartesian_contract_id`。
   该 ID 为双方同一 `contract` 的规范 JSON SHA256；算法见 `fingerprint()`。配置中 `1` 和 `1.0` 也可能影响指纹，建议复制同一 JSON。
2. AI PC 发送 `command=set_cartesian_target, confirmed=true, target={...}`：
   - `frame_id=base_link, units=mm, tcp_id`；
   - `position_mm=[X,Y,Z]`：**夹爪 TCP 抓取位置**，不是相机坐标/物体包围框中心；
   - `orientation_convention=R_base_tcp_xyzw, orientation_xyzw=[x,y,z,w]`；
   - `approach_mm / lift_mm`：接近和抬升目标位置，使用同一姿态；
   - `surface_base_mm`：辅助诊断的点击表面点，不能代替 `position_mm`；
   - `target_id / contract_id / calibration_id / source_session_id / track_id / class_name`：锁定目标及版本绑定。
3. PS 校验后返回同 seq、`ok=true, accepted=true, state=target_received, execution_started=false, target=<原样目标>`。
   AIPC 只在完整匹配回执后记录已接收目标。未响应或回显不同会报错，不能推断已送达。
4. PS 后续基于自己的机器人模型和关节反馈求解、检查限位/碰撞/速度/连续性，并在本地受控启动。
   目标报文不等于实时伺服指令，不定义自动执行或自动重试。PS 应对重复 target_id 幂等处理，不重复抓取。
   新目标需显式替换；断线、重启或已过时的待执行目标不能自动启动。需要本地重新确认或新鲜目标。

参考模拟器只收存目标并回显，**不计算真实 IK，不驱动 PL，不宣称路径可达**：

```bash
./scripts/start_ps_simulator.sh --cartesian-config config/pickup_tcp.json
```

真实 AX7010 需实现同一握手/命令/回执。尚未实测时默认 contract 未验证，模拟器也拒绝接收伪实物坐标。
离线测试在临时目录使用显式 synthetic fixture，不污染真机配置。
`cartesian_status` 可读取模拟端最后目标；`clear_cartesian_target` 可清除它。
断开通信不会擦除最后坐标记录，但旧目标不因此获得执行授权。现有轨迹执行通道的断线停止行为仍保留。

## 滤波、锁定与显示

- 保留工具原有中值 + 100 ms EMA + 1.5 mm 死区，30 mm 跳变拒绝；漏检暂存最多 350 ms，手关键点最多 200 ms。
  原有画面定位十字和骨架显示不变；暂存点明确禁用，不能伪装新坐标。
- 人工夹持点取冻结同帧的 3×3 深度中值，要求至少 80% 有效、MAD≤2 mm、深度跨度≤6 mm、中心像素有效。
  这是局部空间抗噪，**不是多帧的自动抓取点估计**；深度平滑仍不能保证测到的一定是工具。
- 点击后形成一次冻结候选；确认后不再每帧发送变化的坐标，因此不会因检测噪声改变 PS 的执行目标。
  检测丢失不会发送零坐标，不会切换到另一个同类工具，也不会自动重发旧目标。
- 页面实时点只在年龄允许范围内显示；已接收目标独立保留，标明是历史锁定目标，不冒充物体当前所在位置。
  ACK 坐标从回执原样读取，写入 `runtime/pickup/last_ack.json`，网页服务重启后可继续查看。
- TCP 点绘制在**对应冻结画面**，不把旧点投到新的实时画面。实时画面仍显示滤波参考点；两者文字含义不同。
- 真正执行中工具意外移动、有人介入或关节异常，仍应由 PS/PL 的本地执行与停止逻辑处理，不能依赖网页刷新。

验证命令：

```bash
PYTHONPATH=vision:communication:planning .venv-vision/bin/python -m unittest discover -s tests -v
```

测试覆盖非单位刚性变换方向、米→毫米、TCP 偏移/投影、单位/姿态/范围拒绝、标定失配、旧帧/漏检/手部阻止新提交、
完整 TCP 往返与 ACK 匹配、目标锁存、无自动执行；另运行原有滤波回归。测试不打开相机。

本次实际结果：71 项回归通过，记录 `runtime/pickup/tests.log`；HTTP 路由、请求令牌和过期帧拒绝记录
`runtime/pickup/http-check.json`。已用 Firefox 检查页面布局和 JavaScript 状态渲染，截图
`runtime/pickup/ui.png`；截图检查将流替换为同一历史 JPEG，没有启动相机，也不是实时操作或真机验收。
