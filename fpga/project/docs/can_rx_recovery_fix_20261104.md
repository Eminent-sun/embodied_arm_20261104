# 本次error=5与RECOVER失败

故障会话：`software/operator_logs/20261104_154243`。已通过JTAG的APU内存目标读取DDR、已定义的邮箱寄存器及CAN错误诊断寄存器；没有写板上寄存器、发CAN命令、暂停CPU或复位程序。

## 直接证据

| 项目 | 读数 | 含义 |
|---|---|---|
| ARM状态 | FAULT_LOCKED，error=5，fault_cause=5 | 底层通信/读写健康检查失败 |
| 停止确认 | True，enabled_mask=0，ack_mask=0x3f | 控制器确认六轴停止；故障位置读数是保存的快照 |
| 邮箱RX_ERRORS | 0x20 | can_rx_service的CAN ERROR锁存位 |
| 邮箱HEALTH | 0x3f1b | 包含接收完整性丢失标记 |
| CAN ESR | 0x06 | 填充错误、格式错误标志 |
| CAN ECR | 0x8000 | 接收错误计数128、发送错误计数0 |
| 邮箱RX_OVERFLOW / TX_STATUS | 0 / 0 | 此次读数未显示接收溢出或待发送状态 |

前一会话记录两轮完整执行成功。保存的故障目标等于当前标定的HOME，尚未发现v3新增Z190准备点被接受的记录。现有证据不能把故障归因于新增下降段，也不能确定具体是哪台节点或哪段接线造成接收错误。

`candidate/rtl/can_rx_service.v`明确将CAN ERROR锁存到公共PL复位；`software/src/path_mailbox.c`的healthy检查要求RX_ERRORS为0；硬件恢复入口同样要求接收完整性正常。因此当前RECOVER返回5符合现有限制，不能靠反复RECOVER或RESUME解除。没有放宽保护或自动清除错误。

## 当前处理顺序

1. 承托整个机械臂，保持当前日志。暂不发RESUME、GOHOME、RUNPATH或重新CAL。
2. 关闭电机和夹爪执行器电源，再检查CANH/CANL接插件是否松动、共地是否可靠、线缆是否被拉扯、屏蔽/走线和供电是否异常。若需测量总线终端，断开所有相关总线节点电源后测量；只有总线恰好有两只120Ω终端时，H-L间才通常约为60Ω，不额外盲加终端。
3. 修正接线/供电问题后，执行器仍保持断电，退出旧ARM控制台，保留FPGA和JTAG连接。总菜单选1，重新加载现有配套BIT/ELF，等待ARM_GRIPPER_DOWNLOAD_DONE。这是为了清除公共PL复位才会解除的错误锁存，不是更新轨迹或更换程序版本。
4. 在失能、有承托状态下摆回已确认的实物HOME；恢复六轴及夹爪供电，菜单选2，STATUS检查新程序状态。
5. 本次执行器已断电、程序也重载，重新执行CONFIGHOME、BEGIN、逐轴CAL、SAVEINITIAL、EXPORT；不得RESTORE旧绝对电机位置替代。
6. 确认INITIAL_HOLD、无故障、六轴标定完整并停稳，先保持观察，再显式RUNPATH。不要在刚恢复时反复启动。
7. 如果尚未运动就再次出现error=5，先停下，保存STATUS和日志，继续定位总线/供电问题，不再反复烧录、标定或运动。

首次标定命令及实物HOME要求见《operator_guide_20261104.md》；当前六段轨迹见《pickup_approach_30mm_20261104.md》。CAN波形和实际电气故障仍需现场测量，现有寄存器只能确定错误类型，不能替代物理定位。

证据：`software/reports/incident_154243_can_diagnosis.json`及对应只读Tcl/日志。首次诊断的连续读取跨过未定义的邮箱0x0c偏移，产生一次读取错误，随后改为逐个已定义寄存器读取并获得上述结果；没有请求任何寄存器写入或复位。
