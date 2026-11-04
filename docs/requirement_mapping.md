# 具身智能赛道提交条款对应

依据用户提供 `amd_contest_guide_2026.pdf` 第3.2节；提交内容为印刷页14–16（PDF页17–19）。文件名使用小写英文；原生工程内部扩展名与生成器名称中的点按格式保留。

| 条款 | 交付位置 | 已有内容 / 待补内容 |
|---|---|---|
| 3.2.3.1 平台、型号、驱动、ROCm | hardware_setup.md、../metrics/logs/environment.json | 记录实际版本；精确PC子型号/物理内存条容量仍需铭牌确认 |
| 3.2.5.1(1) 系统层 | architecture.md、interface.md、hardware_setup.md | 两端职责、数据流、协议、同步与异常边界 |
| 3.2.5.1(2) FPGA/Zynq | ../fpga/project/ | RTL、BD、XDC、依赖、脚本、BIT/XSA/HWH/ELF、实现与仿真记录 |
| 3.2.5.1(3) AI PC | ../host/app/、../host/model/、../host/deploy/ | 源码、模型、精度/来源、依赖、启动与复测；完整重训数据不全 |
| 3.2.5.1(4) 外设与硬件 | ../hardware/、hardware_setup.md | BOM、历史接线与照片；完整装配/电气和部分铭牌参数待补 |
| 3.2.4.3 任务成功率 | ../metrics/metrics.csv | 开发路径日志已有；物品级固定条件闭环验收待补 |
| 3.2.4.3 物理响应延迟 | ../metrics/metrics.csv | 主机感知与历史路径计时已有；采集到执行器响应P50/P95/P99/max待补 |
| 3.2.4.3 AI效果与性能 | ../metrics/logs/、../metrics/evidence/ | mAP50–95、分阶段推理、吞吐与现场反馈，分别标注来源 |
| 3.2.4.3 FPGA量化贡献 | ../metrics/fpga/audit/ | 资源/时序、仿真、CAN与保持读数；外部物理控制/PWM波形及同条件贡献实验待补 |
| 3.2.4.3 两端通信 | interface.md、../metrics/logs/host_loopback.json | 本机ARM1回环与历史CAN；真实AI PC—当前FPGA链路待联调/实测 |
| 3.2.4.4 专项至少两项 | ../metrics/metrics.csv | FPGA资源/时序、视觉/深度完整性、原现场可靠性反馈等 |
| 3.2.5.2 指标与证据 | ../metrics/metrics.csv | 统一七列表头，原日志、测试脚本、版本与分位数保留；未测值不填造 |
| 3.2.5.3 工作流 | ../skill/readme.md | 适用范围/命令/失效条件；跨设备完整部署验收未提供 |
| 3.2.5.4 报告 | ../report/design_report.md、../report/ | 总报告与AIPC/FPGA分册、失败及复现步骤 |
| 3.2.5.5 目录映射 | ../readme.md | 完整FPGA集中在fpga/project，保持工程依赖关系 |

以上为现有材料与条款的映射，不将打包校验作为实机验收。包内保留用户原始指南，不引入其他赛道容器/pass@k等无关要求。
