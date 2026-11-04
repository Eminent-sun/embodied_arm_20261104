# AI PC 坐标转换与运动规划

> R2状态说明：下文保留原技术记录与配置快照。用户已补充现场测试反馈，最新情况见 [现场更新](field_test_update.md)；请勿将历史“未测试/未固定”表述用于否定当前反馈。

> 当前简化入口见 [桌面拾取 TCP 接口](simple_pickup.md)：`/workbench` 一次点选/确认后发送基座系 TCP 目标到 PS，不要求先运行 MoveIt 或同步审查 PS 轨迹。以下复杂规划流程保留在 `/planning`，不作为新坐标提交的前置条件。PS 仍须在本地完成执行检查。

> 2026-11-03 用户更新：执行用逆运动学安排在 AX7010 PS。AI PC 负责视觉、相机到基座变换和拾取笛卡尔目标生成；PS 本地处理逆解、路径/限位/碰撞检查与执行。实机 PS 集成尚未核验。本地 MoveIt `/compute_ik` 仅用于保留的仿真规划流程，简化目标提交不依赖它。

> 2026-11-02 更新：当前任务已改为仅桌面拾取，网页首页用于采集。当前使用方法见 [桌面采集与拾取](tabletop_collection.md)。下文交接/放置内容保留为历史模式说明。

历史交接模式为“拾取工具 → 固定交接区域内按手的位置递送 → 等待交接”；当前默认仅桌面拾取。
完整交接规则、配置、五阶段预览和验证见 [工具递送](tool_handover.md)。
本页的六阶段 pick/place 流程保留为旧版桌面放置模式及回归测试。

通用软件已接通：固定目标 ID → AI PC 重新计算相机到基座变换 → 已审核的 TCP 抓取位姿 →
MoveIt 碰撞约束 IK 与六阶段规划 → 分段六关节轨迹导出 → 网页 / RViz 预览。
规划进程不包含 execute/upload 调用，网页执行按钮仍关闭。

相机与持续推理没有重启。相机未固定、外参未标定，实测配置保持未验证。
真实夹爪 CAD、TCP、关节零位/限位和 PS/PL 执行控制器仍未验收。
当前 URDF 的 Link6 仍含旧工具几何；仿真通过不表示已换成实际新夹爪。

## 运行方式

先查看已经完成的离线验证：打开 http://127.0.0.1:8080/planning，点击“查看离线仿真规划”。
页面显示可旋转的 TCP 轨迹投影、基座 XYZ；当前默认演示为桌面拾取；交接模式的配置/测试另行保留。
该结果来自明确标记的 synthetic_test 配置，没有相机实测标定，也没有移动电机。

启动常规规划服务（默认 ROS domain 73、仅本机发现）：

```bash
./scripts/start_planning.sh
# 如需同时查看机器人模型和轨迹：
./scripts/start_planning.sh use_rviz:=true
```

两条命令任选一条，不要重复启动同一 domain 的 move_group。
默认提供模拟 joint_states；真实反馈接入后需用 `publish_simulated_joints:=false`，
并确保只保留一个经过核对的关节状态源。无新鲜六关节状态会拒绝规划。
无论采用哪一种状态源，这个启动入口都设置 `allow_trajectory_execution=false`。
不同时启动旧 motor action server 或其它执行入口；规划与执行部署分别验收。

软件分工：GPU 环境负责视觉，系统 Python / ROS 2 Jazzy 负责 MoveIt，网页通过 JSON 和独立进程请求规划。
没有把 ROCm PyTorch 与 rclpy/FastDDS 合并；NPU 未用于规划或未经验证的推理。

## 实测配置必须补齐什么

`config/planning.json` 是唯一的实测规划入口，默认不填虚构数值。

| 字段 | 必须来自哪里 |
|---|---|
| setup_id / calibration_id | 当前固定安装位及已通过验证的眼在手外标定 |
| robot_model_reviewed / robot_description_sha256 | 实际机械臂、末端和碰撞模型审核；与运行中 MoveIt 的 robot_description 内容 SHA256 一致 |
| workspace_min_m / workspace_max_m | base_link 下的实际 TCP 工作区，三个数，单位 m |
| gripper.link_to_tcp | Link6 到夹爪 TCP 的实测刚性变换：position_m + quaternion_xyzw |
| gripper.collision_boxes | 夹爪保守包络；每个 box 包含 size_m 与 pose，pose 在 Link6 坐标系 |
| scene_boxes | 桌面、收纳区、固定障碍物的包络；size_m 与 pose 在 base_link 坐标系 |
| grasp_profiles | 按工具与已审核摆放方向配置抓取参数，不能直接把检测框中心当抓取位姿 |
| handover_regions | 当前默认：固定交接区域、手边 TCP 偏移与方向，见 tool_handover.md |
| place_zones | 旧版桌面放置模式：命名放置区域，每区提供 tcp_pose：position_m + quaternion_xyzw，在 base_link 下 |

每个抓取 profile 需要：

- `reviewed: true` 和适用 `classes`（例如 pliers）；设置前必须确实检查实物与摆放。
- `tcp_quaternion_xyzw`：单位四元数，描述期望 TCP 在基座中的朝向。
- `surface_to_tcp_offset_base_m`：检测表面参考点到实际抓取 TCP 的偏移。
- `clearance_m`：沿基座 +Z 接近/抬升的距离，当前程序支持 10–300 mm。
- `object_size_m`、`surface_to_object_center_base_m`：用于碰撞检查的物体包络及其中心偏移。

**这版使用已审核的固定抓取方向，不会自动从 YOLO 框推断任意工具的抓取朝向。**
如果工具任意旋转，必须先获得可靠的轴向/姿态估计或由人确认对应抓取配置。
细长工具框中心也可能落在桌面上，稳定深度不等于正确的工具抓取表面。
对接真实夹爪前还需用实际 CAD/保守包络替换旧工具，核对 SRDF 的已有自碰撞排除项。

`gripper.tcp_calibrated`、`robot_model_reviewed`、`validated` 只有完成对应实测后才能设为 true。
已知相机/基座移动后应重新标定，改动模型后应重新审核模型 SHA256。

## 坐标与规划规则

- 从新鲜观测中的 `surface_point_camera_m` 出发，在 AI PC 使用 `T_base_camera` 重新计算基座点。
  不直接信任外部传入或旧缓存的 `surface_point_base_m`。
- 检查固定安装位、相机序列号、内参/深度对齐指纹、calibration_id、观测年龄、目标 ID、深度及手部提示。
  暂存/跳变/过期坐标、离线图像以及不同安装位均不能进入实测任务。
- 用已审核偏移和方向生成 TCP 目标，再计算：
  `T_base_Link6 = T_base_TCP × inverse(T_Link6_TCP)`，因此夹爪长度不会被遗漏。
- 旧版桌面放置模式六阶段：approach（OMPL）→ grasp（笛卡尔）→ lift（笛卡尔）→ transfer（OMPL）→
  place（笛卡尔）→ retreat（笛卡尔）。接近/抬升方向固定为 base_link 的 +Z，非任意方向抓取规划器。
- 笛卡尔段要求 fraction=1，拒绝只完成部分路径。目标姿态使用碰撞约束 IK；
  每段额外核对末端 FK 位置/方向误差，拒绝把“找到某组关节角”当作目标已到达。
- 场景含桌面/障碍物、夹爪包络和目标物体。下探阶段才允许目标与末端接触；
  抓取后把物体附着到 Link6，搬运时检查所携带的物体，放置后移回世界场景。
  未实际执行，所以规划结束会恢复初始场景。机器人与环境已有其它碰撞物不会被删除。
- 专用 OMPL 配置缩小碰撞采样间隔和 TOTG 路径容差；仍保留 ValidateSolution。
  对输出的关节线性插值额外采样检查，属于离散碰撞验证，不宣称连续碰撞或真实物理精度保证。
- 请求冻结目标与配置指纹。实测规划结束再次检查原目标、标定与配置；变化时标记 requires_review。
  不重新选同类最高置信度目标，不把新坐标无条件覆盖已确认目标。

MoveIt 轨迹平滑参数的官方实现参考：
[AddTimeOptimalParameterization](https://github.com/moveit/moveit2/blob/jazzy/moveit_ros/planning/planning_response_adapter_plugins/src/add_time_optimal_parameterization.cpp)。

## 命令行与通信输出

实测配置完整、相机恢复且目标稳定后，可在网页按 ID 生成草案、选择抓取配置，再点“在 AI PC 生成轨迹”。
交接任务使用 tool_handover.md 的带 hand-track-id 命令。旧版放置模式也可使用以下命令；下面名称和 ID 必须替换为当前实物配置，命令不会启动摄像头：

```bash
.venv-vision/bin/python scripts/make_plan_request.py \
  --track-id 4 --zone bin_a --profile pliers_flat \
  --output runtime/planning/request_001.json
./scripts/plan_task.sh --request runtime/planning/request_001.json \
  --output runtime/planning/result_001.json
```

请求创建后须在 30 秒内开始规划；网页独立 worker 最长 180 秒，失败或超时不会发送任何执行指令。
同一 ROS domain 的网页/CLI worker 使用文件锁串行操作规划场景。

输出包括：目标基座 XYZ、TCP 各阶段位姿、模型/标定/配置指纹、路径检查信息、六关节轨迹、夹爪事件。
轨迹顺序 `joint1..joint6`，角度 rad，时间 s；与已有 TCP 7010 的 upload 数据结构兼容。
TCP 7011 继续负责视觉观测，两个接口用途保持分开。

默认关节采样速度上限 0.25 rad/s、采样加速度预算 0.5 rad/s²；每段额外检查已有 PS 的限位、
时间递增、120 秒时长与 1000 点限制。导出是时间戳 + 位置样本，**不等于已经完成 PL 的连续插补与动力学验收**。
夹爪事件独立列出，时长合计不含夹爪动作/等待。真实执行时还需确认、当前编码器起点匹配、
逐段反馈、夹爪应答、视觉异常处理及急停联锁；本轮不接通这些真实执行动作。

## 旧版桌面放置回归验证记录

- 41 项单元/通信测试：坐标方向、TCP 偏移、错误缓存坐标、标定不匹配、过期、手部、
  越界、未审核抓取、配置篡改及关节采样时序/限速等。
- 隔离 domain 74 的真实 MoveIt 服务完成六阶段合成场景规划；4 个笛卡尔段均为 100%。
  一次验证共检查 205 个关节插值状态，分段轨迹时长约 13.83 秒；随机规划的具体路径/时长可能变化。
- 真实 MoveIt 拒绝不可达 IK、只完成 43.45% 的笛卡尔路径以及已放入场景的碰撞障碍。
- 六段文件导出成功；首段实际经 TCP 上传到 PS 模拟端并确认 prepared，关节保持 HOME，未发送 execute。
- 独立 system-Python worker CLI 也完整规划成功，模型内容指纹被记录。

报告：`runtime/planning/synthetic_result.json`、`worker-result.json`、`rejection_checks.json`；
分段导出：`runtime/planning/export/`。全部为 synthetic_test；实测标定文件仍未启用。

复现离线验证（单独终端运行，不打开相机）：

```bash
ROBOARM_ROS_DOMAIN_ID=74 ./scripts/start_planning.sh
# 另一终端
export ROBOARM_ROS_DOMAIN_ID=74
source scripts/env_jazzy.bash
/usr/bin/python3 scripts/verify_aipc_planning.py
/usr/bin/python3 scripts/verify_planning_rejections.py
PYTHONPATH=planning:vision:communication .venv-vision/bin/python -m unittest discover -s tests -v
```
