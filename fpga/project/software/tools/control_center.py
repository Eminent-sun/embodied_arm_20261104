"""One manual entry point for paired download and the existing ARM console.
Opening this menu never connects to hardware. No automatic calibration/motion.
"""
import argparse,json,struct,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TOOLS=ROOT/'software/tools'
MENU='''
========== 机械臂 + 舵机统一入口 ==========
1  首次更新 / FPGA 重新上电：下载 BIT + ELF
   选 1 前：机械臂已承托，电机和舵机电源已切断，旧 ARM 控制台已关闭。
2  日常控制：进入电机 + 舵机共用的 ARM> 控制台
3  显示电机初始化、回 HOME 和舵机操作步骤
4  读取 PS 状态 / 故障诊断（不使能、不发 CAN）
5  退出后重新连接（仅清理已确认关闭输出的会话停止标记，不重新下载）
0  退出此菜单（不会更改板上状态）

日常只选 2；不要为了操作舵机而重新下载。
ARM> 中 STOP / QUIT 会请求六轴停止并关闭舵机 PWM；退出前先承托。
'''
GUIDE='''
【首次更新】
承托机械臂、切断六轴及舵机电源、关闭旧 ARM 控制台；FPGA 板和 JTAG 保持供电连接。
菜单选 1，看到 ARM_GRIPPER_DOWNLOAD_DONE 才算下载命令完成。
恢复需要使用的执行器电源，选 2 进入 ARM>；新程序不会自动使能。

【首次建立电机 HOME / 电机重上电后重新标定】
先在失能、有承托的情况下把实物摆到之前采用的 URDF HOME。
这不是让任意姿态自动回 HOME；CAL 会把当前轴的位置认作指定模型角并使能该轴。
在 ARM> 逐条输入，前一步 result=0 才继续：
  CONFIGHOME
  BEGIN
  CAL 1 0
  CAL 2 1.57
  CAL 3 0
  CAL 4 0
  CAL 5 1.57
  CAL 6 0
  SAVEINITIAL
  EXPORT "software/config/my_home.json"
  STATUS
预期 INITIAL_HOLD、enabled_mask=0x3f、calibrated_mask=0x3f、model_initial_saved=True。
CONFIGHOME 已包含新鲜读数检查，不需要再手动重复 READ。

【已标定后的电机操作】
  MOVETO X Y Z Roll Pitch Yaw  底座坐标 mm、姿态 deg，控制 Link6 原点
  GOHOME                      回到本次保存的初始 HOME，然后保持
  STATUS                      查看是否完成；到位前不要发下一段动作
例：MOVETO 200 0 100 0 0 0 是之前使用过的目标，但仍须确认当前机构路径无干涉。
result=0 / plan_valid=True 代表规划被接受；等 STATUS 到 CARTESIAN_HOLD 且 frames 完成才是本段执行结束。
若需要原固定路径，须在失能时先 PREVIEW 并成功，再完成标定。
之后 PICK -> 等 PICK_HOLD -> DELIVER -> 等 DELIVERY_HOLD -> RETURN -> 等 INITIAL_HOLD。
原 PICK/DELIVER/RETURN 没有自动插入夹爪动作；本次 RUNPATH 按下文顺序操作夹爪。

【按本次记录执行一次拾取递送路径】
先完成本次 HOME 标定；如不在初始点，先 GOHOME 并等到 INITIAL_HOLD。
  PATHINFO                    显示路径，不执行动作
  RUNPATH                     执行一次：初始 -> 拾取 -> 递送 -> 初始
当前 RUNPATH v3，共 6 段：先到高位 180 0 190 0 -10 0，再下移到原拾取点。
拾取点：180 0 160 0 0 0；下降到位后才等 5 秒，再闭合到 1490 us。
递送点：180 -150 170 -60 -90 0；到位等 3 秒，打开到 1110 us，渐变完成再等 2 秒，返回。
每段等待到位，夹爪也等待脉宽渐变完成；不自动循环。
运行中按 Ctrl+C 取消并请求 STOP。RUNPATH 期间不在 ARM> 接收其他命令。
PAUSED_HOLD 会终止后续步骤并保持，不自动恢复；故障或超时请求停止。
已修复 HOME 边界小偏差导致规划拒绝、随后 STOP 的问题；首段先检查规划。
规划拒绝且确认仍停稳保持时取消路径、保留力矩，不重试。
本次高位准备/下降仅更新电脑路径模块，已正常运行现有程序的无需重新下载或仅为更新重做 CAL。
下一次显式 RUNPATH 自动载入，开头应显示 v3；已启动的旧一轮不变。旧窗口 PATHINFO 可能显示上一版说明。
仅明确未执行的 result=6 会在原目标保持下有限等待 5 秒/3 次；已接受的运动不重发。

【同一电机供电会话，仅 PS 重载后恢复】
只有电机读数零点关系未变、且确认标定文件属于当前机械结构和 HOME 时才使用：
  RESTORE "software/config/my_home.json"
  RESUME
  STATUS
RESTORE 不使能；RESUME 使能并保持当前位置，不会回 HOME 或续跑。
之后需要回 HOME 才输入 GOHOME。不能用随包旧文件代替刚保存的 my_home.json。
电机电源重新上过电、零点关系不确定：按上面的新 HOME 标定步骤操作。

【舵机：可独立操作，不需要电机 BEGIN / CAL】
  GRIP INIT             初始位改为完全打开 1110 us
  GRIP OPEN             原张开位置 1220 us
  GRIP CLOSE            原闭合位置 1360 us
  GRIP OPENSTEP         每输入一次张开一步，目标减 10 us，下限 1110 us
  GRIP CLOSESTEP        每输入一次闭合一步，目标加 10 us，上限 1490 us
  GRIP US 1300          自定义脉宽 1110..1490 us
  GRIP OPEN 10 20       启用后的渐变：每 20 ms 最多变化 10 us
  GRIP CLOSE 2 100      启用后的渐变：每 100 ms 最多变化 2 us
  GRIP STATUS           查看 PWM，不是实际夹紧/到位传感器
  GRIP OFF              只关闭舵机 PWM，不停止六轴
逐次命令先读取最新目标，再变化 10 us；不自动重复。PWM 关闭时先 GRIP INIT。
从 OFF 启用时直接输出目标脉宽；后续目标改变才采用渐变。

【停止与重新连接】
STOP / QUIT 会请求电机停止并关闭 PWM；可能失去支撑力矩，先承托。
若仅退出了控制台而 PS 未重载，可选 5 重新连接。
FAULT_LOCKED 时，排除原因后：RECOVER；成功后且标定有效，再 RESUME。
PAUSED_HOLD 表示保持最后已确认目标；排除迟到原因、停稳后显式发新的 GOHOME / MOVETO。
不要通过反复下载跳过故障检查，也不要在没有标定时发送运动命令。
'''

def reconnect_cleanup(bridge,layout):
    """Explicit menu 5 only. Never clear a fault or enable an output."""
    import workflow_console as console
    snapshot=console.application_snapshot(bridge,layout)
    if not snapshot['application_matched']:raise RuntimeError('PS 与本控制台不匹配；没有写入任何数据。')
    if snapshot['state_number']==226:return '保留故障与停止标记；连接后先查看 STATUS，必要时显式 RECOVER。'
    if not snapshot['stop_flag']:return '没有待清理的停止标记。'
    address=int(layout['g_gripper_report']['address'],0)
    servo=struct.unpack('<13I',bridge.read(address,13))
    if servo[:2]!=(0x53525631,1) or servo[5]:
        raise RuntimeError('PWM 尚未确认关闭；不清理停止标记。保持承托，等 PS 处理停止后再连接。')
    if snapshot['state_number']==0:
        console.clear_idle_stop(bridge,layout,snapshot)
    elif snapshot['state_number']==1:
        console.reconnect_confirmed_disabled(bridge,layout)
    else:
        raise RuntimeError('当前状态不支持清理停止标记；请使用菜单 4 查看状态。没有清除故障、使能或复位。')
    return '仅清理已关闭输出的会话停止标记；没有使能或发送 CAN。'

def run_action(choice,xsct):
    """Return child exit status. No chaining download into enable/console."""
    if choice=='3':print(GUIDE);return 0
    if choice not in ('1','2','4','5'):raise ValueError('请输入 0..5。')
    from download_gripper import verify
    verify()
    if choice=='1':
        command=[sys.executable,str(TOOLS/'download_gripper.py'),'--download','--xsct',xsct]
    else:
        if choice=='5':
            import workflow_console as console
            layout=json.loads((ROOT/'software/reports/workflow_symbols.json').read_text())
            bridge=console.Bridge(xsct)
            try:print(reconnect_cleanup(bridge,layout))
            finally:bridge.close()
        command=[sys.executable,str(TOOLS/'workflow_console.py'),
                 '--diagnose' if choice=='4' else '--connect','--id2-positive','--xsct',xsct]
    return subprocess.run(command,cwd=ROOT,check=False).returncode

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--guide',action='store_true',help='Print steps only; no hardware connection')
    parser.add_argument('--xsct',default='D:/Xilinx/Vitis/2023.1/bin/xsct.bat')
    args=parser.parse_args()
    if args.guide:print(GUIDE);return
    while True:
        print(MENU)
        try:
            choice=input('请选择：').strip()
            if choice=='0':return
            code=run_action(choice,args.xsct)
            if code:print(f'操作未完成，返回码 {code}。保留上面的错误输出；未自动重试。')
        except (EOFError,KeyboardInterrupt):print('\n已退出菜单。');return
        except (OSError,ValueError,RuntimeError) as exc:print('未完成：',exc)

if __name__=='__main__':main()
