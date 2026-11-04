"""One explicit recorded pick/delivery cycle. Importing never accesses hardware."""
from dataclasses import dataclass

@dataclass(frozen=True)
class Waypoint:
    request: int | None
    pose: tuple

APPROACH = (
    Waypoint(None, (180.0, 0.0, 190.0, 0.0, -10.0, 0.0)),
    Waypoint(54, (180.0, 0.0, 160.0, 0.0, 0.0, 0.0)),
)
TRANSFER = (
    Waypoint(53, (180.0, 0.0, 170.0, 0.0, 0.0, 0.0)),
    Waypoint(155, (180.0, -150.0, 170.0, -60.0, -90.0, 0.0)),
)
RETURN = (
    Waypoint(None, (180.0, -150.0, 200.0, -60.0, -90.0, 0.0)),
)

OPEN_US = 1110
CLOSED_US = 1490
PICK_WAIT_S = 5.0
DELIVERY_WAIT_S = 3.0
RELEASE_WAIT_S = 2.0

import hashlib
import json
import math
import struct
import time
from pathlib import Path
from workflow_protocol import cartesian_payload, cartesian_report, record_info
from gripper_protocol import gripper_payload, gripper_report

class CycleError(ValueError):
    pass

class CyclePaused(CycleError):
    pass

class CyclePlanRejected(CycleError):
    """A non-executed plan was rejected while verified holding stayed intact."""
    pass

def describe_cycle():
    lines=['RUNPATH: execute ONE cycle from the saved, calibrated HOME.',
           'Gripper: open 1110 us -> pickup arrived +5 s -> close 1490 us;',
           'delivery arrived +3 s -> open 1110 us -> pulse reached +2 s -> return HOME.',
           'Route v3: 6 motion segments; approach 30 mm higher at Pitch=-10 deg, descend to pickup at Pitch=0 deg.',
           'Wait 5 s AFTER descent/arrival, then close. Quintic joint interpolation, stop at each waypoint.',
           'Fixed dwell deadlines; arrival jitter never resets the timer. Safety monitoring stays active.',
           'Wait for verified arm completion and PWM ramp completion at every stage.',
           'Preview first; rejected plans cancel the cycle and preserve verified settled hold.',
           'Transient result=6 waits/rechecks within 5 s, at most 3 requests; accepted motion is never replayed.',
           'During RUNPATH press Ctrl+C to cancel and request STOP.']
    for phase,points in [('HOME -> PICK',APPROACH),('PICK -> DELIVERY',TRANSFER),('DELIVERY -> HOME',RETURN)]:
        lines.append(phase)
        lines.extend('  '+' '.join(f'{v:g}' for v in point.pose)+(f'  (record #{point.request})' if point.request is not None else '  (generated lift; offline validated)') for point in points)
    lines.append('  GOHOME (the current session SAVEINITIAL pose)')
    return '\n'.join(lines)

class RecordedCycleRunner:
    """Foreground sequence; the existing Worker independently maintains heartbeat.

    No saved motor position is loaded into the board. All MOVETO planning uses
    the running PS and the current session's calibrated record. Ctrl+C aborts.
    """
    def __init__(self,worker,submit,sequence,folder,progress=print,clock=time.monotonic,sleep=time.sleep):
        self.worker=worker;self.submit=submit;self.sequence=sequence
        self.folder=Path(folder);self.progress=progress;self.clock=clock;self.sleep=sleep
        self.started=False;self.expected_pulse=None;self.calibration=None;self.events=[]
        self.next_grip_check=0.0
        self.last_arm=None

    def log(self,event,**details):
        row={'event':event,'time_monotonic_s':self.clock(),**details}
        self.events.append(row)
        with (self.folder/'recorded_cycle.jsonl').open('a',encoding='utf-8') as out:
            out.write(json.dumps(row,ensure_ascii=False)+'\n')

    def arm(self,allowed):
        data=self.worker.read('g_arm_report',30)
        h=struct.unpack_from('<12I',data);floats=struct.unpack_from('<18f',data,48)
        self.last_arm={'header':h,'position_rad':floats[:6],'velocity_rad_s':floats[6:12],'target_rad':floats[12:]}
        if h[:2]!=(0x57465231,1):raise CycleError('ARM report mismatch')
        if h[2]==13:raise CyclePaused('PAUSED_HOLD: cycle stopped here; no automatic continuation')
        if h[2]==226 or h[3] or h[11]:raise CycleError(f'ARM fault/error: state={h[2]} error={h[3]} cause={h[11]}')
        if h[2] not in allowed:raise CycleError(f'Unexpected ARM state {h[2]}')
        if h[4:7]!=(63,63,1):raise CycleError('All six axes must be enabled, calibrated, with SAVEINITIAL complete')
        if not all(math.isfinite(x) for x in floats):raise CycleError('Nonfinite ARM feedback')
        if self.worker.read('g_arm_stop',1)!=bytes(4):raise CycleError('STOP is pending')
        if self.calibration is not None and self.worker.read('g_arm_calibration',117)!=self.calibration:
            raise CycleError('Calibration changed during the cycle')
        return h,floats[:6],floats[6:12],floats[12:]

    def settled(self,snapshot):
        _,position,velocity,target=snapshot
        return all(abs(position[a]-target[a])<=self.axes[a][11] and abs(velocity[a])<=self.axes[a][12] for a in range(6))

    def hold_safe(self,snapshot):
        _,position,velocity,target=snapshot
        return all(self.axes[a][5]<=position[a]<=self.axes[a][6] and abs(velocity[a])<=self.axes[a][9] and abs(position[a]-target[a])<=self.axes[a][10] for a in range(6))

    def wait_hold_ready(self,allowed,label,home=None,timeout=5.):
        start=self.clock();deadline=start+timeout;streak=0;before=None
        while True:
            snapshot=self.arm(allowed)
            self.monitor_grip()
            if before is None:before=snapshot
            if snapshot[0][7:9]!=before[0][7:9] or any(abs(x-y)>1e-6 for x,y in zip(snapshot[3],before[3])):
                raise CycleError('Hold target or motion counters changed during readiness check')
            if not self.hold_safe(snapshot):raise CycleError('Feedback exceeds hold safety limits')
            ready=self.settled(snapshot) and (home is None or all(abs(snapshot[1][a]-home[a])<=self.axes[a][11] for a in range(6)))
            streak=streak+1 if ready else 0
            if streak>=3:
                self.log('hold_ready',label=label,elapsed_s=self.clock()-start,arm=self.last_arm)
                return snapshot
            if not ready:
                self.log('hold_not_ready',label=label,arm=self.last_arm,home_motor_rad=home,
                         arrival_position_rad=[a[11] for a in self.axes],arrival_velocity_rad_s=[a[12] for a in self.axes])
            if self.clock()>=deadline:
                raise CycleError(f'{label}: 未连续满足停稳/初始位条件；保持状态未变，详情见 hold_not_ready 日志。')
            self.sleep(.1)

    def preflight(self):
        self.progress('RUNPATH v3：6 段路线；先到 Z=190 mm、Pitch=-10°，下移到 Z=160 mm、Pitch=0°，停稳等 5 秒再闭爪。')
        data=self.worker.read('g_arm_calibration',117);meta=record_info(data)
        if meta['calibrated_mask']!=63 or not meta['initial_valid']:
            raise CycleError('RUNPATH requires complete CAL and SAVEINITIAL')
        self.axes=[struct.unpack_from('<3I10f',data,56+a*52) for a in range(6)]
        if tuple(a[3] for a in self.axes)!=(-1.,1.,-1.,-1.,-1.,1.):
            raise CycleError('RUNPATH requires the current ID2-positive direction profile')
        home_joint=struct.unpack_from('<6f',data,416)
        if any(abs(x-y)>.01 for x,y in zip(home_joint,(0,1.57,0,0,1.57,0))):
            raise CycleError('Saved initial pose is not the recorded URDF HOME')
        self.calibration=data;self.home=struct.unpack_from('<6f',data,440)
        self.progress('确认初始位连续停稳（最多等待 5 秒，不发送运动或夹爪命令）。')
        self.wait_hold_ready({3},'RUNPATH 前置检查',home=self.home)
        self.move_timeout=struct.unpack_from('<I',data,44)[0]/1000+10.0
        self.log('preflight_pass',calibration_sha256=hashlib.sha256(data).hexdigest(),home_motor_rad=self.home)

    def send(self,operation,record=None,allow_rejection=False):
        self.sequence+=1
        reply=self.submit(self.worker,self.sequence,operation,record=record)
        self.log('request',request=self.sequence,operation=operation,reply=reply)
        if len(reply)!=4 or reply[0]!=self.sequence or reply[2:]!=(operation,0):
            raise CycleError(f'Request {self.sequence} reply mismatch: {reply}')
        if reply[1] and not allow_rejection:raise CycleError(f'Request {self.sequence} failed: {reply}')
        return reply

    def plan_request(self,operation,point=None):
        before=self.arm({3,12});self.monitor_grip()
        deadline=self.clock()+5.0
        for attempt in range(1,4):
            before_arm=self.last_arm
            reply=self.send(operation,None if point is None else cartesian_payload(point.pose),allow_rejection=True)
            info=None
            if point is not None:
                info=cartesian_report(self.worker.read('g_arm_cartesian',36))
                self.log('cartesian_reply',operation=operation,source_request=point.request,report=info,arm_before=before_arm)
                if info['sequence']!=self.sequence or info['result']!=reply[1]:
                    raise CycleError('Cartesian reply does not match request result')
            if not reply[1]:return info
            # Retry only an explicitly NOT EXECUTED result=6, after checking
            # the same settled hold. Never replay accepted/uncertain motion.
            if reply[1] in (1,2,3,4,6) and (info is None or not info['plan_valid']):
                after=self.arm({before[0][2]});self.monitor_grip()
                if self.hold_safe(after) and (reply[1]==6 or self.settled(after)) and after[0][7:9]==before[0][7:9] and all(abs(x-y)<=1e-6 for x,y in zip(after[3],before[3])):
                    if reply[1]==6 and attempt<3 and self.clock()<deadline:
                        self.progress('控制器本次未确认停稳；保持原目标，等待连续停稳后再检查（最多 5 秒/3 次，未启动运动）。')
                        self.log('settle_wait_started',operation=operation,attempt=attempt,arm=self.last_arm)
                        streak=0
                        while self.clock()<deadline:
                            self.sleep(.1)
                            snapshot=self.arm({before[0][2]});self.monitor_grip()
                            after=snapshot
                            if not self.hold_safe(snapshot):raise CycleError('Feedback exceeded hold safety limits while waiting for readiness')
                            if snapshot[0][7:9]!=before[0][7:9] or any(abs(x-y)>1e-6 for x,y in zip(snapshot[3],before[3])):
                                raise CycleError('Hold target or motion counters changed while waiting for readiness')
                            streak=streak+1 if self.settled(snapshot) else 0
                            if streak>=3:
                                self.log('settle_wait_ready',operation=operation,attempt=attempt,arm=self.last_arm)
                                break
                        if streak>=3:continue
                    # A healthy hold with unchanged target stays enabled even
                    # if the readiness timeout expires. Do not claim arrival.
                    self.log('plan_rejected_hold',operation=operation,result=reply[1],cartesian=info,arm=self.last_arm,settled=self.settled(after))
                    raise CyclePlanRejected(f'Plan rejected (result={reply[1]}); arm keeps its original hold target. Remaining cycle cancelled; no STOP or further retry.')
            raise CycleError(f'Request {self.sequence} failed: {reply}')

    def grip_status(self):
        self.send(111,gripper_payload(['STATUS']))
        info=gripper_report(self.worker.read('g_gripper_report',13))
        if info['sequence']!=self.sequence or info['result'] or not info['present'] or not info['pwm_enabled'] or info['lease_expired']:
            raise CycleError('Gripper is disabled, expired or has an invalid report')
        if info['target_pulse_us']!=self.expected_pulse:
            raise CycleError('Gripper target changed unexpectedly')
        return info

    def monitor_grip(self):
        if self.expected_pulse is not None and self.clock()>=self.next_grip_check:
            info=self.grip_status();self.next_grip_check=self.clock()+.5
            if info['pulse_ramping'] or info['active_pulse_us']!=self.expected_pulse:
                raise CycleError('Gripper output no longer holds the requested pulse')

    def grip(self,pulse,label):
        before=self.wait_hold_ready({3,12},'夹爪动作前停稳检查');self.progress(label)
        self.expected_pulse=pulse
        self.log('gripper_requested',pulse_us=pulse)
        self.send(111,gripper_payload(['US',str(pulse)]))
        deadline=self.clock()+10.0
        streak=0
        while True:
            snapshot=self.arm({3,12})
            if not self.hold_safe(snapshot) or snapshot[0][7:9]!=before[0][7:9] or any(abs(x-y)>1e-6 for x,y in zip(snapshot[3],before[3])):
                raise CycleError('Arm exceeded safety limits or target changed during gripper operation')
            streak=streak+1 if self.settled(snapshot) else 0
            info=self.grip_status()
            if not info['pulse_ramping'] and info['active_pulse_us']==pulse and streak>=3:break
            if self.clock()>=deadline:raise CycleError('Gripper PWM ramp timed out')
            self.sleep(.1)
        self.next_grip_check=0.0
        self.log('gripper_pulse_reached',pulse_us=pulse,mechanical_feedback=False)

    def move(self,point,phase):
        self.progress(f'{phase}: '+ ' '.join(f'{v:g}' for v in point.pose))
        info=self.plan_request(107,point)
        if info['sequence']!=self.sequence or info['result'] or info['model_only'] or not info['plan_valid'] or not 0<info['frames']<=2048:
            raise CycleError('MOVETO did not produce a live accepted plan')
        if any(abs(x-y)>1e-3 for x,y in zip(info['xyz_mm']+info['rpy_deg'],point.pose)):
            raise CycleError('Accepted pose does not match requested waypoint')
        self.log('move_accepted',phase=phase,source_request=point.request,pose=point.pose,plan=info)
        self.wait_move(12,info['frames'],info['target_motor_rad'])
        self.log('waypoint_arrived',phase=phase,source_request=point.request,pose=point.pose)

    def wait_move(self,final_state,frames=None,target=None):
        deadline=self.clock()+self.move_timeout
        streak=0
        while True:
            snapshot=self.arm({11,final_state});h=snapshot[0]
            self.monitor_grip()
            if h[2]==final_state and h[7]==h[8] and h[8]>0 and (frames is None or h[8]==frames) and self.settled(snapshot):
                if target is not None and any(abs(x-y)>1e-4 for x,y in zip(snapshot[3],target)):
                    raise CycleError('Final arm target differs from accepted plan')
                streak+=1
                if streak>=3:return
            else:streak=0
            if self.clock()>=deadline:raise CycleError('Arm arrival timed out')
            self.sleep(.1)

    def dwell(self,seconds,label):
        before=self.wait_hold_ready({3,12},'等待计时前停稳检查')
        self.progress(label);start=self.clock();deadline=start+seconds;last_countdown=None;jitter_samples=0
        self.log('dwell_started',seconds=seconds,label=label,deadline_monotonic_s=deadline)
        while True:
            snapshot=self.arm({3,12})
            if not self.hold_safe(snapshot) or snapshot[0][7:9]!=before[0][7:9] or any(abs(x-y)>1e-6 for x,y in zip(snapshot[3],before[3])):
                raise CycleError('Arm exceeded safety limits or target changed during dwell')
            # Arrival already passed the consecutive-sample check. Small holding
            # velocity fluctuations must not starve the operator's timed dwell.
            # Actual safety violations still abort above; grip() checks readiness
            # again before any output change, with a bounded timeout.
            if not self.settled(snapshot):jitter_samples+=1
            self.monitor_grip()
            remaining=deadline-self.clock()
            if remaining<=0:break
            countdown=math.ceil(remaining)
            if countdown!=last_countdown:
                self.progress(f'等待剩余 {countdown} 秒。');last_countdown=countdown
            self.sleep(min(.1,remaining))
        self.log('dwell_finished',seconds=seconds,label=label,elapsed_s=self.clock()-start,jitter_samples=jitter_samples)

    def run(self):
        try:self.preflight()  # Rejection here sends no enable, grip or motion command.
        except KeyboardInterrupt:
            self.worker.stop();raise
        self.started=True;self.log('cycle_started')
        try:
            self.progress('先检查首段规划，尚不打开夹爪或移动机械臂。')
            info=self.plan_request(106,APPROACH[0])
            if info['model_only'] or not info['plan_valid'] or not 0<info['frames']<=2048 or any(abs(x-y)>1e-3 for x,y in zip(info['xyz_mm']+info['rpy_deg'],APPROACH[0].pose)):
                raise CycleError('First segment preview did not produce a live valid plan')
            self.grip(OPEN_US,'夹爪打开到 1110 us，完成后出发。')
            for point,phase in zip(APPROACH,('前往拾取准备位（抬高 30 mm）','下移到拾取点')):self.move(point,phase)
            self.dwell(PICK_WAIT_S,'拾取点已到位，等待 5 秒。')
            self.grip(CLOSED_US,'夹爪闭合到 1490 us，等待 PWM 渐变完成。')
            for point in TRANSFER:self.move(point,'前往递送')
            self.dwell(DELIVERY_WAIT_S,'递送点已到位，等待 3 秒。')
            self.grip(OPEN_US,'夹爪打开到 1110 us，等待 PWM 渐变完成。')
            self.dwell(RELEASE_WAIT_S,'已完成打开指令，再等待 2 秒。')
            for point in RETURN:self.move(point,'返回初始位置')
            self.arm({12});self.plan_request(108)
            self.wait_move(3,target=self.home)
            self.log('cycle_completed',final_state='INITIAL_HOLD',gripper_pulse_us=OPEN_US)
            self.progress('一次路径已完成：回到初始点，夹爪保持完全打开；不自动重复。')
        except CyclePaused:
            self.log('cycle_paused',auto_resume=False)
            raise
        except CyclePlanRejected:
            self.log('cycle_rejected_hold',auto_resume=False,stop_requested=False,arm=self.last_arm)
            raise
        except BaseException as error:
            stop_error=None
            try:self.worker.stop()
            except Exception as failure:stop_error=str(failure)
            try:self.log('cycle_aborted',reason=type(error).__name__+': '+str(error),stop_requested=stop_error is None,stop_error=stop_error,arm=self.last_arm)
            except OSError:pass
            raise

if __name__=='__main__':
    print(describe_cycle())
