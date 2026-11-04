# AI PC 硬件与环境基线

> R2状态说明：下文保留原技术记录与配置快照。用户已补充现场测试反馈，最新情况见 [现场更新](field_test_update.md)；请勿将历史“未测试/未固定”表述用于否定当前反馈。

核对日期：2026-10-30。用户提供的 [AI PC 官方使用指南](https://zcnijjcepfie.feishu.cn/docx/E8cqdUGWsog0skxOmwHc6GkIngh)
正文与参考表已逐块读取（239 个可访问内容块，页面另引用一个未返回的末尾块）。原始页面、结构和可读文本保存在
`runtime/research/aipc-guide*`；指南中的另外几份内部文档并不包含在本页面内，未声称读取它们。

| 项目 | 本机实际情况 | 项目安排 |
|---|---|---|
| CPU | AMD Ryzen AI 9 HX 370 | 相机、手部关键点、ROS、通讯 |
| GPU | Radeon 890M，KFD gfx_target_version=110500，即 gfx1150 | ROCm YOLO 推理、YOLO11n 微调 |
| NPU | XDNA2，amdxdna 已加载，/dev/accel/accel0 存在 | 预留；当前未声称 NPU 推理成功 |
| 内存/磁盘 | Linux 可见约 28 GiB RAM、8 GiB swap；项目分区约 425 GiB 可用（配置前） | 小 batch，避免多套大模型常驻 |
| 系统 | Ubuntu 24.04.2，内核 7.0.0-38-generic | 保留现有内核内置 amdgpu/amdxdna |
| 机器人软件 | ROS 2 Jazzy / MoveIt 2.12.4 | scripts/env_jazzy.bash |
| 相机 | Orbbec Gemini 2，AY6T25501D7，固件 1.4.92 | 640×480 RGB + 对齐真实深度 |
| USB | 当前协商 480 Mbps（USB 2） | 提高分辨率前更换 USB 3 数据线/接口并复查 lsusb -t |
| 下位机 | 黑金 AX7010，PS Linux/IP 未定；FPGA 控制夹爪 | 以太网协议与本机模拟端，未接电机 |

采用指南的 **uv 虚拟环境方案**，按本机架构使用 gfx1150，不照抄指南 gfx1151 示例。
ROCm wheel 自带运行时，无需另装系统 ROCm 或更换 GPU 内核驱动。
版本固定为 PyTorch 2.13.0+rocm10.0.0、TorchVision 0.28.0+rocm10.0.0；
安装入口 `bash scripts/install_rocm_vision.sh`，约数 GB 下载。
`runtime/acceleration.json` 仅由矩阵运算和 YOLO GPU 验证真正通过后生成；
`.venv-rocm/verified` 存在时视觉启动脚本优先使用它。
CPU 回退：`VISION_PYTHON=$PWD/.venv-vision/bin/python ./scripts/start_vision.sh --compute cpu`。

已验证：ROCm 矩阵运算、YOLO11n GPU 推理成功，GPU 属性明确返回 gfx1150、约 14.8 GiB 可用统一内存。
默认三类工具模型 + 手部关键点 + RGB-D + 独立 ROS 发布流程，最终暖机后约 29.85 FPS（640×480），
270 个统计帧均有手，最多 2 手，联合处理耗时中位 25.0 ms；
固定双手参考图的 YOLO+手部并行耗时约 20.2 ms，每帧检出两手。
测量记录在 `runtime/research/performance-comparison.json`、`fixed-hands-gpu.json`。
后者不含相机/深度/网页，不能拿它换算成整机实测 FPS。实际速度随场景、曝光、后台训练而变化。

本机 Ultralytics 自动混合精度检查未通过（`runtime/research/amp-check.log`），首版训练采用 FP32。
不要为了加速绕过检查强制 FP16。`weights/yolo26n.pt` 是 Ultralytics 检查 AMP 时使用的辅助模型；
项目检测和训练模型仍为用户指定的 YOLO11n。

用户已执行 `sudo bash scripts/enable_ai_devices.sh`，GPU/NPU 当前 ACL 已核验；
render/video 组权限在下次登录后对新进程生效。相机 udev 规则已持久安装。
libatomic1、libquadmath0 已由系统安装。系统自带的 `libamdhip64-5` 不参与本项目 wheel 环境；
不对不相关软件做通配卸载，不设置指向旧 HIP 的 LD_LIBRARY_PATH。

联合环境核验发现，同一解释器同时加载 ROCm PyTorch 与 rclpy/FastDDS 会触发原生内存分配器异常。
已将 ROS 发布拆成系统 Python 子进程：`start_vision.sh --ros` 自动启动 `robotarm_vision.ros_publisher`，
读取原子更新的观测 JSON 并仅发布新鲜帧，退出时一起清理。GPU 推理进程不再 import rclpy。
使用 `--ros` 前仍需 `source scripts/env_jazzy.bash`。不要把这两个环境重新合并到一个进程。

NPU 的 FastFlowLM 安装涉及 XRT、成对匹配的驱动/固件、IOMMU 和 memlock。
当前任务为 YOLO11n 和手部检测，未安装无关 LLM 服务，也未修改 GRUB、固件或扩大 GTT。
后续若选用 NPU 跑 ONNX 检测器，应按 Ryzen AI Software 验证算子覆盖、量化精度及实际吞吐，
不能把 `/dev/accel` 的存在或 CPU/GPU 速度当成 NPU 验收。

依据：[AMD Ultralytics ROCm 指南](https://rocm.blogs.amd.com/ecosystems-and-partners/ultralytics-amd/README.html)、
[AMD PyTorch 安装](https://developer.amd.com/playbooks/pytorch-kernels/)、
[Ryzen AI Linux](https://ryzenai.docs.amd.com/en/latest/linux.html)。

## NPU 实测补充（2026-10-30）

已从 AMD 官方公开链接取得 `RAI_1.8_Linux_NPU_XRT.zip`，ZIP 完整校验通过，
解包至 `.npu/packages`，deb 仅解压到 `.npu/root`，未安装系统包、DKMS 或替换固件。
独立诊断 shell 可 `source scripts/env_npu_diagnostics.bash` 后执行 `xrt-smi examine`。
XRT 2.25.37 能枚举 `0000:66:00.1`、aie2p、6×8，读到固件 1.0.0.63。
但 `validate --run gemm` 和 `--run latency` 均返回 `ERT_CMD_STATE_ABORT`；
**设备枚举通过不等于 NPU 计算通过，当前不能启用 NPU 视觉推理。**
证据：`runtime/acceleration-npu.json` 和 `runtime/retraining/npu-*.json`。

Ryzen AI 1.8 Linux 模型运行时仍需 AMD 账号下载；用户当前无法下载。
官方 GitHub v1.8.0 release 没有附带该安装包，源码快照不能替代运行时。
后续需获取官方运行时并验证驱动/固件兼容性，再执行官方 CNN quicktest、
YOLO11n 导出/量化、算子覆盖和真实场景精度/延迟对比。
当前部署维持 GPU 负责 YOLO 推理与 FP32 训练，CPU 负责 RGB-D、手部模型、界面和通讯。
NPU 适合通过量化验证后的常驻低功耗推理；不用于本项目 YOLO 反向传播训练，
也不运行无关 LLM 来人为提高设备占用率。

XRT 失败时内核日志还记录 `Message callback ret -22` / `Channel in bad state`，
保存于 `runtime/retraining/npu-kernel-errors.txt`。尚未确定根因，不能仅凭此归因权限。
四类模型训练期间采样 30 秒，GPU busy 中位数 99%，采样记录
`runtime/retraining/gpu-training-utilization.json`；空闲或达到相机 30 FPS 上限时
不需要人为保持高占用。训练与实时推理竞争同一个 iGPU，正式演示应停止训练。

四类模型部署后发现推理约 30 FPS，但原预览限频会因完成时刻抖动丢帧，
JPEG 更新约 25 FPS、网页流约 23.89 FPS。预览改为可吸收小抖动的令牌限频，
网页检查新帧间隔从 25 ms 降到 10 ms；最终 180 帧采样中网页流 29.99 FPS，
预览文件更新 30.00 FPS、处理状态 29.96 FPS。场景为键盘/房间，无工具与手，
不能据此宣称实物识别率；记录 `runtime/retraining/web-stream-v2-paced.json`。
