# 指标与原始证据

`metrics.csv` 是统一提交汇总，严格采用指南七列表头，共 99 项。`aipc_metrics.csv` 保留 AIPC R2 的 50 项来源，`fpga/metrics.csv` 与 `fpga/audit/metrics.csv` 保留原 FPGA 56 项历史口径。总表已由实际 AIPC 指标替换原 FPGA 文档中的 AI 缺项，原表仅用于溯源。

总表的“证据文件”均相对本 metrics 目录；AIPC 原始数据在 logs/、evidence/，FPGA 原始数据在 fpga/audit/evidence/。类别和测量条件注明离线实测、用户反馈、历史状态、仿真、布线报告或待测。空白数值表示未测，建议目标不作为成绩。主机回环 RTT 不作为 AX7010 实链路 RTT，路径完成数不作为物品抓取成功率。

复算命令（包根目录）：`python metrics/scripts/check_metrics.py`，需 numpy；FPGA 复算：`python metrics/scripts/recompute_fpga_metrics.py --output <新的结果目录>`，使用标准库。AI 性能重测：`bash host/deploy/retest.sh`。包校验：`python metrics/scripts/verify_package.py`。

FPGA 历史 audit 的证据快照保持原字节；复算使用冻结副本并写入新目录。现场反馈原始日志尚未随输入包提供；相应不等式维持反馈界限。波形证据仅保留实际已有材料，不将统计图当作示波器截图。
