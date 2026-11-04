# v4 现场测试留出

124 张 / 393 框，来自完整场次 `table_20261102_233455_e7dcede4`。
只用于训练完成后的固定阈值比较和最终 AP 评估，不用于训练或选择最佳检查点。
标签来源 `../site_tools/annotations_web_v4/holdout.json`；原始数据仍完整保留。

此处 data.yaml 中 train/val 别名仅用于满足 Ultralytics 数据配置解析，**不得用于 model.train**。
新模型与旧 v3 使用 confidence=0.35、NMS IoU=0.45、类别一致且匹配 IoU≥0.50 比较。
AP 使用完整置信度排序，不能混淆 AP 和部署固定阈值检出率。

同一拍摄时段、工具和背景，因此仍有相关性；未验证新桌面、杂乱遮挡、手持/竖放或抓取成功率。


本目录属于统一提交包 AIPC 数据部分；复测入口为包根 host/deploy/retest.sh，结果索引为 metrics/metrics.csv。完整训练集未纳入本次软件包，当前冻结测试集与深度/标注保持原字节。
