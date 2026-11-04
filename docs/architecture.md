# 系统架构与数据流

```mermaid
flowchart LR
  cam[Gemini 2 RGB-D] --> ai[AMD AI PC: YOLO11n / MediaPipe / 深度与滤波]
  ai --> ui[人工选择与确认 / TCP目标与配置契约]
  ui --> tcp[ARM1 TCP 7010 / 7011]
  tcp -. 待适配和联合验证 .-> ps[AX7010 PS: 运动学 / 轨迹 / 状态许可]
  console[Windows 控制台 / XSCT JTAG] --> ddr[DDR请求 / CRC / 序号]
  ddr --> ps
  ps --> axi[PL AXI运动邮箱 / CAN调度 / PWM]
  axi --> motor[六轴执行器 / 夹爪]
  motor --> fb[CAN反馈与状态]
  fb --> ps
  ps --> console
```

AI PC 承担 RGB-D 采集、工具与手部检测、时间滤波、标定变换、任务目标确认和 UI。PS 承担运动学、路径和状态机；PL 承担 AXI 事务、CAN 帧调度/接收、独立 PWM 和服务超时。PL 有明确的自定义硬件逻辑和实现报告。

图中实线对应各自源码支持的链路，虚线是尚未由这两个输入包共同验证的接口适配。不能由合并文件推导“目标已物理执行”。各端详情见 aipc_architecture.md、fpga_architecture.md；跨端协议见 interface.md。
