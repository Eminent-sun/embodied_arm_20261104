# AI PC 对外接口

AI PC→PS 使用以太网 TCP，实际板卡 IP 待对接。7010 为显式确认的目标/控制接口，7011 为观测遥测，禁止把遥测直接当伺服设定。
本包的通信性能数值仅来自 127.0.0.1 回环；不是实际网线或 AX7010 时延。

ARM1 帧头为大端 `!4sIII`：magic=ARM1、version=1、JSON字节长度、CRC32。报文最大1MiB，JSON拒绝NaN/Inf。
请求必须有递增seq，回复需匹配seq、ok状态。socket默认超时2秒。不要通过简单text socket直接发送裸JSON绕过帧头。

目标提交：hello核对cartesian_target能力及配置contract_id → set_cartesian_target(confirmed=true,target) → 核对原样回显。
关键target字段：schema_version=1；task=tabletop_pickup；frame_id=base_link；units=mm；tcp_id；position_mm；orientation_xyzw；
orientation_convention=R_base_tcp_xyzw；approach_mm；lift_mm；surface_base_mm；calibration_id；source_session_id；track_id；class_name；target_id。
抓取TCP位置 = 1000 × (R_base_camera × p_camera + t_base_camera) + surface_to_tcp_base_mm。
姿态是TCP到基座的旋转四元数，xyzw顺序；不是欧拉角。接近和抬升沿基座+Z，当前需Z向上且固定抓取姿态经过实测。
PS以法兰逆解时，应使用其已标定的法兰到TCP模型；不再转换相机坐标。

ACK：accepted=true，state=target_received，execution_started=false，target逐字段相同。UI仅显示被ACK确认的目标。
收到目标不代表IK成功、运动开始或抓取成功。PS本地的路径/限位/碰撞检查与执行结果另行对接。
目标ID/配置指纹不匹配、外参未绑定、深度缺失、目标ID丢失、手存在、坐标跳变、过期图像均阻止新目标提交。
已接收目标是历史任务记录；目标丢失不会重新发送，断线后不会自动开始运动。不得以“冻结坐标仍存在”推断现场仍可执行。

时间方案：当前采集记录主机接收RGB-D时间和设备时间戳；本机阶段耗时和回环RTT使用同一主机单调时钟。
软件观测有效期在接收侧以本地单调时钟累加，不依赖两机墙钟完全一致；这不等于双机同步或曝光起算的硬实时截止期。
目前未实现或验证AI PC—PS跨机时钟同步，故不报告单向网络延迟。未来真实链路优先测同机发/收RTT；若测单向或物理闭环，
需对共享触发/硬件时间戳/PTP方案验证同步误差后再报结果。其波形由联合实验取得，不在此AI PC分册中伪造。

实现位置：host/app/communication/robotarm_link/protocol.py、cartesian.py、vision_protocol.py；上位机目标生成在host/app/vision/robotarm_vision/pickup.py。
通信回环测试只启动临时本机参考接收端，结束后关闭，不触碰实体电机。
