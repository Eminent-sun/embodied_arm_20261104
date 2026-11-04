# FPGA / Zynq 工程

当前完整工程在 `project/`；内部目录保留 Vivado/PS/控制台相对布局。板卡 AX7010，器件 xc7z010clg400-1；PL 50 MHz，CAN 20 MHz。工具 Vivado/Vitis 2023.1。

| 功能 | 本目录相对位置 |
|---|---|
| RTL / 仿真 / XDC / BD / IP | `project/candidate/` |
| 原生工程 | `project/vivado2023_project/roboarm_ila_rx_debug.xpr` |
| 构建与离线签核 | `project/build/` |
| BIT / XSA / PS 初始化 / HWH | `project/bitstream/` |
| PS C、平台、求解器 | `project/software/src/`、`include/`、`platform/`、`vendor/` |
| 配套 ELF | `project/software/build/arm_workflow.elf` |
| 综合实现、时序资源报告 | `project/reports/` |
| Windows 控制台与协议 | `project/software/tools/` |
| 操作步骤 | `project/docs/operator_guide_20261104.md` |

在 `project/` 执行 `python software/tools/download_gripper.py`，默认只做离线文件配对检查。构建命令见总 README；`build/check_relocated.tcl` 检查工程输入路径，不要求已清理的实现运行缓存。

工程从原内部 ZIP 展开，删除历史修订、可重建 .runs 产物、会话 journal/backup 以及未启用的旧增量 DCP。保留当前签核实际引用的三份历史基准，保持其相对位置。小写化将 `start.S` 改为 `start.s`，构建命令显式指定 assembler-with-cpp，启动汇编内容与现有 ELF 不变。

既有 BIT/XSA/ELF 与 AIPC 模型保持原字节。当前控制传输为 XSCT/JTAG-DDR；AIPC ARM1/TCP 的协议对应见 `../docs/interface.md`。本包未重新综合、烧录或运行机械臂；已有报告仍对应其原采样/构建条件。

机械操作前按当前现场确认供电、支撑、有效标定与停止流程。历史 calibration 文件仅是来源证据，不自动成为新上电的有效标定。
