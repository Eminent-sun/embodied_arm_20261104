# 当前 FPGA 工程操作入口

此目录为统一提交包中的 fpga/project。上层总入口是 ../../readme.md；以下命令均在本目录执行。应用源码、BIT/XSA/ELF 和当前控制配置来自原 FPGA 工程；README、文档路径及大小写构建适配已更新。

离线核对：python software/tools/download_gripper.py（不带 --download）。
离线软件测试：python -m unittest discover -s software/tests -p "test_*.py"。
完整操作步骤：docs/operator_guide_20261104.md。
PWM 协议：docs/servo_interface.txt。
RUNPATH v3：docs/pickup_approach_30mm_20261104.md。

Windows 控制入口：00_control.cmd；下载入口：01_download_with_actuators_off.cmd；控制台：02_console.cmd。下载、连接和运动均需操作者显式选择。下载会清除 RAM 标定，六轴与舵机电源、机械支撑按操作文档核对。

当前 RUNPATH 为六段路径，先到高位准备点再下降；GRIP INIT=1110 us，OPEN=1220 us，CLOSE=1360 us，允许范围1110..1490 us，PWM50Hz。GRIP/PWM 状态是命令状态，不是物理夹紧反馈。源码和详细限制以随包操作文档为准。

新 AIPC 应用在 ../../host/app，不使用本工程的 JTAG 控制台作为 Linux 部署入口。两端接口对应见 ../../docs/interface.md。

构建与重建方法见 ../readme.md。当前源码含标准库控制台及可选 unicorn/pyelftools ARM 离线验证；原来源未锁定这两个测试依赖的准确版本。历史调试备份已清理，仅保留签核需要的基准；所有文件校验以 ../../file_manifest.json 为准。
