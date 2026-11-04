# AI PC 硬件与启动前检查

本机DMI为Micro Computer (HK) Tech Limited / EliteMini Series / F8BNB，CPU为Ryzen AI 9 HX370，iGPU Radeon890M(gfx1150)，
NPU XDNA2。准确营销子型号与物理内存条容量需据铭牌补充，本包记录操作系统实际可见内存，不把可用内存当物理标称容量。
版本和测试功耗模式以metrics/logs/environment.json为准。保留内核amdgpu，不安装amdgpu-dkms，不替换系统Python，不修改IOMMU。

Gemini 2接AI PC USB，提供640×480彩色与已对齐米制深度；历史连接协商为USB2 480Mbps，不能宣传为当前实测USB3吞吐。
AI PC以太网将来连接AX7010 PS；主机不直接驱动电机或夹爪，不能把USB供电当执行机构供电。
相机固定为眼在手外。安装前保持camera_fixed=false；固定后创建新的setup_id，用至少6个拟合点及4个独立验证点标定外参，建议10–15个拟合点。
外参须绑定序列号、工厂模型、分辨率、安装位；夹爪TCP、基座轴和工作区要与PS一致。详细步骤见simple_pickup.md和vision_calibration.md。
本包不提供虚构的接线图/执行器BOM；电机、驱动器、电源、PL接线由实际硬件分册说明。

仅打开网页不会自动启用相机/YOLO。采集预览和推理不可同时争用相机。
运行采集或推理前使用用户已有的设备权限脚本按实际Linux账户配置；脚本可能需要sudo，禁止把用户密码写入工程或报告。
对外只监听本机127.0.0.1的网页，测试令牌动态生成，不打包现场会话令牌。
