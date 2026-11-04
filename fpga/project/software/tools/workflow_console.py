"""Explicit manual console. No connection unless --connect is given.
The background worker alone owns XSCT and maintains a DDR heartbeat.
"""
import argparse,concurrent.futures,hashlib,json,queue,re,shlex,struct,subprocess,threading,time
import importlib
import recorded_cycle as recorded_cycle_module
from pathlib import Path
from workflow_protocol import OPS,make_request,save_record,load_record,record_info,pose_info,pose_from_readback,save_pose,load_pose,cartesian_payload,cartesian_report
from gripper_protocol import STEP_COMMANDS, gripper_payload, gripper_report
from prepare_machine_config import prepare_for_home_calibration
from recorded_cycle import RecordedCycleRunner, CycleError, CyclePaused, CyclePlanRejected, describe_cycle
from prepare_home_alignment import SIGN, ID2_POSITIVE_CANDIDATE
ROOT=Path(__file__).resolve().parents[1]
STATES={0:'OFF',1:'CONFIGURED',2:'CALIBRATING',3:'INITIAL_HOLD',4:'PICK_HOLD',5:'DELIVERY_HOLD',6:'PICKING',7:'DELIVERING',8:'RETURNING',9:'REFERENCE_SAVED',10:'REFERENCE_HOLD',11:'MOVING_CARTESIAN',12:'CARTESIAN_HOLD',13:'PAUSED_HOLD',226:'FAULT_LOCKED'}
HELP='''CONFIG <machine.json>  configure verified mechanics/rates; no enable
CONFIGHOME [file.json] freshly capture physical URDF HOME and configure for CAL; no enable
HOLDINITIAL [file.json] capture a NEW current-position reference, save to PC, then hold; never compare an old file
SAVEPOSE [file.json]    capture/save raw reference only; no enable
HOLDPOSE <file.json>    explicitly hold a saved raw reference only if already at that pose
PREVIEW                compute the full fixed-path geometry while disabled; not needed for raw hold
CHECKPOSE X Y Z R P Y   solve/preview only; base XYZ in mm, RPY in degrees
MOVETO X Y Z R P Y      move Link6 to pose, joint-space interpolation; calibrated hold required
GOHOME                 return to calibrated saved initial pose; then hold
RECOVER                recheck stop and recover to disabled standby; no automatic enable or replay
RESUME                 explicitly enable and hold CURRENT pose using retained calibration; no homing
BEGIN                  begin calibration, or explicitly hold a restored initial pose
CAL <ID1..6> <model_rad> capture known reference angle and enable ONLY that axis to hold
SAVEINITIAL            save one six-axis initial pose
EXPORT <file.json>     save calibration/initial pose to PC (no CAN)
RESTORE <file.json>    restore complete calibration; no enable
PICK                   preset -> position1 -> descend; then hold
DELIVER                rise -> position2 -> forward; then hold
RETURN                 retreat -> saved initial joint pose; then hold
PATHINFO               show recorded pick/delivery route; no motion
RUNPATH                run ONE pick/delivery/return cycle from calibrated HOME; Ctrl+C stops
STATUS                 show state/feedback
READ                   fresh read-only motor mode/position/velocity/zero/offset
STOP                   emergency stop and fault latch
QUIT                   request stop, close console
GRIP OPEN/CLOSE/INIT    enable PWM: OPEN=1220, CLOSE=1360, INIT=1110 us
GRIP OPENSTEP/CLOSESTEP one manual step: target -10/+10 us; requires PWM enabled
GRIP US <pulse> [step interval_ms]  pulse=1110..1490 us; default 10 us/100 ms
GRIP OFF / GRIP STATUS  disable PWM / read PWM state (no mechanical sensor)
RUNPATH explicitly sequences the gripper once; ordinary commands have no automatic sequence/repeat. CAL angles are model radians.
Dispatch lateness >100 ms: PAUSED_HOLD at last verified target if feedback/transport remain healthy. New MOVETO/GOHOME is explicit; no auto replay.
Raw reference hold: PP speed=0.1 rad/s, accel=0.1 rad/s2; release after manual deflection returns to captured target.
The PC file is a per-session motor reference; it does not calibrate URDF HOME or write motor zero.
STOP/QUIT/host loss disables gripper PWM; PWM-off does not confirm mechanical release.
Keep mechanical support available: STOP/host loss can disable torque.'''
class Bridge:
    def __init__(self,xsct):
        self.process=subprocess.Popen(['cmd.exe','/d','/c',str(xsct),str(ROOT/'tools/workflow_bridge.tcl')],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
        self.lines=queue.Queue()
        def reader():
            for line in self.process.stdout:self.lines.put(line.strip())
            self.lines.put(None)
        threading.Thread(target=reader,daemon=True).start()
        self.read_until('BRIDGE_READY',45)
    def read_until(self,marker,timeout):
        lines=[];deadline=time.monotonic()+timeout
        while time.monotonic()<deadline:
            line=self.lines.get(timeout=max(.001,deadline-time.monotonic()))
            if line is None:raise RuntimeError('XSCT bridge exited')
            if line==marker:return lines
            if line.startswith('BRIDGE_ERROR'):raise RuntimeError(line)
            lines.append(line)
        raise TimeoutError('XSCT bridge timeout')
    def transfer(self,line):
        self.process.stdin.write(line+'\n');self.process.stdin.flush();return self.read_until('BRIDGE_DONE',2)
    def read(self,address,count):
        result=[]
        for start in range(0,count,24):
            lines=self.transfer(f'GET {address+4*start} {min(24,count-start)}')
            data=next((line[9:] for line in lines if line.startswith('DATA_HEX ')),None)
            if data is None:raise RuntimeError('No DATA_HEX result; check that workflow_console.py and workflow_bridge.tcl are from the same version')
            tokens=data.split()
            if any(not re.fullmatch(r'[0-9A-Fa-f]{8}',token) for token in tokens):raise RuntimeError('Invalid DATA_HEX word')
            result.extend(int(word,16) for word in tokens)
        if len(result)!=count:raise RuntimeError('Incorrect memory result length')
        return struct.pack('<'+'I'*count,*result)
    def write(self,address,data):
        words=struct.unpack('<'+'I'*(len(data)//4),data)
        if len(words)>24:raise ValueError('Use short queued writes so heartbeat can run between chunks')
        self.transfer('PUT '+str(address)+' '+' '.join(hex(word) for word in words))
    def close(self):
        try:self.process.stdin.write('QUIT\n');self.process.stdin.flush()
        except (OSError,ValueError):pass
        try:self.process.wait(timeout=2)
        except subprocess.TimeoutExpired:self.process.terminate()

def application_snapshot(bridge,symbols):
    def read_words(name,count):return struct.unpack('<'+'I'*count,bridge.read(int(symbols[name]['address'],0),count))
    header=read_words('g_arm_report',12)
    geometry=read_words('g_approved_path_geometry',5)
    cartesian=read_words('g_arm_cartesian',2) if 'g_arm_cartesian' in symbols else None
    gripper=read_words('g_gripper_report',2) if 'g_gripper_report' in symbols else None
    return {'report_address':symbols['g_arm_report']['address'],
            'expected_magic':'0x57465231','actual_magic':f'0x{header[0]:08X}',
            'version':header[1],'state':STATES.get(header[2],header[2]),'state_number':header[2],
            'error':header[3],'stop_confirmed':bool(header[10]),'fault_cause':header[11],
            'active_mask':header[4],'calibrated_mask':header[5],'initial_saved':header[6],
            'stop_flag':read_words('g_arm_stop',1)[0],
            'request_go':read_words('g_arm_request',2)[1],
            'geometry_magic':f'0x{geometry[0]:08X}','geometry_complete':geometry[2],
            'geometry_count':geometry[3],'geometry_math_passed':geometry[4],
            'cartesian_interface_matched':cartesian==(0x43505231,1) if cartesian is not None else None,
            'gripper_interface_matched':gripper==(0x53525631,1) if gripper is not None else None,
            'application_matched':(gripper is None or gripper==(0x53525631,1)) and header[0]==0x57465231 and header[1]==1 and header[2] in STATES and header[4]<=63 and (cartesian is None or cartesian==(0x43505231,1))}

def timing_details(data):
    values=struct.unpack('<16I',data)
    if values[:2]!=(0x54494d31,1):return None
    names=('frame_index','elapsed_ms','due_elapsed_ms','lateness_ms','observe_ms','publish_ms',
           'last_service_ms','max_service_ms','completed_at_ms','next_due_elapsed_ms',
           'fault_kind','period_policy','sample_ms','reserved')
    result=dict(zip(names,values[2:]));result.pop('reserved')
    if values[15]:result['dispatch_late_limit_ms']=values[15]
    result['fault_reason']={0:'none',1:'total_job_deadline',2:'frame_dispatch_late'}.get(values[12],'unknown')
    result['schedule']={0:'legacy_absolute_grid',1:'verified_completion_plus_interval'}.get(values[13],'unknown')
    return result

def fault_details(bridge,symbols):
    """Read saved DDR values only. Never poll CAN, halt, reset or clear flags."""
    data=bridge.read(int(symbols['g_arm_report']['address'],0),30)
    h=struct.unpack_from('<12I',data)
    if h[:2]!=(0x57465231,1) or h[2]!=226:return {'available':False}
    position,velocity,target=(struct.unpack_from('<6f',data,offset) for offset in (48,72,96))
    result={'available':True,'frames_completed':h[7],'error':h[3],'fault_cause':h[11],
            'saved_motor_rad':position,'saved_velocity_rad_s':velocity,'last_commanded_motor_rad':target,
            'saved_position_minus_target_rad':[p-t for p,t in zip(position,target)],
            'scope':'Saved observations from the fault; axes after the first failed check may retain the preceding scan. These are not fresh motor readings.'}
    if 'g_arm_timing' in symbols:
        result['timing']=timing_details(bridge.read(int(symbols['g_arm_timing']['address'],0),16))
    record=bridge.read(int(symbols['g_arm_calibration']['address'],0),117)
    try:record_info(record)
    except ValueError:
        result['thresholds_available']=False;return result
    rows=[]
    for a in range(6):
        axis=struct.unpack_from('<3I10f',record,56+a*52)
        reasons=[]
        if not axis[5]<=position[a]<=axis[6]:reasons.append('position_outside_configured_range')
        if abs(velocity[a])>axis[9]:reasons.append('velocity_above_trip')
        if abs(position[a]-target[a])>axis[10]:reasons.append('following_error_above_limit')
        if reasons:rows.append({'motor_id':a+1,'violations_in_saved_values':reasons,
                               'velocity_trip_rad_s':axis[9],'following_error_limit_rad':axis[10],
                               'safe_motor_range_rad':[axis[5],axis[6]]})
    result['violations_in_saved_values']=rows
    return result

def wait_for_application(bridge,symbols,timeout=600,progress=print):
    began=time.monotonic();deadline=began+timeout;next_progress=began
    waiting=False
    while True:
        snapshot=application_snapshot(bridge,symbols)
        if snapshot['application_matched']:
            if waiting and progress:progress(f"PS 初始化完成：已计算 {snapshot['geometry_count']} 个路径采样点。")
            return snapshot
        if snapshot['actual_magic']=='0x57465231' and snapshot.get('gripper_interface_matched') is False:
            raise RuntimeError('Running PS does not match this arm+gripper console; use the paired ELF. No DDR writes performed.')
        # compute_main publishes the application report only after geometry
        # computation. A zero report while geometry advances is startup, not
        # evidence of an ELF mismatch. Never write heartbeat/stop/GO here.
        if snapshot['actual_magic'] not in ('0x00000000','0x57465231') or (
            snapshot['actual_magic']=='0x57465231' and snapshot['version'] not in (0,1)):
            raise RuntimeError('PS startup check failed; no DDR writes performed: '+json.dumps(snapshot))
        current=time.monotonic()
        if current>=deadline:
            raise RuntimeError('PS initialization wait timed out; no DDR writes performed. Keep CPU running and use --diagnose to inspect progress: '+json.dumps(snapshot))
        waiting=True
        if current>=next_progress and progress:
            progress(f"等待 PS 初始化：路径已计算 {snapshot['geometry_count']} 个点，complete={snapshot['geometry_complete']}，已等待 {current-began:.0f}s。保持 CPU 运行。")
            next_progress=current+5
        time.sleep(min(.5,max(0,deadline-current)))

def clear_idle_stop(bridge,symbols,snapshot):
    # Explicit operator cleanup of the old console's startup-failure write.
    # No automatic clearing, no active/calibrated/fault-state recovery.
    if not snapshot['application_matched'] or snapshot['state_number']!=0 or snapshot['active_mask'] or snapshot['calibrated_mask'] or snapshot['initial_saved'] or snapshot['request_go']:
        raise RuntimeError('Idle-stop cleanup requires matched OFF state, no active/calibrated axes and GO=0; nothing written')
    if snapshot['stop_flag'] not in (0,1):raise RuntimeError('Unexpected stop flag; nothing written')
    if snapshot['stop_flag']:
        bridge.write(int(symbols['g_arm_stop']['address'],0),bytes(4))
        if struct.unpack('<I',bridge.read(int(symbols['g_arm_stop']['address'],0),1))[0]:raise RuntimeError('Stop flag did not clear')

def reconnect_confirmed_disabled(bridge,symbols):
    # Explicit CLI option only. QUIT in inactive CONFIGURED leaves the DDR
    # stop flag set without entering FAULT. Clear only that flag, never reset
    # PS/PL, restore a record, send CAN, or clear a fault state.
    snapshot=application_snapshot(bridge,symbols)
    busy=struct.unpack('<4I',bridge.read(int(symbols['g_arm_reply']['address'],0),4))[3]
    if (not snapshot['application_matched'] or snapshot['state_number']!=1 or
            snapshot['active_mask'] or not snapshot['stop_confirmed'] or
            snapshot['error'] or snapshot['fault_cause'] or snapshot['request_go'] or busy or
            snapshot['stop_flag'] not in (0,1)):
        raise RuntimeError('Disabled reconnect requires matched CONFIGURED, confirmed stop, no active axes/error/pending request; nothing written')
    if snapshot['stop_flag']:
        bridge.write(int(symbols['g_arm_stop']['address'],0),bytes(4))
        if bridge.read(int(symbols['g_arm_stop']['address'],0),1)!=bytes(4):
            raise RuntimeError('Disabled reconnect stop flag did not clear')

class Worker:
    def __init__(self,xsct,symbols,startup_timeout=600,reconnect_disabled=False):
        self.jobs=queue.Queue();self.ready=concurrent.futures.Future();self.error=None;self.stopping=False;self.symbols=symbols
        def run():
            bridge=None;application_verified=False
            try:
                bridge=Bridge(xsct);snapshot=wait_for_application(bridge,symbols,timeout=startup_timeout)
                if reconnect_disabled:
                    reconnect_confirmed_disabled(bridge,symbols)
                    snapshot=application_snapshot(bridge,symbols)
                if snapshot['stop_flag'] and snapshot['state_number']!=226:
                    raise RuntimeError('PS stop flag is set; no writes performed. Run --diagnose. If the application is OFF with no calibration or active axes, --clear-idle-stop explicitly clears only this DDR startup flag.')
                application_verified=True
                self.ready.set_result(True);heartbeat=0;next_beat=0
                while not self.stopping:
                    if time.monotonic()>=next_beat:
                        heartbeat=(heartbeat+1)&0xffffffff;bridge.write(self.addr('g_arm_heartbeat'),struct.pack('<I',heartbeat));next_beat=time.monotonic()+.15
                    try:method,arguments,future=self.jobs.get(timeout=.03)
                    except queue.Empty:continue
                    try:future.set_result(getattr(bridge,method)(*arguments))
                    except Exception as error:future.set_exception(error);raise
            except Exception as error:
                self.error=error
                if not self.ready.done():self.ready.set_exception(error)
                # Best effort only. The independent PL lease remains necessary.
                if bridge and application_verified:
                    try:bridge.write(self.addr('g_arm_stop'),struct.pack('<I',1))
                    except Exception:pass
            finally:
                if bridge:
                    bridge.close()
        self.thread=threading.Thread(target=run,daemon=True);self.thread.start();self.ready.result(timeout=startup_timeout+60)
    def addr(self,name):return int(self.symbols[name]['address'],0)
    def call(self,method,*arguments):
        if self.error:raise RuntimeError(f'Bridge failed: {self.error}')
        future=concurrent.futures.Future();self.jobs.put((method,arguments,future));return future.result(timeout=3)
    def read(self,name,count):return self.call('read',self.addr(name),count)
    def write_word(self,name,value):self.call('write',self.addr(name),struct.pack('<I',value))
    def request(self,data):
        address=self.addr('g_arm_request');self.call('write',address+4,bytes(4))
        # GO is written last; CRC covers the final nonzero GO image.
        pending=bytearray(data);pending[4:8]=bytes(4)
        for start in range(0,len(pending),64):self.call('write',address+start,bytes(pending[start:start+64]))
        self.call('write',address+4,data[4:8])
    def stop(self):self.write_word('g_arm_stop',1)

def submit_request(worker,sequence,operation,config=None,record=None,axis=0,reference=0,timeout=30):
    worker.request(make_request(sequence,operation,axis,reference,config,record))
    deadline=time.monotonic()+timeout;next_progress=time.monotonic()+5
    while True:
        reply=struct.unpack('<4I',worker.read('g_arm_reply',4))
        if reply[0]==sequence:return reply
        if time.monotonic()>deadline:worker.stop();raise TimeoutError('Request timed out; no retry')
        if operation==105 and time.monotonic()>=next_progress:
            geometry=struct.unpack('<5I',worker.read('g_approved_path_geometry',5))
            print(f'PREVIEW: {geometry[3]} samples, complete={geometry[2]}',flush=True);next_progress=time.monotonic()+5
        time.sleep(.05)


def gripper_step_payload(worker,sequence,parameters):
    if len(parameters)!=1:raise ValueError('Step commands take no parameters; one command = 10 us')
    reply=submit_request(worker,sequence,111,record=gripper_payload(['STATUS']))
    info=gripper_report(worker.read('g_gripper_report',13))
    if reply!=(sequence,0,111,0) or info['sequence']!=sequence:
        raise ValueError('Fresh gripper status failed; no step sent')
    return gripper_payload(parameters,info)


def capture_to_file(worker,sequence,path,backup_folder):
    reply=submit_request(worker,sequence,102)
    if reply[1]:raise ValueError(f'Capture failed, result={reply[1]}; no hold request sent')
    data=worker.read('g_initial_pose',29)
    return save_captured_pose(data,sequence,path,backup_folder)

def save_captured_pose(data,sequence,path,backup_folder):
    info=pose_info(data)
    save_pose(Path(backup_folder)/f"initial_pose_gen_{info['generation']}.json",data)
    if Path(path).exists():
        old=Path(path).read_bytes()
        previous=Path(backup_folder)/f"previous_initial_pose_{sequence}.json"
        previous.write_bytes(old)
    save_pose(path,data)
    if load_pose(path)!=data:raise ValueError('Saved initial pose did not verify; no hold request sent')
    return data

def capture_home_to_file(worker,sequence,path,backup_folder):
    # RECOVER preserves valid calibration and enters CONFIGURED. The deployed
    # ELF's raw-pose capture only accepts OFF/REFERENCE_SAVED; use its existing
    # read-only operation here without editing PS state or its raw-pose buffer.
    before=worker.read('g_arm_report',30)
    state=struct.unpack_from('<12I',before)
    if state[:2]!=(0x57465231,1):raise ValueError('Unexpected PS report; HOME not captured')
    if state[2]!=1:return capture_to_file(worker,sequence,path,backup_folder)
    def disabled(report):
        h=struct.unpack_from('<12I',report)
        return h[:2]==(0x57465231,1) and h[2:5]==(1,0,0)
    if not disabled(before) or worker.read('g_arm_stop',1)!=bytes(4):
        raise ValueError('CONFIGHOME requires disabled standby with no pending STOP; nothing sent')
    reply=submit_request(worker,sequence,OPS['READ'])
    if reply!=(sequence,0,OPS['READ'],0):
        raise ValueError(f'Fresh HOME read failed, result={reply[1]}; no configuration or hold sent')
    readback=worker.read('g_arm_readback',36)
    after=worker.read('g_arm_report',30)
    if not disabled(after) or worker.read('g_arm_stop',1)!=bytes(4):
        raise ValueError('PS left disabled standby during HOME read; no configuration or hold sent')
    data=pose_from_readback(readback,sequence)
    evidence={'source':'fresh_WF_READ_in_CONFIGURED','request':sequence,'reply':reply,
              'before_report_hex':before.hex(),'after_report_hex':after.hex(),
              'readback_hex':readback.hex(),'pose_sha256':hashlib.sha256(data).hexdigest(),
              'PS_raw_reference_written':False,'enable_requested':False}
    with (Path(backup_folder)/'home_capture_reads.jsonl').open('a',encoding='utf-8') as log:
        log.write(json.dumps(evidence)+'\n')
    saved=save_captured_pose(data,sequence,path,backup_folder)
    print('已在失能待命状态完成六轴只读采集；接下来仅更新 HOME 配置，不使能。')
    return saved
def require_id2_positive_record(data):
    record_info(data)
    gains=tuple(struct.unpack_from('<f',data,68+a*52)[0] for a in range(6))
    if gains!=ID2_POSITIVE_CANDIDATE:
        raise ValueError('ID2 positive candidate requires NEW CONFIGHOME/BEGIN/CAL/SAVEINITIAL; old-direction calibration cannot enable or move in this console')

def main():
    parser=argparse.ArgumentParser();modes=parser.add_mutually_exclusive_group()
    modes.add_argument('--connect',action='store_true');modes.add_argument('--diagnose',action='store_true');modes.add_argument('--clear-idle-stop',action='store_true')
    parser.add_argument('--xsct',default='D:/Xilinx/Vitis/2023.1/bin/xsct.bat')
    parser.add_argument('--startup-timeout',type=int,default=600,help='PS initialization wait in seconds (1..1800), default 600; no hardware writes while waiting')
    parser.add_argument('--id2-positive',action='store_true',help='Explicit photo-supported mapping candidate: CONFIGHOME uses ID2 gain +1 and recomputes zero/ranges; old-direction records cannot enable or move')
    parser.add_argument('--reconnect-disabled',action='store_true',help='Explicitly reconnect after QUIT only in CONFIGURED with confirmed stop and all axes disabled; clear only the DDR stop flag, no CAN or enable')
    args=parser.parse_args()
    if args.reconnect_disabled and not args.connect:parser.error('--reconnect-disabled requires --connect')
    if not 1<=args.startup_timeout<=1800:parser.error('--startup-timeout must be 1..1800 seconds')
    if not (args.connect or args.diagnose or args.clear_idle_stop):print(HELP);print('OFFLINE HELP ONLY. No hardware connection.');return
    layout=json.loads((ROOT/'reports/workflow_symbols.json').read_text())
    if hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest()!=layout['ELF_sha256']:raise RuntimeError('ELF/symbol pairing mismatch')
    if args.diagnose or args.clear_idle_stop:
        bridge=Bridge(args.xsct)
        try:
            snapshot=application_snapshot(bridge,layout)
            if args.clear_idle_stop:
                clear_idle_stop(bridge,layout,snapshot)
                snapshot=application_snapshot(bridge,layout)
            print(json.dumps(snapshot,indent=2))
            if args.diagnose and snapshot['application_matched'] and 'g_arm_timing' in layout:
                print(json.dumps({'timing':timing_details(bridge.read(int(layout['g_arm_timing']['address'],0),16))},indent=2))
            if args.diagnose and snapshot['application_matched'] and snapshot['state_number']==226:
                print(json.dumps({'fault_detail':fault_details(bridge,layout)},indent=2))
            print('DDR read-only diagnosis; no heartbeat/GO/stop/CAN writes.' if args.diagnose else 'Explicit OFF-state stop-flag cleanup only; no CAN commands or motor enable.')
        finally:bridge.close()
        return
    print(HELP)
    if args.id2_positive:print('ID2 正向候选模式：CONFIGHOME 使用 gain=[-1,+1,-1,-1,-1,+1]；需新捕获 HOME 并完成 CAL。旧方向标定不能用于使能或运动。候选尚待实物复核。')
    worker=Worker(args.xsct,layout,args.startup_timeout,True) if args.reconnect_disabled else Worker(args.xsct,layout,args.startup_timeout)
    sequence=struct.unpack('<I',worker.read('g_arm_reply',1))[0]
    folder=ROOT/'operator_logs'/time.strftime('%Y%m%d_%H%M%S');folder.mkdir(parents=True,exist_ok=True)
    def backup(path=None):
        data=worker.read('g_arm_calibration',117);info=record_info(data)
        save_record(folder/f"calibration_gen_{info['generation']}.json",data)
        save_record(path or folder/'calibration_latest.json',data)
        return info
    try:
        while True:
            try:
                line=input('ARM> ').strip();parts=shlex.split(line,posix=False)
                if not parts:continue
                op=parts[0].upper();parameters=[part.strip('"') for part in parts[1:]]
                if op in ('HELP','?'):print(HELP);continue
                if op=='PATHINFO':
                    if parameters:raise ValueError('PATHINFO takes no arguments')
                    print(describe_cycle());continue
                if op=='RUNPATH':
                    if parameters:raise ValueError('RUNPATH takes no arguments')
                    require_id2_positive_record(worker.read('g_arm_calibration',117))
                    cycle_module=importlib.reload(recorded_cycle_module)
                    runner=cycle_module.RecordedCycleRunner(worker,submit_request,sequence,folder)
                    try:
                        runner.run()
                    except cycle_module.CyclePaused as error:
                        print('路径已取消后续步骤，保留 PAUSED_HOLD：',error)
                    except cycle_module.CyclePlanRejected as error:
                        print('路径准备未通过，已取消剩余步骤；原保持目标未变，保留电机力矩，未发送 STOP：',error)
                        print('请保持控制台开启，输入 STATUS 查看状态；不要直接重跑。详细原因已记录到 recorded_cycle.jsonl。')
                    except KeyboardInterrupt:
                        print('路径已取消并请求 STOP；请承托机械臂，输入 STATUS 核对。')
                    except (ValueError,RuntimeError,TimeoutError,queue.Empty,OSError,struct.error) as error:
                        print('路径未完成：',error)
                        print('已请求 STOP；请承托并查看 STATUS。' if runner.started else '前置条件不满足，未启动路径或夹爪动作。')
                    finally:
                        sequence=runner.sequence
                    continue
                if args.id2_positive and op in ('BEGIN','CAL','SAVEINITIAL','RESUME','CHECKPOSE','MOVETO','GOHOME','PICK','DELIVER','RETURN'):
                    require_id2_positive_record(worker.read('g_arm_calibration',117))
                if op=='GRIP':
                    if parameters and parameters[0].upper() in STEP_COMMANDS:
                        sequence+=1
                        payload=gripper_step_payload(worker,sequence,parameters)
                    else:
                        payload=gripper_payload(parameters)
                    sequence+=1;reply=submit_request(worker,sequence,111,record=payload)
                    info=gripper_report(worker.read('g_gripper_report',13))
                    if info['sequence']!=sequence:raise RuntimeError('Gripper reply sequence mismatch')
                    print(info)
                    with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'parameters':parameters,'reply':reply,'gripper':info})+'\n')
                    continue
                if op=='STATUS':
                    data=worker.read('g_arm_report',30);integers=struct.unpack_from('<12I',data)
                    status={'state':STATES.get(integers[2],integers[2]),'error':integers[3],'fault_cause':integers[11],
                           'stop_confirmed':bool(integers[10]),
                           'enabled_mask':hex(integers[4]),'calibrated_mask':hex(integers[5]),'model_initial_saved':bool(integers[6]),
                           'raw_reference_saved':integers[2] in (9,10),
                           'frames':f'{integers[7]}/{integers[8]}','motor_rad':struct.unpack_from('<6f',data,48)}
                    status['velocity_rad_s']=struct.unpack_from('<6f',data,72)
                    status['target_motor_rad']=struct.unpack_from('<6f',data,96)
                    if integers[2] in (13,226):
                        status['saved_velocity_rad_s']=struct.unpack_from('<6f',data,72)
                        status['last_commanded_motor_rad']=struct.unpack_from('<6f',data,96)
                        status['saved_position_minus_target_rad']=tuple(p-t for p,t in zip(status['motor_rad'],status['last_commanded_motor_rad']))
                    if integers[2]==13:status['pause_reason']='dispatch_late_holding_last_verified_target'
                    print(status)
                    saved_timing=timing_details(worker.read('g_arm_timing',16)) if 'g_arm_timing' in layout else None
                    if saved_timing:print({'timing':saved_timing})
                    saved_trace=None
                    if integers[2]==226 or integers[10]:
                        trace=struct.unpack('<28I',worker.read('g_arm_stop_trace',28))
                        if trace[0]==0x53545031:
                            saved_trace={'elapsed_ms':trace[2],'ack_mask':hex(trace[3]),
                                  'before_count':trace[4:10],'last_count':trace[10:16],
                                  'last_status':[f'0x{x:08X}' for x in trace[16:22]],
                                  'velocity_raw':trace[22:28]}
                            print({'stop_trace':saved_trace})
                    if integers[2] in (13,226):
                        path=folder/('pause_snapshots.jsonl' if integers[2]==13 else 'fault_snapshots.jsonl')
                        try:
                            with path.open('a',encoding='utf-8') as log:log.write(json.dumps({'time':time.strftime('%Y-%m-%dT%H:%M:%S'),'status':status,'stop_trace':saved_trace,'timing':saved_timing,'scope':'Saved DDR observations; not fresh motor readings. Later axes may retain the preceding scan.'})+'\n')
                            print('故障快照已保存：',path)
                        except OSError as error:print('故障快照保存失败，请保留上面的完整输出：',error)
                    continue
                if op=='EXPORT':print(backup(parameters[0] if parameters else None));continue
                if op=='RECOVER':
                    if parameters:raise ValueError('RECOVER takes no arguments')
                    data=worker.read('g_arm_report',30)
                    if struct.unpack_from('<I',data,8)[0]!=226:raise ValueError('RECOVER requires FAULT_LOCKED; nothing sent')
                    evidence={'time':time.strftime('%Y-%m-%dT%H:%M:%S'),'report_hex':data.hex(),
                              'stop_trace_hex':worker.read('g_arm_stop_trace',28).hex(),
                              'calibration_hex':worker.read('g_arm_calibration',117).hex()}
                    if 'g_arm_timing' in layout:evidence['timing']=timing_details(worker.read('g_arm_timing',16))
                    with (folder/'before_recovery.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps(evidence)+'\n')
                    sequence+=1;reply=submit_request(worker,sequence,OPS[op])
                    with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'reply':reply})+'\n')
                    print({'request':sequence,'result':reply[1],'recovered':reply[1]==0,'enable_requested':False})
                    if reply[1]==0:
                        if args.id2_positive:print('已恢复失能待命。首次切换方向请执行新的 CONFIGHOME/BEGIN/CAL/SAVEINITIAL，不能 RESUME 旧方向记录。')
                        else:print('已恢复失能待命。STATUS 中标定仍有效时，可用 RESUME 保持当前位置，再下新的 MOVETO/GOHOME；不会继续旧轨迹。')
                    else:print('恢复未通过；保持承托，查看 STATUS。没有请求使能或运动。')
                    continue
                if op=='CONFIGHOME':
                    if len(parameters)>1:raise ValueError('CONFIGHOME accepts one optional pose-file path')
                    path=Path(parameters[0]) if parameters else ROOT/'config/home_current.json'
                    sequence+=1;data=capture_home_to_file(worker,sequence,path,folder)
                    config=prepare_for_home_calibration(data, ID2_POSITIVE_CANDIDATE if args.id2_positive else SIGN)
                    config['mapping_profile']='ID2_POSITIVE_PHOTO_CANDIDATE' if args.id2_positive else 'RA8P1_ORIGINAL_SIGNS'
                    config_path=path.with_name(path.stem+'.machine.json')
                    temporary=config_path.with_name(config_path.name+'.tmp')
                    temporary.write_text(json.dumps(config,indent=2)+'\n',encoding='utf-8');temporary.replace(config_path)
                    sequence+=1;reply=submit_request(worker,sequence,100,config=config)
                    print({'request':sequence,'result':reply[1],'configured':reply[1]==0,'enabled':False,'pose_file':str(path),'config_file':str(config_path),'motor_gain':[a['gain'] for a in config['axis']]})
                    with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'file':str(path),'config_file':str(config_path),'reply':reply})+'\n')
                    if reply[1]==0:print('已用新读位置准备 HOME 标定配置，尚未使能。仅当实物已摆到所选 URDF HOME 时继续 BEGIN/CAL。')
                    continue
                if op in ('HOLDINITIAL','SAVEPOSE','HOLDPOSE'):
                    path=Path(parameters[0]) if parameters else ROOT/'config/initial_pose.json'
                    if op=='HOLDPOSE':
                        if not parameters:raise ValueError('HOLDPOSE requires an initial-reference file')
                        data=load_pose(path);sequence+=1;reply=submit_request(worker,sequence,104,record=data.ljust(468,b'\0'))
                        if reply[1]:raise ValueError(f'Reference restore rejected: {reply[1]}; no enable requested')
                    else:
                        sequence+=1;data=capture_to_file(worker,sequence,path,folder)
                        print('初始位置已保存并校验：',path)
                    if op!='SAVEPOSE':
                        print('请求六轴当前位置保持：PP速度0.1 rad/s，加速度0.1 rad/s2；不回零，不执行路径。')
                        sequence+=1;reply=submit_request(worker,sequence,103,record=data.ljust(468,b'\0'))
                        print({'request':sequence,'result':reply[1],'holding_requested':reply[1]==0})
                        with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'file':str(path),'reply':reply})+'\n')
                    continue
                if op in ('STOP','QUIT'):worker.stop();print('Stop requested; confirm stopped status and support the arm.');
                if op=='QUIT':break
                if op=='STOP':continue
                if op in ('CHECKPOSE','MOVETO'):
                    payload=cartesian_payload(parameters)
                    sequence+=1
                    if op=='MOVETO':print('请求移动到 URDF 底座坐标目标，使用关节空间插补；不是末端直线运动。')
                    reply=submit_request(worker,sequence,OPS[op],record=payload,timeout=600 if op=='CHECKPOSE' else 30)
                    info=cartesian_report(worker.read('g_arm_cartesian',36))
                    if info['sequence']!=sequence:raise RuntimeError('Cartesian reply sequence mismatch')
                    print(info)
                    if info['plan_valid']:print('duration_ms 是规划采样时间；每组目标确认后等待 50 ms 再发下一组，实际运行另加通信核验耗时；总时限仍为 55 秒。')
                    if info['result']==0 and info['model_only']:print('仅模型解算：种子为 URDF HOME；未建立实机标定，未发送运动命令。')
                    with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'parameters':parameters,'reply':reply,'cartesian':info})+'\n')
                    continue
                if op not in OPS:raise ValueError('Unknown operation; use HELP')
                if op in ('GOHOME','RESUME') and parameters:raise ValueError(op+' takes no arguments')
                if op=='RESUME':print('请求使用已保留的标定使能六轴、保持当前姿态；不会返回 HOME 或续跑旧轨迹。')
                config=json.loads(Path(parameters[0]).read_text(encoding='utf-8-sig')) if op=='CONFIG' else None
                record=load_record(parameters[0]) if op=='RESTORE' else None
                if args.id2_positive:
                    if config is not None and tuple(a['gain'] for a in config['axis'])!=ID2_POSITIVE_CANDIDATE:
                        raise ValueError('CONFIG direction profile does not match --id2-positive; use fresh CONFIGHOME')
                    if record is not None:require_id2_positive_record(record)
                axis=int(parameters[0]) if op=='CAL' else 0;reference=float(parameters[1]) if op=='CAL' else 0
                sequence+=1
                reply=submit_request(worker,sequence,OPS[op],config,record,axis,reference,600 if op=='PREVIEW' else 30)
                with (folder/'requests.jsonl').open('a',encoding='utf-8') as log:log.write(json.dumps({'request':sequence,'operation':op,'reply':reply})+'\n')
                print({'request':sequence,'result':reply[1],'accepted':reply[1]==0})
                if reply[1]==0 and op=='READ':
                    data=worker.read('g_arm_readback',36)
                    for a in range(6):print(struct.unpack_from('<4I2f',data,a*24))
                if reply[1]==0 and op in ('CAL','SAVEINITIAL','RESTORE'):print('PC backup:',backup())
            except (ValueError,IndexError,KeyError) as error:print('INPUT REJECTED:',error)
    finally:
        try:worker.stop()
        except Exception:pass
        worker.stopping=True;worker.thread.join(timeout=3)
if __name__=='__main__':
    try:main()
    except (KeyboardInterrupt,EOFError):
        print('\n控制台已中断退出，退出时已尝试请求 STOP；可能解除保持力矩，请承托机械臂。重连请用菜单 5，先 STATUS 核对，不要直接重跑。')
    except (RuntimeError,TimeoutError,queue.Empty,OSError,struct.error) as error:
        print('CONTROL_ERROR:',error);raise SystemExit(1)
