# RGB-D 与相机标定

> R2状态说明：下文保留原技术记录与配置快照。用户已补充现场测试反馈，最新情况见 [现场更新](field_test_update.md)；请勿将历史“未测试/未固定”表述用于否定当前反馈。

启动 `./scripts/start_vision.sh --headless` 和 `./scripts/start_dashboard.sh`，打开
http://127.0.0.1:8080。页面连续显示识别画面和对齐深度，状态显示实际处理 FPS。
颜色蓝→红对应 0.15→1.50 米显示范围，黑色是缺失/无效值；远于 1.50 米的有效值饱和显示为红色。
原始深度不被这个显示范围截断。点击深度图获取**最近深度采样帧**的三维点及帧号/年龄，
并非冻结的屏幕帧。过期超过 2 秒或无有效深度时不能输出有效测距。

`runtime/vision/depth.npz` 包含 `depth_m`（float32，米）、同帧 `color_bgr` 和 `metadata`（JSON 字符串）；
`latest.json` 提供检测框、21 个手部关键点、深度有效率、推理时间和实际处理 FPS。
深度原始快照以 5 Hz 更新，JPEG 默认上限 30 Hz，日志默认 2 Hz；`--record-all` 用于完整基准记录。
相机持续取帧，按完整 RGB-D 对丢弃过时帧，不把不同时刻的 RGB/深度拼接。
可导出彩色米制点云：`.venv-vision/bin/python scripts/export_depth_cloud.py`，
结果为 `runtime/vision/cloud.ply`（相机光学坐标系），配套 JSON 保存采样信息。
host_latency_ms 是主机接收→处理延迟，不包含曝光/USB 传输；设备时间戳单独保存。
`--compute auto|cpu|0`、`--threads 1`、`--imgsz 640` 可用于对照，降低 imgsz 可能损害细长工具召回。
YOLO 与手部模型对同一帧并行执行，两路都完成后才发布联合结果；不会复用旧帧手势充作当前检测。

## 1. 打印标定板

已生成 `config/calibration/checkerboard_9x6_20mm.svg`：**9×6 内角点**，每格 20 mm。
图纸尺寸 220×170 mm，A4 **横向**打印，选择实际尺寸/100%，关闭适应页面。
用尺核实每格尺寸，贴在平整硬板上，避免反光、弯曲。实际格长不等于 20 mm 时必须传入真实数值。

```bash
.venv-vision/bin/python scripts/calibrate_camera.py board --columns 9 --rows 6 --square-mm 20
```

## 2. 采集与检查彩色内参、深度

先退出占用 Gemini 的视觉/采集进程；一次只打开一个 SDK 采集程序。

```bash
.venv-vision/bin/python scripts/calibrate_camera.py capture --session runtime/calibration/table_01
```

在窗口中移动、倾斜标定板；识别成功后按空格保存，Q 退出。
建议 20–30 张，至少 15 张；棋盘中心覆盖画面至少 4 个九宫格区域，
前后距离、左右/上下倾角都要变化，不能只重复正面画面。棋盘整体应在视野内并清晰。
程序保存原图、角点、对齐深度和序列号；拒绝覆盖已有会话及几乎相同的连续视图。

```bash
.venv-vision/bin/python scripts/calibrate_camera.py intrinsics --session runtime/calibration/table_01
```

输出 `intrinsics_report.json`。每 5 张取 1 张仅用于留出重投影检查，其余拟合内参。
质量门槛：拟合 RMS <0.8 px、每张留出 RMS <1 px、覆盖≥4 格、板法线变化≥15°。
同时用 SDK 工厂内参计算棋盘平面，报告实测深度相对平面的 z 偏差。
留出图仍用其角点求棋盘姿态，这是内参重投影诊断，不等于外部测量精度证明。
当前 RGB-D 对齐仍使用 SDK 工厂内参；不会将新的彩色内参强行混用于工厂对齐深度。

## 3. 固定相机到基座外参（eye-to-hand）

完整安装位绑定、冻结同帧测点、异常点诊断和 PS 视觉接口流程见
[眼在手外视觉链路](eye_to_hand_pipeline.md)。当前相机未固定，不能启用真实外参。

相机固定，机械臂不需要连接主机也可以用测量工具获得基座坐标；没有基座实测坐标就停在此步。
模板 `config/calibration/correspondences.template.json` 不含虚构点。
同一物理标记分别记录深度相机光学坐标 `camera_m` 和基座坐标 `base_m`，单位均为米。
先填写 setup_id、camera_fixed、factory_intrinsic、factory_distortion，与 vision_station.json 的安装位保持一致。
覆盖工作区的至少 6 个点（建议 10–15 个）用于拟合，另取至少 4 个新位置用于独立验证。
深度点可由网页 `/api/point?u=...&v=...` 读取，记录其帧信息；点必须落在真实标记表面。
注意光学轴 x 向右/y 向下/z 向前，基座轴按 URDF；不要把桌面像素或毫米值填成米。

```bash
# 复制模板并填写实际测量；确认来自实测后将 physically_measured 设为 true
cp config/calibration/correspondences.template.json runtime/calibration/measured_points.json
.venv-vision/bin/python scripts/calibrate_camera.py extrinsics \
  --input runtime/calibration/measured_points.json
# 检查报告后启用；只有独立验证通过才会写入项目外参，原文件自动备份
.venv-vision/bin/python scripts/calibrate_camera.py extrinsics \
  --input runtime/calibration/measured_points.json --activate
```

约定 `p_base = T_base_camera @ [p_camera,1]`。当前默认验证 RMS ≤5 mm 且最大误差≤10 mm 才可通过首期粗定位检查。
这些阈值不是精密抓取验收标准；小工具抓取还需更严格的 TCP、夹爪和桌面定位检查。
移动相机、桌面或基座后必须重新测量；启动视觉时重新加载外参。
现有 `config/calibration/camera_to_base.json` 保持未标定；运行程序不等于已完成实物标定。

深度仅给出表面点。抓取方向、夹爪开口、碰撞体和接近/抬升轨迹尚需独立实现与验收。

## 现场数据采集质量

`capture_tool_dataset.py --scene flat|upright|negative` 按拍摄场次保存原始 PNG、
对齐深度和工厂内参，先预热 3 秒，拒绝 95% 像素亮度低于 12 的近全黑帧。
这只是全黑检查，不自动替代人工清晰度/曝光检查。采集不会生成类别标签。
同场次和相邻帧不得跨训练/验证/测试；真实照片的变换与抠图合成仅用于训练，
不能把增强图数量当成独立实物样本数。标注位置：`datasets/site_tools/annotations/`。

预览输出通过小容量令牌限频吸收采集与处理抖动，保持长期约 `--preview-fps`，
不再按固定时间格跳过边界帧。网页新帧检查间隔 10 ms；实测显示约 29.99 FPS。
