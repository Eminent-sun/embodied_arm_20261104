# 设计报告

阅读入口为 [design_report.md](design_report.md)，覆盖本次合并包的系统划分、两端内容与联合接口状态。

- `aipc_report.md`、`aipc_report.docx`、`aipc_report.pdf`：保留 AIPC R2 的设计/测试分册，三者来自同一输入包；文中“本分册”指 AIPC，FPGA现已在同一总包中。
- `fpga_report.md`：FPGA控制与实现分册，已修正旧“本包没有AI”描述及目录位置。
- `build_report.py`、`requirements.txt`：原 AIPC 分册生成脚本与依赖；其作用范围仍为 AIPC 文档。
- 统一数值来源为 `../metrics/metrics.csv`；原两端指标表保留用于溯源。

原历史技术计划书、视频及重复机械子包未纳入软件提交包。完整复现入口见根 readme.md，提交条款状态见 ../docs/requirement_mapping.md。
