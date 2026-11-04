# 两端接口与执行边界

| 项目 | AIPC 应用 | 当前 FPGA 工程 |
|---|---|---|
| 通道 | ARM1/TCP，控制7010、遥测7011 | XSCT/JTAG 读写 DDR |
| 帧 | 大端 `!4sIII`，magic/version/JSON长度/CRC32 | 小端836字节：20字节头+344配置+468记录+4 CRC32 |
| 位置 | base_link，毫米 | XYZ 毫米 |
| 姿态 | TCP到基座的 xyzw 四元数 | RPY 度；运动学内部弧度 |
| 许可 | contract_id、标定/TCP ID、显式 confirmed | 有效标定、CONFIG/BEGIN、状态检查、命令序号 |
| 回复 | 目标接收 ACK，execution_started=false | 操作结果、运动/保持/故障状态 |

AIPC hello、set_cartesian_target 与 ACK 不等于现有 ELF 的 MOVETO/GRIP 指令。两端尚需显式匹配传输、配置/坐标、姿态转换、状态许可、停止和执行完成定义，包内未提供已经验证的协议转换桥。不得将参考 TCP 接收端的 ACK 解释为真实抓取完成。

详细报文与时间约定：[aipc_interface.md](aipc_interface.md)、[ax7010_protocol.md](ax7010_protocol.md)、[fpga_interface.md](fpga_interface.md)。PS/PL 运动邮箱0x40000000、ABI0x00020009；PWM外设0x40001000、20ms帧、1110..1490us，寄存器见 `../fpga/project/docs/servo_interface.txt`。

AIPC 本机耗时和回环 RTT 使用同机单调时钟；未验证 AI PC 与 PS 跨机同步。真实两端通信优先用发端同机 RTT 测量，单向延迟需另给同步误差。旧 CAN 读取和本机回环分别保存，均不替代本版跨端链路性能。
