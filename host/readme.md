# AI PC 应用与复现

本目录为统一具身智能提交包的 AI PC 部分，保留 2026-11-04 R2 源码、模型、数据及证据。以下路径和命令均以整个提交包根目录为基准。FPGA 工程见 fpga/project/，统一指标见 metrics/metrics.csv。
原工程源码、配置、权重和数据保持不动；本包为独立副本，未上传到任何外部平台。

## 首先阅读

- 正式文档：`report/aipc_report.docx`（可编辑）、`report/aipc_report.pdf`（查看/打印）、`report/aipc_report.md`（文本源）。
- 指标汇总：`metrics/metrics.csv`，表头按指南；原始逐次CSV/JSON在`metrics/logs/`。
- 剩余的AI PC验收及精度优化：`metrics/acceptance_targets.csv`给出具体门槛和方法，不是实测成绩。
- 条款对应：`docs/requirement_mapping.md`，原指南见`docs/amd_contest_guide_2026.pdf`。

FPGA 实现与板级历史记录已并入 fpga/project/ 和 metrics/fpga/audit/。主机协议回环不是AI PC到真实AX7010链路实测，离线处理FPS不是实际摄像头/执行器闭环FPS。
两端传输接口和已有证据范围见 docs/interface.md；真实协同与物理任务验收仍按条款对应表补充。

## 目录与指南对应

| 路径 | 内容 |
|---|---|
| `docs/` | 系统图、数据流、接口、硬件设置、标定与指南对应 |
| `host/app/vision/` | RGB-D、检测/手部、滤波、标定、上位机源码 |
| `host/app/communication/` | ARM1主机接口、视觉遥测及本地参考接收端 |
| `host/app/planning/` | 原规划几何与可选ROS代码；简化TCP提交不依赖MoveIt |
| `host/app/models/` | 正式模型、手部模型、官方基础YOLO及SHA256清单 |
| `host/model/` | 模型来源/版本/精度说明与上游许可证 |
| `host/app/config/` | 未启用的真实标定/TCP配置，禁止用模拟数值覆盖 |
| `host/deploy/` | 隔离安装、启动、复测脚本和完整依赖锁文件 |
| `host/app/datasets/` | 124图留出集、配对深度、标签和采集元数据 |
| `data/provenance/` | 数据来源/许可/版本、原工程源文件哈希 |
| `metrics/` | 指标表、逐次日志、脚本、统计图、明确标注的历史记录 |
| `skill/` | 复用流程、适用范围与失效条件 |
| `report/` | 设计/测试分册及文档生成脚本 |

应用内目录保留原相对布局，模型放`host/app/models`，而说明放`host/model`，这是对推荐目录的映射。
原始文档在包内改用小写英文文件名；正文可以中文。仓库文件路径通过字符检查，未把Python缓存/用户虚拟环境打包。

## 从零部署（需要联网获取依赖）

目标环境：Ubuntu24.04、Python3.12、Ryzen AI 9 HX370/Radeon890M gfx1150及兼容的内核amdgpu。
不得照搬本机内核到不支持的设备；先检查实际驱动和GPU设备权限。GPU环境与ROS系统Python分开。

```bash
# 在解压后的 embodied_arm_20261104 根目录执行。
python3 -m venv .bootstrap
.bootstrap/bin/pip install uv
export PATH="$PWD/.bootstrap/bin:$PATH"
bash host/deploy/setup.sh gpu
```

若系统缺少python3-venv，先使用系统包管理器安装该组件；不替换系统Python。
安装脚本仅创建包内`.venv-vision`和`.venv-rocm`，不更换内核/驱动，也不自动开启相机。
GPU依赖来自AMD `stable.repo.amd.com/rocm/whl-next/`，CPU torch来自官方CPU索引；版本见锁文件，网络镜像不可用时不得静默更换版本后复用本次结果。

根据实际权限需要，检查`host/app/scripts/enable_ai_devices.sh`、`install_camera_permissions.sh`；如需sudo，由本机操作者执行，报告和源码不包含密码。
已有模型文件随包提供，不必重新下载或覆盖现场微调权重。查看`host/app/models/manifest.json`核对SHA256。

未在第二台全新机器完成整套安装验收；本次实际验证是在同一AI PC的独立代码/数据副本上使用已验证环境运行。
完整1065图训练集/204图验证集未附，重训需要另行取得；本包提供权重、完整测试集和数据来源，可重跑报告中的检测评价与性能测试。

## 复测（默认不打开相机、不发真实运动指令）

```bash
bash host/deploy/retest.sh
```

默认输出到新建`retest_日期_时间`目录，不覆盖本次正式证据。依次测量ROCm环境CPU/GPU、固定留出集AP、离线RGB-D处理、独立CPU回退、主机回环和软件回归。
GPU/CPU分别持续60秒，离线RGB-D30秒，回环10秒；机器负载、温度和依赖不同会影响结果。AP精度不等于抓取成功率。
脚本不会启动YOLO常驻服务、ROS或真实机械臂。所有生成的人工测点只在临时测试上下文中使用，不写真实标定。

批量性能测试应在相机预览、实时推理、训练及其他高负载任务停止后运行。本次线程设置会在模型首次初始化后重新固定为1，避免推理库自动线程配置影响比较。

## 运行网页 / 现场功能

```bash
bash host/deploy/run_dashboard.sh --port 8080
# 浏览器打开 http://127.0.0.1:8080/workbench
```

仅打开网页不启动相机。首页`/`用于素材采集，`/workbench`为简化拾取，`/planning`为保留的高级预览。
需要检测时主动执行`host/app/scripts/start_vision.sh --headless`，不要同时打开采集预览。
默认外参、TCP和工作区未验证，所以不会生成可用于实机的基座目标。按docs/simple_pickup.md先固定相机、实测标定并核对PS坐标契约。
当前简化流程只生成笛卡尔目标并提交，不要求ROS/MoveIt；本软件包未包含旧 URDF 资产/ROS 构建产物，不把高级MoveIt规划视为可直接复现的本分册验收项目。

## 证据范围与已知限制

当前报告的模型效果来自同工具/同时间附近的完整留出场次；尚无跨日期、陌生工具、竖放收纳盒的独立验收。
采集元数据的原split/unlabelled字段原样保留，实验真值和划分以`annotations_web_v4/holdout.json`、最终标注和manifest为准。
手部时延有实测，手部关键点准确率没有人工标注真值。深度有效率有档案复核；新增用户现场反馈：各测点三维定位误差约5–8mm，RMS未计算，不能宣称RMS≤5mm。
NPU只保留历史诊断证据，未宣称推理可用。整机功耗和跨机同步误差未测，不填写假数据。

报告中的统计图是软件计时/人工输入图，不是示波器或逻辑分析仪波形。原始CSV保留P99之外的离群最大值，没有删掉长尾。

## 完整性检查

```bash
python3 metrics/scripts/verify_package.py
```

对照`file_manifest.json`逐文件检查SHA256。该清单已按合并后的所有交付文件重新生成（除清单自身）；ZIP 外另附整包 SHA256。
源文件保护记录在`data/provenance/source_integrity.json`，该记录说明 AIPC 原分册的来源；本次合并文件来源和文档修改见 integrity/source_map.json。AIPC 应用源码、模型、数据和配置保持原字节，数据集 README 除外。
本包不赋予第三方模型/数据新的许可证，来源及上游许可见host/model与data/provenance；未对外发布用户图片。

## R2 现场测试更新

用户反馈完整现场感知≥25帧/秒，连续30分钟；主机P95≤50ms、P99≤80ms、最大≤150ms；30分钟异常/人工重启0/0，均已达标。各测点定位误差约5–8mm，尚未计算RMS。原始反馈与补充确认保存在metrics/evidence/field_test_feedback.json及.md。指标中的不等式是反馈界限，不是恰好测得的精确点值；现场原始日志与标定配置尚未提供。

原有自动采集的离线/回环数据保持不变。R2只修订文档和指标来源，host/app源码、模型、数据及配置与旧包逐文件相同；不把旧配置的未激活状态当作用户现场未测试的结论。
