# FPGA 指标分册

统一总表见 `../metrics.csv`。本目录 `metrics.csv` 与 `audit/` 是原 FPGA 日志审计快照，56 项中含历史结果与待测建议；原 AI 缺项现已由总表中的 AIPC 实际指标补充，不用于判断合并包是否包含模型。

`audit/evidence/` 保存实现报告、CAN ILA、控制台日志、必要源码与 ELF 快照，保留原哈希。完整当前 FPGA 工程在 `../../fpga/project/`。审计快照不能与更新后的运行日志混算。

从包根执行 `python metrics/scripts/recompute_fpga_metrics.py --output <新目录>` 可复算冻结数据，结果不覆盖历史证据。完整抓取闭环、物理响应延迟、真实两端通信和外部 PWM 波形仍依赖后续实测。
