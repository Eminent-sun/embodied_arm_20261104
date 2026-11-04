# 硬件、供电与接线

已知主控：ALINX AX7010，Zynq-7010 `xc7z010clg400-1`；外部/PL时钟50MHz，CAN时钟20MHz。PC在本次材料核对时读取到ASUS TUF Gaming A16 FA608WI、Ryzen AI 9 HX 370、约32GB物理内存。该 PC 是 FPGA 调试侧历史清点；AIPC 实际推理设备与软件栈见 hardware_setup.md 和 ../metrics/logs/environment.json。

| 信号 | FPGA管脚/排针 | 连接 |
|---|---|---|
| CAN_TX | F17，J11 pin3，LVCMOS33 | CAN收发器TXD |
| CAN_RX | F16，J11 pin4，LVCMOS33 | CAN收发器RXD |
| servo_pwm | W19，J10 pin3，LVCMOS33 | 舵机信号线 |

以上来自当前XDC及既有说明；照片是历史参考，不能代替本次实物逐线核验。CANH/CANL经收发器到电机总线，不能直接接FPGA管脚。舵机和电机供电均需独立符合额定要求，W19仅输出信号；非隔离连接需可靠共地。收发器具体芯片、电源/逻辑电平、终端、电机电源额定值、保险和急停线路未形成完整台账。

已有用户确认ID1/3/4/5为EL05、ID2为RS00；目前六轴工程中ID6的实装型号/固件/铭牌未在本次归档中得到独立确认。`hardware/bom.csv`将未确认字段留空。图纸/URDF中出现的名称不自动代表实装BOM。

重现时先按当前装配核对各轴型号/ID、固件、方向、零点、偏置、行程及负载。`software/config/`下的历史校准/初始点不能自动用于新上电会话。下载BIT/ELF会复位并清RAM标定，需按现场操作说明重新建立有效引用。

历史输入另含小臂/腕部 CAD 和两套 URDF，其未被本软件构建调用，原件保留在用户原 ZIP；本包保留 BOM 和接线图片，仍缺整机可制造装配图、完整BOM、电源/电气原理图和传感器标定，因此还不能仅靠本材料完全复原机械电气装置。
