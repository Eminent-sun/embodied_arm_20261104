# 硬件、接线与运行环境

AI 推理证据对应 Micro Computer (HK) Tech Limited / EliteMini Series / F8BNB，Ryzen AI 9 HX 370、Radeon 890M gfx1150。OS 可见内存约28.98GiB，物理条容量与精确营销型号待铭牌确认。系统为 Ubuntu24.04.2，kernel7.0.0-38，内核amdgpu，ROCm SDK10.0.0、torch HIP7.15.26333。保留两种版本字段，按源环境 JSON 解释；不把 torch 包后缀替代实际 HIP 版本。

原 FPGA 清点的 ASUS TUF Gaming A16 FA608WI / HX370 / 约32GB 为另一调试工作站记录。不得与 AIPC 的推理测试硬件混用。完整来源见 `../metrics/logs/environment.json`、`fpga_runtime_environment.json`。

控制板为 ALINX AX7010 / xc7z010clg400-1，PL50MHz、CAN20MHz。CAN_TX=F17/J11pin3，CAN_RX=F16/J11pin4，舵机PWM=W19/J10pin3，LVCMOS33。CAN 经外部收发器连接 CANH/CANL；W19只作信号，舵机和电机电源按实装额定值独立配置，非隔离连接共地。完整引脚/供电约束与未确认项见 fpga_hardware_setup.md。

相机为 Orbbec Gemini2；固定外参、深度对齐、TCP标定见 aipc_hardware_setup.md、vision_calibration.md、simple_pickup.md。包内真实标定配置未激活；用户现场反馈的测点误差约5–8mm，现场标定文件与原始日志尚未补入，不能以模板配置覆盖实测配置。

实装清单见 `../hardware/bom.csv`，历史接线照片在 `../hardware/photos/`。机械完整装配图、电源保护、急停线路及ID6铭牌等未确认字段保持原状态。
