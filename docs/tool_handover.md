# 固定交接区域、动态接收手

> 2026-11-02 更新：当前任务已改为仅桌面拾取，网页首页用于采集。当前使用方法见 [桌面采集与拾取](tabletop_collection.md)。下文交接/放置内容保留为历史模式说明。

本项目当前任务是 **拾取桌面工具 → 递送到指定区域内的手边 → 停稳等待交接**。
交接区域固定在机械臂 `base_link` 坐标系，手可以在区域内换位置。
只要相机、基座及安装位保持不动，手移动不需要重新做外参标定。
相机或基座相对位置变化则必须重新标定；区域边界或人体隔离布置改变也需重新审核。

## 坐标与停稳判断

1. Gemini 对齐 RGB-D 提供真实米制关键点。MediaPipe 的 normalized z 不参与三维定位。
2. 手部沿用 ID 关联和逐点滤波，掌部参考点取关键点 0、5、9、13、17 的均值。
3. 停稳检查使用这五点的**原始深度测量**，避免 EMA 延迟掩盖手的移动。
   连续采样至少 6 次且覆盖至少 0.35 s；最近最多 0.5 s 内掌部范围直径不超过 12 mm、
   相邻测量速度不超过 0.08 m/s。缺失或暂存清空稳定历史，单次移动超过 15 mm 重新累计。
   这是规划筛选阈值，不是安全认证或实物精度保证。
4. 生成交接计划时要求唯一接收手、指定 ID、21 个新鲜有效深度点，帧与点的合计年龄不超过 150 ms。
   第二只手、模糊关联、缺失深度、暂存点都拒绝作为新的交接参考。
5. AI PC 使用已绑定安装位、相机序列号与内参的 `T_base_camera` 重新计算所有手点。
   不直接信任旧缓存的 `base_m`。
6. 所有当前手点须在固定区域内；递送 TCP 按下式计算，方向使用审核过的工具递送方向：

   `p_TCP_base = mean(T_base_camera × p_palm_camera) + palm_to_tcp_offset_base_m`

   TCP 是带偏移的手边停靠点，不能直接使用掌部坐标作为夹爪目标。
   接近点为 `p_TCP_base + approach_offset_base_m`，这两个点也必须在区域内。

手部包络覆盖原始和滤波后的全部 21 点，并在各方向增加配置的 margin。
包络进入 MoveIt 世界碰撞场景，手与机械臂、夹爪及携带工具均禁止碰撞；
抓取阶段的“允许工具与夹爪接触”不会扩大到手部。
手的包络不覆盖整个前臂或身体，必须另行测量/隔离人体可能进入的区域。

## 两部分任务与等待边界

| 部分 | 轨迹阶段 | 结束条件/后续门槛 |
|---|---|---|
| 拾取 | approach → grasp → lift | 抓取到位后闭爪；收到有效抓持反馈，再检查接收手与编码器起点、确认递送 |
| 递送 | transfer → present | 到达手边后停稳，保持夹持，等待交接确认 |

当前生成的是五段完整任务的**规划预览**，不可把分段轨迹拼接为一次无等待执行。
`events` 明确包含抬升后的 `confirm_delivery` 和末端的 `await_handover` 两个等待边界。
“检测到手”不等于“接住工具”：接稳及松爪必须显式确认，随后等待 FPGA 夹爪应答，
再根据实际状态单独规划撤离。因此本次结果不包含自动松爪事件和跨越交接等待的撤离段。

目标在规划时冻结。手点相对冻结点变化超过 `max_deviation_m`（模板 10 mm）、手移出区域、
丢失/暂存/变 ID/多手、会话或标定改变时，复核失效，不能持续追手。
`HandoverGuard` 的失效会锁存：手回到原位也需要新计划和确认。
工具在抓取后离开桌面画面是正常情况，guard 的 `delivery` 阶段只复核接收手；
`pickup` 阶段同时复核原工具。进入 delivery 的前提必须由真实抓取反馈确定，不能由漏检推断。

网页对已完成的实测计划每 0.5 s 做一次预执行复核，并在任务文件夹持久保存 `guard.json`。
这是**界面检查**，不是硬实时急停链路。当前未接通电机执行管理器，guard 不会发送 stop/execute/open。
真实接入时还必须把 phase、抓持应答、连续监测、联锁、超时停止及实际状态下的递送重规划接到控制器。
手在拾取期间移动后，旧递送预览不能直接复用；需在安全保持状态从当前编码器位置重新规划第二部分。

## 实测配置

`config/planning.json` 默认 `task_kind: tool_handover`，实测配置仍为 `validated: false`。
`handover_regions.handover` 的边界、TCP 偏移、方向和接近方向均为 null；没有把测试几何写入实物配置。

| 字段 | 含义 |
|---|---|
| min_m / max_m | 固定交接三维包围盒，基座 XYZ，单位米；须在总工作区内 |
| palm_to_tcp_offset_base_m | 从掌部到夹爪 TCP 的安全停靠偏移，基座方向，按实际工具握持位置审核 |
| tcp_quaternion_xyzw | 工具递送方向；应避免尖端/刃口朝向接收者 |
| approach_offset_base_m | TCP 从哪一侧接近手边停靠点，不能穿过手或人体 |
| hand_margin_m | 关键点包络的附加裕量；模板 0.025 m，须按实物精度与误差预算审核 |
| max_deviation_m | 冻结后允许的点偏差；模板 0.01 m，超出即失效 |
| body_scene_reviewed | 已审核手外的前臂/人体隔离与 scene_boxes，不能仅凭手关键点设 true |
| reviewed | 区域、工具递送姿态及边界已实测审核 |

抓取方向仍由 `grasp_profiles` 提供；YOLO 框中心不是通用抓取姿态。
不同长度、尖端方向和握持部位的工具需分别审核 profile 与递送偏移，当前不自动推断任意工具姿态。

相机固定/外参、实物夹爪 TCP 与碰撞模型、编码器/限位、人体隔离、FPGA 夹爪反馈均未验收，
因此实际执行继续关闭。NPU 未参与本流程；GPU 视觉环境与 CPU/ROS 规划进程保持分离。

## 使用和验证

刷新 http://127.0.0.1:8080：选择工具 ID、交接区域、接收手 ID，再生成草案和规划。
界面显示掌部与递送 TCP 的基座三维坐标；规划图虚线表示固定区域，粉色点表示冻结的接收手。
“查看离线仿真规划”加载 `runtime/planning/handover_result.json`，不会打开相机。
TCP 7011 原有 21 点三维手部观测与 ACK 继续保留；规划目标不是已经下发的电机命令。
TCP 7010 使用分段六关节轨迹，FPGA 不需要做相机到基座转换。

```bash
# 实测完成且视觉运行后；名称和 ID 必须使用现场实际值
.venv-vision/bin/python scripts/make_plan_request.py \
  --track-id 4 --hand-track-id 8 --zone handover --profile pliers_flat \
  --output runtime/planning/new_request.json
./scripts/plan_task.sh --request runtime/planning/new_request.json \
  --output runtime/planning/new_result.json
```

离线验证不访问相机，也不驱动机械臂：

```bash
ROBOARM_ROS_DOMAIN_ID=74 ./scripts/start_planning.sh
# 另一终端
export ROBOARM_ROS_DOMAIN_ID=74
source scripts/env_jazzy.bash
/usr/bin/python3 scripts/verify_handover_planning.py
PYTHONPATH=planning:vision:communication .venv-vision/bin/python -m unittest discover -s tests -v
```

2026-11-01 验证：49 项单元/通信测试通过；实际 MoveIt 完成同一固定区域内两处合成手位置的规划，
两次五段轨迹均停在等待交接，三段笛卡尔路径均完整。合成手位移 5 mm，目标相应变化、区域保持不变。
将手部包络放在机械臂上时碰撞检查明确拒绝；HOME 关节状态未变化，相机未打开，控制命令未发送。
报告 `runtime/planning/handover_verification.json`；两套结果与请求同目录；
分段导出和等待事件见 `runtime/planning/handover_export/`，这些全部是 synthetic_test。

隔离 domain 74 完成验证后以 SIGINT 退出时，MoveIt 服务在 rclcpp CallbackGroup/NodeBase
析构路径出现一次原生段错误（`runtime/planning/handover-service.log`）。规划期间及独立 worker
均完成返回，结果已保存；异常发生在服务关闭阶段，尚未定位根因，不据此宣称运行时稳定性已验收。
测试服务已停止；正常 domain 73 的规划服务保留，实际控制执行仍关闭。

实现参考：MoveIt 的碰撞矩阵会省略与默认规则相同的项，因此验证同时检查禁止手部接触的默认规则、
实际碰撞拒绝以及抓取接触阶段的规则，而不是要求全 false 行必须出现在返回消息中。
[MoveIt Jazzy 碰撞矩阵实现](https://github.com/moveit/moveit2/blob/jazzy/moveit_core/collision_detection/src/collision_matrix.cpp)。
