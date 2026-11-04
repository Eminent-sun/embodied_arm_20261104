# 模型与来源声明

工具检测：Ultralytics YOLO11n，本地四类微调 site v4，FP32 推理，未量化。正式文件在 host/app/models/tools_yolo11n.pt，哈希和来源链见同目录 manifest.json。基座官方来源：https://github.com/ultralytics/assets/releases/download/v8.3.0/yolo11n.pt 。运行库 Ultralytics 8.4.193、ROCm PyTorch 2.13.0+rocm10.0.0，安装包和 GPU 配置见依赖锁文件。模型为 2,597,780 个融合后参数，基于当前日志统计，不以 GFLOPs 推算 FPS。

任务类 0 screwdriver，1 pliers，2 scissors（包含用户蓝色剪切钳），3 tweezers。不是通用全部工具或 PCB 检测器。

手部：MediaPipe Hand Landmarker，官方 float16/1 模型资产，SHA256 见 manifest.json。本项目使用 CPU delegate、VIDEO 模式、最多两手、每手 21 点；float16 是官方模型资产类型，不代表整个 CPU 感知流程均为 FP16。真实深度来自 Gemini 2，禁止把模型 normalized z 当米制。

训练：25 epochs、batch16、640、FP32、AdamW lr0=0.0006，验证集选择第21轮；训练参数/曲线见 metrics/historical/training_args.yaml、training_results.csv。本包提供部署权重、完整124图留出测试及配对深度、标签与数据来源清单。未附全部1065训练图和204验证图，因而完整训练复现需另外取得原训练数据；推理和本包测试复现不依赖它们。

来源及许可：Ultralytics 许可证原文随附 ultralytics_license.txt；不要把该衍生模型笼统声明为 MIT。手部模型下载源见 manifest.json。公开训练数据来源/版本/许可声明见 data/provenance；其中原始图片权属未逐张独立验证，本包不重分发公开训练图。现场测试图片由用户提供，仅在此次本地交付包中附带，未上传外网。包内工程不统一改授其他许可证。

NPU 未完成 YOLO 部署验证，不宣称 NPU 加速。CPU 回退环境与 ROCm 环境分离；ROS 只在独立系统 Python 进程运行。
