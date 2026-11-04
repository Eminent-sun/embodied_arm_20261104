# 可复用工作流

以下路径从提交包根目录执行。两端详细范围分别见 [aipc_readme.md](aipc_readme.md)、[fpga_readme.md](fpga_readme.md)。

| 工作流 | 用法 | 适用条件与失效条件 | 已有验证范围 |
|---|---|---|---|
| 提交包校验 | `python metrics/scripts/verify_package.py` | 任意 Python3；缺文件/哈希/路径不符即失败 | 本次合并包逐文件检查 |
| FPGA 产物配对 | `python fpga/project/software/tools/download_gripper.py` | 文件版本须成套；不带下载开关 | 本地 BIT/XSA/ELF/PS-init/控制台配对 |
| AI 部署与复测 | `bash host/deploy/setup.sh gpu`、`bash host/deploy/retest.sh` | 对应 Linux/驱动/依赖；变更模型、输入或后端后需重测 | AIPC 原环境的副本测试，非第二台干净环境 |
| 冻结指标复算 | `python metrics/scripts/check_metrics.py` 与 `recompute_fpga_metrics.py --output <新目录>` | 原始日志完整、各自分位数定义不变 | AIPC 原 CSV 统计与 FPGA 冻结日志 |
| RGB-D 到目标 | 按 `docs/simple_pickup.md` 配置并使用 workbench | 实测外参/TCP、目标有效；标定移动、过期和握手失败拒绝提交 | 软件契约测试与原现场反馈 |
| 单次机械路径 | FPGA 操作文档中的显式 RUNPATH | 有效现场标定、状态与供电；故障不得自动重放 | 已归档的开发日志及离线验证 |

干净环境部署时间、第二设备/第二场景迁移结果尚无完整记录，未将脚本存在等同于迁移验收。
