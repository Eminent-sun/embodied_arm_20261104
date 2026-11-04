# 接口定义与数据类型

## PC到PS

源码：完整工程 `software/tools/workflow_protocol.py`、`workflow_bridge.tcl`、`workflow_console.py`。经XSCT/JTAG读写DDR，桥接限制0x00100000..0x00200000的对齐访问；原桥接单次最多32个32位字，Python正常分块最多24字。

请求结构总长836字节：`<4I f`头20字节，344字节配置，468字节记录，最后4字节CRC32。头为sequence、GO=0x57464c31、operation、axis、reference(float32)；按小端编码。CRC覆盖前832字节。序号需单调，不允许复用造成重放。地址由当前ELF符号文件 `software/reports/workflow_symbols.json`确定，不跨版本硬套。

操作码包含BEGIN=1、CAL=2、SAVEINITIAL=3、PICK=4、DELIVER=5、RETURN=6、STOP=7、READ=8、CONFIG=100、RESTORE=101、PREVIEW=105、CHECKPOSE=106、MOVETO=107、GOHOME=108、RECOVER=109、RESUME=110、GRIP=111。笛卡尔输入为XYZ毫米、RPY度，求解内部关节弧度。GRIP报告是指令/PWM状态，非物理夹紧反馈。

## PS到PL

运动邮箱：0x40000000，4KB，当前ABI=0x00020009；控制器支持0x00020008/9。偏移见完整工程 `software/include/motion_mailbox.h` 和 `candidate/rtl/pl_motion_mailbox.v`，包括CONTROL、暂存目标、QUERY、COMMAND_STATUS、RESULT、HEALTH、RX_ERRORS、计数和RECOVER。事务必须串行，不可把若干float直接写到CAN基址当成多轴轨迹。

舵机：独立0x40001000，4KB，ID=0x53525631，ABI=0x00010000。CTRL完整32位写1原子提交/启用，写0关闭；目标1110..1490us，step=1..10us，interval=1..50帧，帧20ms。KICK=0x4b49434b服务1s；迟到心跳不能自动重新启用。完整寄存器表已收在操作文档的SERVO_INTERFACE副本。

## CAN及物理输出

已有CAN配置为1Mbit/s、29位扩展帧、DLC=8，HOST_ID=0xfd；bitrate是设计配置，不是持续有效吞吐实测。参数读type0x11、写0x12、使能0x03、普通失能0x04；参数index在byte0/1，小端float32位模式在byte4..7。电机参数/缩放/零点须按实装型号和固件核对，普通失能请求不等于外部硬件急停。

CAN管脚F17/F16，PWM管脚W19。详细电气接线见hardware_setup。现有材料没有测得跨PC/PS时钟同步误差，正式通信报告先用RTT。
