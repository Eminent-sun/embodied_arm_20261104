# AI PC 部署与启动

所有命令在提交包根目录执行。目标平台、软件实录见 `../../metrics/logs/environment.json`；模型来源见 `../model/model.md`。Ubuntu 24.04 / Python 3.12，CPU 与 ROCm 使用独立虚拟环境。

1. 创建 `.bootstrap` 并安装 uv，将其加入 PATH，命令见根 readme.md。
2. `bash host/deploy/setup.sh gpu`：安装 CPU 与 GPU 环境，依赖使用本目录两个 requirements 文件；`cpu` 模式只安装 CPU 环境。
3. `bash host/deploy/retest.sh`：在新建 retest 目录复测模型、离线 RGB-D、CPU 回退、主机回环和单元测试；不复写提交的原始日志。
4. `bash host/deploy/run_dashboard.sh --port 8080`：启动页面，浏览器访问 `/workbench`。
5. 现场感知按 `host/app/scripts/start_vision.sh --headless` 启动，实测外参和 TCP 配置见 `docs/simple_pickup.md`。

GPU 模式依赖兼容的 AMD 驱动与设备权限，锁定版本见本目录依赖文件。安装脚本不安装内核驱动。完整部署尚未在第二台全新机器验证；CPU 模式不能复现 GPU 指标。FPGA 的 Windows 调试控制台在 `fpga/project/software/tools/`，不属于这套 Linux 部署脚本。
