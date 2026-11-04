# 机械臂电机＋舵机总脚本详细使用说明

适用目录：`D:\FPGA_jingsai\optimization\robstride_arm_gripper_20261104`。
入口：双击该目录的 `00_control.cmd`。本说明按当前代码核对，日期为 2026-11-04。

## 1. 现在该从哪一步开始

如果刚才已经在同一个 ARM> 窗口控制舵机，且没有重新下载、没有给 FPGA 或电机重新上电，先输入 `STATUS`，根据下表选择下一步。不要为了切换到电机控制而再次下载。

| 当前状态 | 下一步 |
|---|---|
| OFF | 如要做末端运动，先摆到已确认的实物 HOME，再执行第 4 节的新标定流程。 |
| CONFIGURED，尚无完整标定 | 在已确认的实物 HOME 执行 BEGIN、逐轴 CAL、SAVEINITIAL。 |
| INITIAL_HOLD / CARTESIAN_HOLD，六轴标定完整且初始点已保存 | 可以先 CHECKPOSE，再按第 5 节显式 MOVETO。 |
| CALIBRATING | 核对哪些轴已完成 CAL，完成剩余轴后 SAVEINITIAL；不要直接 MOVETO。 |
| MOVING_CARTESIAN / PICKING / DELIVERING / RETURNING | 继续 STATUS 观察，先等当前动作结束。 |
| PAUSED_HOLD | 查看第 8 节，停稳并排除迟到原因后再显式发新目标。 |
| FAULT_LOCKED | 先承托并查看 STATUS，处理故障后按第 8 节 RECOVER。 |
| REFERENCE_HOLD / REFERENCE_SAVED | 这是原始位置参考流程，尚不能据此认定已完成模型 HOME 标定。 |

当前版本要求 CAN 电机 ID 1、2、3、4、5、6 均在线，舵机另走 PWM。早期聊天标题中的“五电机”不代表本脚本会跳过第六轴。若现在实际只接了五台，请先确认缺失哪一轴，不要照六轴流程强行继续。

## 2. 菜单各项做什么

| 输入 | 用途 | 会发生什么 |
|---|---|---|
| 1 | 首次下载、更换 BIT/ELF，或 FPGA 断电后重新加载 | 配置 FPGA、初始化 PS 并运行 ELF；会复位程序，RAM 内标定会丢失。 |
| 2 | 日常共用控制台 | 进入 ARM>，输入电机或舵机命令。不会自动标定或开合。 |
| 3 | 显示内置操作提示 | 只显示说明，不连接硬件。 |
| 4 | 诊断程序状态、故障 | 读取保存的 PS 状态；不使能电机，不发送新的 CAN 查询。 |
| 5 | 退出控制台后重新连接 | 在已确认输出关闭的条件下清理旧会话停止标记，再进入控制台；不会自动清除故障或使能。 |
| 0 | 关闭菜单 | 关闭菜单本身。 |

菜单里的“2”和 ARM> 里的命令不是同一层。看到 ARM> 后只输入命令本身，例如 `STATUS`，不用输入 ARM>。

只保留一个控制台连接这套机械臂，避免多个控制台同时写请求。控制台运行时负责维持心跳，关闭窗口或连接中断会触发停止处理。

## 3. 确实需要下载时

仅在需要更新程序或 FPGA 重新上电时执行：

1. 承托机械臂，切断 CAN 电机和舵机的执行器电源，关闭旧 ARM 控制台；FPGA 和 JTAG 保持连接。
2. 双击 `00_control.cmd`，菜单选择 `1`。
3. 等待出现 `ARM_GRIPPER_DOWNLOAD_DONE`；出现错误时保留完整输出，不继续标定或运动。
4. 恢复需要使用的执行器电源，菜单选择 `2`，等待 ARM>。
5. 输入 `STATUS`。

新程序启动时六轴不自动使能，舵机 PWM 默认关闭。因为这次扩展了舵机范围到 1110～1490 μs，需要下载这次配套的 BIT 和 ELF 后新范围才生效；若已经更新并在正常使用，不要重复下载。

## 4. 首次使用／电机重上电后的 HOME 标定

### HOME 的含义

这里的 HOME 是先前约定的实物机械臂姿态，对应模型关节角：

`[0, 1.57, 0, 0, 1.57, 0] rad`。

先在失能且有承托的情况下，把实物摆到此前已确认的 URDF HOME。上面的数字只说明模型角，不能代替实物 HOME 图或机械定位。若不确定当前摆姿是否为该 HOME，先不要执行 CAL。

`CONFIGHOME` 不会把机械臂移动到 HOME；它读取当前电机位置，准备本次标定配置。`CAL` 会把当前轴位置认作给定的模型角，并使能这一轴保持当前姿态。不能在任意摆姿下套用这些角度。

当前菜单采用 ID2 正向配置：方向系数为 `[-1,+1,-1,-1,-1,+1]`。程序仍将其标为待实物核对的候选配置；不能将旧方向标定文件直接套用到这个入口。

### 逐条操作

下面每行单独输入；前一步 result=0 才继续，不要整段盲贴：

```text
CONFIGHOME
STATUS
```

CONFIGHOME 预期 `configured=True`、`enabled=False`，随后状态为 CONFIGURED。它已包含新的六轴位置采集，不需要为了这一步重复 READ。

```text
BEGIN
STATUS
```

对新配置，预期进入 CALIBRATING。随后逐轴执行：

```text
CAL 1 0
STATUS
CAL 2 1.57
STATUS
CAL 3 0
STATUS
CAL 4 0
STATUS
CAL 5 1.57
STATUS
CAL 6 0
STATUS
```

每执行一次 CAL，该轴会进入使能保持。若 result 非零、某轴异常移动或状态进入 FAULT_LOCKED，不执行剩余步骤，按第 8 节处理。

六轴全部成功后：

```text
SAVEINITIAL
EXPORT "software/config/my_home.json"
STATUS
```

预期：

```text
state = INITIAL_HOLD
enabled_mask = 0x3f
calibrated_mask = 0x3f
model_initial_saved = True
```

这些字段必须结合查看。`0x3f` 表示六轴全部；仅有一个 result=0 不代表已经完成整套标定。

`SAVEINITIAL` 保存当前六轴初始姿态，后续 GOHOME 返回这里；`EXPORT` 把本次记录保存到电脑。电机重新上电、零点关系变化或机械结构变化后，旧文件不能直接视作新标定。

## 5. 移动到 XYZ＋姿态目标

前提：六轴模型标定完成、初始位置已保存，机械臂处于可用的保持状态。

格式：

```text
CHECKPOSE X Y Z Roll Pitch Yaw
MOVETO X Y Z Roll Pitch Yaw
```

- XYZ 使用 URDF 底座坐标系，单位 mm。
- Roll、Pitch、Yaw 单位为度；CAL 的单位则是弧度，两者不要混用。
- 当前目标位置对应模型 Link6 原点。装上抓夹后，夹爪尖端不一定就是这个坐标点。
- MOVETO 使用关节空间插补，不能将其当作末端沿直线运动。

下面是先前使用过的格式示例，不代表当前摆姿到这个点的路径已经确认：

```text
CHECKPOSE 200 0 100 0 0 0
```

CHECKPOSE 只做计算，不启动移动。检查输出的 result、plan_valid、model_only 等字段。当前入口还会核对方向配置；空白启动时可能先拒绝 CHECKPOSE，需要按本说明完成相应配置和标定。若其他入口显示 model_only=True，只表示模型求解，不能当作实机已经可动。计算成功也不等于完成了机械臂与环境的碰撞检查。

确认目标、方向、当前配置和路径后，显式执行：

```text
MOVETO 200 0 100 0 0 0
STATUS
```

MOVETO 返回 result=0、plan_valid=True 表示请求与规划通过。继续用 STATUS 查看执行状态：运行中为 MOVING_CARTESIAN；完成后应为 CARTESIAN_HOLD，且 frames 的完成数等于总数。未完成前不发下一段动作。

`duration_ms` 是规划时间，实际运行还包含通信、逐组核验及等待耗时，不要单按秒表判断完成。

## 6. 返回本次保存的初始位置

```text
GOHOME
STATUS
```

GOHOME 会真正启动电机运动，返回本次 SAVEINITIAL 保存的六轴姿态；完成后应为 INITIAL_HOLD。它需要有效的实机标定，不能用来代替首次摆 HOME 和 CAL。

## 7. 只想让电机保持现在的位置

如果暂时不需要 XYZ 运动，也不确定模型 HOME，可以使用原始当前位置保持流程。由 OFF 状态开始、实物已承托时输入：

```text
HOLDINITIAL
STATUS
```

它新读取并保存当前六轴位置，然后显式使能保持这次读到的位置，预期进入 REFERENCE_HOLD。当前保持参数是速度 0.1 rad/s、加速度 0.1 rad/s²；手动偏离后会尝试返回捕获位置。

这个流程会使能电机，但不会建立 URDF 模型标定。完成 HOLDINITIAL 后不能直接认定已具备 MOVETO／GOHOME 的条件。若之后需要改做模型运动，先按停止、恢复失能的流程处理，再摆好实物 HOME，进行第 4 节标定；不要在保持力矩下强行摆姿。

只保存原始位置而不使能可用 `SAVEPOSE`。原始位置文件与 EXPORT 导出的完整标定文件用途不同。

## 8. 停止、故障与重新连接

### STOP 和 QUIT

```text
STOP
STATUS
```

STOP 请求电机停止并关闭舵机 PWM，可能让机构失去支撑力矩。它不是“暂停并保持”的命令；执行前准备承托。STATUS 中应检查 stop_confirmed 和当前状态，而不是把“Stop requested”当作停止已确认。

`QUIT` 也会请求停止，然后退出控制台。控制台异常退出或主机心跳丢失也会触发停止处理。

### FAULT_LOCKED

1. 承托机械臂，查看 STATUS 并保留完整输出。FAULT_LOCKED 下的部分位置数据是故障时保存的观察值，不一定是新的实时读数。
2. 排除断线、供电、运动受阻等实际原因后，显式输入：

```text
RECOVER
STATUS
```

RECOVER 重新核验停止，成功后回到失能待命，不会自动使能或继续旧轨迹。若恢复失败，停在这里，不反复发运动命令。

3. 如果本次标定仍有效、方向配置未变且电机未重上电，可以显式：

```text
RESUME
STATUS
```

RESUME 会使能并保持当前位置，不返回 HOME，不续跑中断轨迹。之后需要回初始位置，再显式 GOHOME。

如果标定不完整、电机重上电、方向配置有变化，或控制台提示旧方向记录被拒绝，则重新执行第 4 节，不使用旧记录 RESUME。

### PAUSED_HOLD

表示调度迟到超过 100 ms，且通信和反馈仍满足保持条件，程序保持最后核验的目标。它不会自动继续原动作。查看 STATUS，排除电脑卡顿或通信问题，待机构停稳后，再显式选择新的 GOHOME 或 MOVETO。STOP 在此状态下仍会请求停止。

### 仅退出过控制台，没有重新下载或给电机断电

回菜单选择 `5` 重新连接，再 STATUS。菜单 5 只在满足关闭输出条件时清理旧会话停止标记；如果是 FAULT_LOCKED，仍需明确 RECOVER。

## 9. 同一电机供电会话中，只有 PS 被重新加载

仅在电机零点、偏置和机械结构未变，且标定文件确属这套当前配置时使用：

```text
RESTORE "software/config/my_home.json"
STATUS
RESUME
STATUS
```

RESTORE 只装入记录，不使能。RESUME 是另一个明确的使能步骤，先检查零点、偏置、范围及当前状态。失败就保留输出，不绕过检查。

如果电机重新断电上电，或不能确认零点关系，改用新的 HOME 标定流程。

## 10. 舵机命令

| 命令 | 作用 |
|---|---|
| GRIP STATUS | 查询 PWM 状态，不请求使能。 |
| GRIP INIT | 启用到完全打开的初始目标 1110 μs。 |
| GRIP OPEN | 到预设张开目标 1220 μs。 |
| GRIP CLOSE | 到预设闭合目标 1360 μs。 |
| GRIP OPENSTEP | 每输入一次，目标减 10 μs，最低 1110 μs。 |
| GRIP CLOSESTEP | 每输入一次，目标加 10 μs，最高 1490 μs。 |
| GRIP US 1300 | 自定义目标 1300 μs，允许 1110～1490 μs。 |
| GRIP OFF | 关闭 PWM，不停止六轴电机。 |

逐次命令在 PWM 关闭时会拒绝，先 GRIP INIT。以目标值累加，不会自动重复。初始 1110 μs 起，闭合 38 次到 1490 μs；从闭合端张开 38 次回到 1110 μs。

舵机可以独立操作，不需要电机 BEGIN/CAL。STOP、QUIT、主机失联或六轴故障会关闭 PWM；PAUSED_HOLD 保留舵机指令。PWM 状态和 pulse_ramping 字段反映输出命令，不是实际夹紧或到位反馈。

## 11. 原固定路径（可选）

这条流程有预设路径，只有确认其适合当前机构和环境时才使用。需要在失能时先 `PREVIEW` 并成功，再执行 HOME 标定。

标定并保存初始点后，顺序为：

```text
PICK
```

等待 STATUS 到 PICK_HOLD，再输入 DELIVER；等待 DELIVERY_HOLD，再输入 RETURN；最后等待 INITIAL_HOLD。PICK／DELIVER／RETURN 不会自动插入夹爪开合，舵机需要单独命令。

仅使用 MOVETO／GOHOME 时，无需为了它们执行 PREVIEW。

## 12. 常见结果怎么理解

| 提示 | 含义／处理 |
|---|---|
| result=0 | 这一条请求通过；运动命令还需等 STATUS 确认完成。 |
| INPUT REJECTED | 输入或前置条件不满足；看提示，不反复发送后续动作。 |
| FAULT_LOCKED | 故障锁定；先查状态和原因，再 RECOVER。 |
| calibrated_mask 不是 0x3f | 六轴模型标定未全部完成。 |
| model_initial_saved=False | 尚未保存可供模型运动使用的初始位置。 |
| 配套文件校验失败 | 使用同一整套工程，不能混搭 BIT、ELF 或控制台文件。 |
| 等待 PS 初始化 | 等待状态检查完成；不要同时开另一控制台或反复下载。 |
| CONTROL_ERROR／请求超时 | 保留完整输出，承托并确认停止；不会自动重试运动请求。 |

日志位置：`software/operator_logs/` 下按时间命名的文件夹。故障状态下执行 STATUS 会保存相应快照；RECOVER 前也保存恢复前证据。

本说明通过读取现有脚本与代码整理；编写说明期间没有连接板卡、使能电机或发送运动命令。软件离线测试通过不代表任意实物摆姿、方向或路径均已验证。

## 13. RUNPATH：一次拾取、递送、返回（v3）

本次在原已跑通的五段路线中增加高位准备和下降，共六段：先到`180 0 190 0 -10 0`，再下移到原拾取点`180 0 160 0 0 0`并恢复Pitch=0°，确认到位后等5秒再闭合1490 μs。其余递送、打开1110 μs、等待和返回沿用原路线。

本次只改电脑路径模块，不需重新下载BIT/ELF或仅为更新重做CAL。当前窗口下一次显式RUNPATH载入新模块，开头应显示RUNPATH v3。已经启动的旧一轮不变；旧窗口PATHINFO可能显示上一版内存说明，以RUNPATH的v3开头和阶段输出为准。

先STATUS确认有效标定、INITIAL_HOLD且实物停稳，再运行。电机断电或零点关系变化后，仍按第4节重新建立实物HOME标定。完整操作和验证见[pickup_approach_30mm_20261104.md](pickup_approach_30mm_20261104.md)。
