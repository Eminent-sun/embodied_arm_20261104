# 具身智能机械臂软件提交包

版本：2026-11-04。依据随包 AMD 选题指南第 3.2 具身智能赛道、3.2.4 指标要求与 3.2.5 提交要求，将 FPGA 工程和 AIPC R2 合并为一个工程包。所有命令从指定目录执行，文件名统一使用小写英文。

## 文件入口

| 指南内容 | 本包位置 |
|---|---|
| 系统架构、数据流、接口、接线 | [docs/architecture.md](docs/architecture.md)、[docs/interface.md](docs/interface.md)、[docs/hardware_setup.md](docs/hardware_setup.md) |
| FPGA RTL、BD、约束 | `fpga/project/candidate/` |
| Vivado 原生工程 | `fpga/project/vivado2023_project/roboarm_ila_rx_debug.xpr` |
| 构建脚本 | `fpga/project/build/`、`fpga/project/software/build_executor_arm.ps1` |
| BIT、XSA、HWH、PS 初始化 | `fpga/project/bitstream/` |
| PS 源码、ELF、符号 | `fpga/project/software/` |
| 综合、实现、仿真及板级记录 | `fpga/project/reports/`、`fpga/project/software/reports/`、`metrics/fpga/audit/` |
| 模型及来源 | `host/app/models/`、[host/model/model.md](host/model/model.md) |
| AI PC 应用与通信源码 | `host/app/vision/`、`host/app/communication/`、`host/app/planning/` |
| 部署、启动、依赖 | [host/deploy/readme.md](host/deploy/readme.md)、`host/deploy/` |
| 指标统一汇总 | [metrics/metrics.csv](metrics/metrics.csv) |
| 原始日志、测试脚本、证据 | `metrics/logs/`、`metrics/scripts/`、`metrics/evidence/`、`metrics/fpga/audit/` |
| 硬件清单与接线参考 | [hardware/bom.csv](hardware/bom.csv)、`hardware/photos/` |
| 可复用流程 | [skill/readme.md](skill/readme.md) |
| 总体报告与两端分册 | [report/design_report.md](report/design_report.md)、[report/readme.md](report/readme.md) |
| 条款对应与文件校验 | [docs/requirement_mapping.md](docs/requirement_mapping.md)、`file_manifest.json` |

为保留 Vivado、PS 和调试脚本的相对路径，完整 FPGA 工程展开在 `fpga/project/`。这是对指南推荐 `fpga/src/build/report` 的目录映射，无需再解压子 ZIP。AIPC 应用目录结构保持原样。

## 校验与复现

解压到较短的英文路径。先在本包根目录执行：

```text
python metrics/scripts/verify_package.py
python fpga/project/software/tools/download_gripper.py
```

第二条不带 `--download`，只校验现有 BIT/XSA/ELF/PS 初始化/控制台配对。

AI PC 目标环境为 Ubuntu 24.04、Python 3.12、Ryzen AI 9 HX 370 / Radeon 890M；实际版本记录见 `metrics/logs/environment.json`。依赖安装会联网，驱动按本机设备环境准备。在包根目录执行：

```bash
python3 -m venv .bootstrap
.bootstrap/bin/pip install uv
export PATH="$PWD/.bootstrap/bin:$PATH"
bash host/deploy/setup.sh gpu
bash host/deploy/retest.sh
bash host/deploy/run_dashboard.sh --port 8080
```

网页入口为 `http://127.0.0.1:8080/workbench`。打开网页不自动启动相机；完整使用流程见 [host/readme.md](host/readme.md)。模型权重、124 图留出集和配对深度已包含；完整训练集另需原始训练资料。

FPGA 构建环境为 Windows、Vivado/Vitis 2023.1、相应 CAN IP 许可。先在 `fpga/project/` 执行：

```powershell
python -m unittest discover -s software/tests -p "test_*.py"
powershell -ExecutionPolicy Bypass -File software/build_executor_arm.ps1
powershell -ExecutionPolicy Bypass -File build/run_servo_sim.ps1
& 'D:/Xilinx/Vivado/2023.1/bin/vivado.bat' -mode batch -source build/build_nodebug.tcl
python build/export_ps_init.py
```

默认 Xilinx 路径为 `D:/Xilinx/`，实际安装位置不同需调整。最新源码运行、重建及板级操作入口见 [fpga/readme.md](fpga/readme.md)。实际下载会复位并清除 RAM 标定，按工程操作文档执行。

## 两端对应关系

AIPC 提供 RGB-D 感知、YOLO11n site v4、目标确认和 ARM1/TCP 接口；FPGA 工程提供 XSCT/JTAG-DDR、PS 运动学与状态机、PL CAN 和 PWM。两套已有传输协议不同；本包归并代码与证据，未新增协议桥接或宣称已完成 AIPC 到该 ELF 的物理闭环。详细契约见 `docs/interface.md`。

统一指标表保留离线实测、现场反馈、历史运行、仿真、实现报告和待测项的不同口径。缺少的完整闭环、物理响应延迟、真实板间通信及部分硬件资料见条款对应表。软件计时图不替代物理波形。

历史视频、多轮工程备份、Vivado 运行缓存、重复源码镜像及未被软件使用的历史机械子包已从提交包移除。构建所需 BD/IP、现有产物、原始测量证据和签名依赖保留。全部保留 README 已按本包位置更新；清理与来源记录在 `integrity/`。本包未执行硬件连接、烧录或运动。
