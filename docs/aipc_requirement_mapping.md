> 本文保留 AIPC 分册的责任范围。完整 FPGA 工程与指标现已并入本包；统一内容以 architecture.md、interface.md、requirement_mapping.md 为入口。

# 具身智能赛道条款对应关系

唯一适用赛道：用户提供指南3.2，印刷页10–18（PDF页13–21）。本文只映射AI PC分册；不套用3.1的RTL/HLS容器、pass@k或3.3自主选题评分。

| 条款 | AI PC需要阐述/提交 | 本包位置 | 边界 |
|---|---|---|---|
| 3.2.2.3(1) | 本地推理、理解、任务/UI、通信、监控日志 | report/aipc_report.*、host/app | 桌面拾取半自主方案 |
| 3.2.2.3(3) | 数据流、通信、时间同步、异常处理 | docs/architecture.md、interface.md | 跨机时钟/真机闭环未验证 |
| 3.2.3.1 | 具体AI PC硬件、内存、驱动与ROCm版本 | metrics/logs/environment.json | 记录软件包及实际HIP版本，营销子型号待铭牌核实 |
| 3.2.3.3 | 系统图、划分、关键模块 | docs/architecture.md、report | 外部PS/PL仅说明接口责任 |
| 3.2.4.3 AI效果与性能 | mAP50–95、batch1分段/总延迟、吞吐 | metrics/metrics.csv、logs、scripts | 离线原始数据 + 用户现场吞吐/延迟反馈，来源分列 |
| 3.2.4.3 通信 | RTT或单向、吞吐/错误等 | metrics/logs/host_loopback.* | 只交付主机协议回环，不写成实际板间性能 |
| 3.2.4.4 至少两项专项 | 视觉/数据完整性、可靠性、滤波等 | metrics表及原始CSV | 含用户30分钟现场稳定性反馈；原始现场日志尚未提供 |
| 3.2.4.5 证据 | 硬件/软件/输入/精度/功耗模式/次数/时长 | environment.json、benchmark.json、CSV | 未测功耗、物理响应不填伪实测数值 |
| 3.2.5.1(3) | 模型、上位机与通信源码、部署依赖 | host/app、host/model、host/deploy | 推理/留出评估可复现，完整训练数据不在此包 |
| 3.2.5.2 | 指定表头、脚本、原始日志 | metrics/metrics.csv、scripts、logs、evidence | 软件图表不是示波器波形 |
| 3.2.5.3 | 可复用工作流（可选加分） | skill/readme.md | 未宣称跨机复用验收 |
| 3.2.5.4 | 背景、模型取舍、架构、结果、失败、复现 | report/aipc_report.md/.docx/.pdf | 可并入团队最终系统报告 |
| 3.2.5.5 | 英文文件路径及目录映射 | readme.md、文件清单 | 本包仅AI PC，不包含FPGA数值 |

完整作品仍需真实物理闭环成功率、采集到执行器响应的P50/P95/P99/max，以及FPGA贡献和真实板间协同证据。
这些交由团队联合实测/FPGA分册，不把主机推理FPS、回环RTT或测试通过率冒充它们。

R2已增加现场反馈，详见field_test_update.md。定位结果为各测点约5–8mm，未计算RMS；不把RMS≤5mm标为通过。
