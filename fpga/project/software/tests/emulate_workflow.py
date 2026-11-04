"""Actual ARM ELF against a virtual mailbox and ideal tracking plant only.
No hardware/debugger/network. Synthetic calibration below is NOT for real use.
"""
import argparse,csv,hashlib,json,struct,sys,time,zlib
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--deps',type=Path,required=True);args=parser.parse_args();sys.path.insert(0,str(args.deps))
from unicorn import Uc,UC_ARCH_ARM,UC_MODE_ARM,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.arm_const import UC_ARM_REG_CPSR,UC_ARM_REG_SP,UC_ARM_REG_LR,UC_ARM_REG_PC,UC_CPU_ARM_CORTEX_A9
from elftools.elf.elffile import ELFFile
root=Path(__file__).resolve().parents[1];elfpath=root/'build/arm_workflow.elf'
bits=lambda f:struct.unpack('<I',struct.pack('<f',f))[0]
fp=lambda u:struct.unpack('<f',struct.pack('<I',u))[0]
with elfpath.open('rb') as f:
    elf=ELFFile(f);segments=[(s['p_vaddr'],s.data()) for s in elf.iter_segments() if s['p_type']=='PT_LOAD']
    symbols={s.name:(s['st_value'],s['st_size']) for s in elf.get_section_by_name('.symtab').iter_symbols()};entry=elf.header['e_entry']
def new_cpu(snapshot=None):
    u=Uc(UC_ARCH_ARM,UC_MODE_ARM);u.ctl_set_cpu_model(UC_CPU_ARM_CORTEX_A9);u.mem_map(0x100000,0x100000)
    if snapshot:u.mem_write(0x100000,snapshot)
    else:
        for address,data in segments:u.mem_write(address,data)
    u.cpr_write(15,0,1,0,0,1,False,0x08c50078);u.reg_write(UC_ARM_REG_CPSR,0x1d3);u.reg_write(UC_ARM_REG_SP,0x200000)
    return u
def words(u,name):
    address,size=symbols[name];return struct.unpack('<'+'I'*(size//4),bytes(u.mem_read(address,size)))
def run_to_idle(u,start):
    began=time.monotonic();u.emu_start(start,symbols['compute_idle'][0],timeout=55_000_000)
    while u.reg_read(UC_ARM_REG_PC)!=symbols['compute_idle'][0]:
        if time.monotonic()-began>300:raise RuntimeError('Offline CPU timeout')
        print('Actual ARM program still computing offline...',flush=True)
        u.emu_start(u.reg_read(UC_ARM_REG_PC),symbols['compute_idle'][0],timeout=55_000_000)
class Plant:
    def __init__(self,u,scenario):
        self.u=u;self.scenario=scenario;self.reg={0:0x43414e36,4:0x20008,0x20:0,0x24:0,0x28:0x3f0b,0x30:0,0x34:0,0x38:0,0x3c:0,0x40:0,0x44:0,0x48:0,0x4c:0}
        if scenario=='wrong_ABI':self.reg[4]=0x20005
        self.hold=False;self.holdseq=0;self.auto_heartbeat=True;self.last_heartbeat=0;self.ticks=0;self.timer_enabled=False;self.path=False;self.seq=0;self.staged=0;self.enabled=0;self.locked=False;self.ever=False
        self.command_log=[];self.commits=[];self.stop_requests=0;self.enable_count=0;self.query=0;self.first_enable=None;self.verified_time=0
        self.pending_stop_feedback=[];self.stop_race_pending=False;self.recovery_count=0
        self.axes=[{'p':bits(initial[a]),'vel':0,'mode':0,'speed':0,'accel':0,'preload':False,'last':bits(initial[a]),'target':bits(initial[a]),'cached':None,'snapshot':None,'age':0,'count':0} for a in range(6)]
        u.mem_map(0x40000000,0x1000);u.mem_map(0xf8f00000,0x1000)
        u.hook_add(UC_HOOK_MEM_READ,self.read,begin=0x40000000,end=0x40000fff)
        u.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=0x40000000,end=0x40000fff)
        u.hook_add(UC_HOOK_MEM_READ,self.read,begin=0xf8f00200,end=0xf8f00208)
        u.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=0xf8f00200,end=0xf8f00208)
    def ms(self):return self.ticks/333333.
    def put(self,address,value):self.u.mem_write(address,struct.pack('<I',value&0xffffffff))
    def stop(self,emergency=False):
        self.stop_requests+=1;self.enabled=0;self.path=False;self.hold=False;self.staged=0
        for i,a in enumerate(self.axes):
            a['vel']=0
            missing=self.ever and (self.scenario=='stop_unknown' or (self.scenario=='stop_one_missing' and i==3))
            delayed=self.ever and self.scenario in ('stop_delayed_feedback','stop_late_feedback') and i==5
            if delayed:self.pending_stop_feedback.append((self.ms()+(150 if self.scenario=='stop_delayed_feedback' else 350),i))
            elif not missing:a['count']+=1
        if self.ever:
            if self.scenario=='stop_running_feedback':self.enabled=1<<5
            if self.scenario=='stop_feedback_error':self.axes[0]['status_extra']=0x400
            # Raw 32784 is 0.016617 rad/s for RS00, 0.025177 for EL05.
            if self.scenario=='stop_near_zero_rs00':self.axes[1]['feedback_velocity_raw']=32784
            if self.scenario=='stop_fast_el05':self.axes[0]['feedback_velocity_raw']=32784
            if self.scenario=='stop_snapshot_race':self.stop_race_pending=True
        if emergency:self.locked=True
    def read(self,u,access,address,size,value,data):
        if address in (0xf8f00200,0xf8f00204,0xf8f00208):
            if address==0xf8f00200 and self.timer_enabled:self.ticks+=33333
            for due,axis in list(self.pending_stop_feedback):
                if self.ms()>=due:
                    self.axes[axis]['count']+=1;self.pending_stop_feedback.remove((due,axis))
            if self.auto_heartbeat and self.ms()-self.last_heartbeat>=200:
                self.last_heartbeat=self.ms();self.put(symbols['g_arm_heartbeat'][0],int(self.ms())+1)
            if self.enabled and (self.path or self.hold) and (self.ms()-self.verified_time>500 or (self.path and self.ms()-self.first_enable>60000) or any(self.ms()-a['age']>=500 for i,a in enumerate(self.axes) if self.enabled&(1<<i))):
                self.stop(True);self.reg[0x20]=0xe1091a
            self.put(address,(self.ticks>>(32 if address==0xf8f00204 else 0)) if address!=0xf8f00208 else int(self.timer_enabled));return
        offset=address-0x40000000
        if offset==0x2c:
            a=self.query&7;p=(self.query>>8)&31;m=self.axes[a]
            if p==1:v=m['count']
            elif p==0:v=(a+1)|(0x20000 if m['count'] else 0)|(0x200 if self.enabled&(1<<a) else 0)|m.get('status_extra',0)
            elif p==5:
                fullscale=33. if a==1 else 50.
                velocity=max(-fullscale,min(fullscale,fp(m['vel'])))
                v=m.get('feedback_velocity_raw',round((velocity+fullscale)*65535/(2*fullscale)))<<16
                if self.stop_race_pending and a==5:
                    self.stop_race_pending=False;m['count']+=1;self.enabled|=1<<5
            else:v=0
        else:v=self.reg.get(offset,0)
        self.put(address,v)
    def write(self,u,access,address,size,value,data):
        if address in (0xf8f00200,0xf8f00204,0xf8f00208):
            if address==0xf8f00208:self.timer_enabled=bool(value&1)
            elif address==0xf8f00200:self.ticks=(self.ticks&0xffffffff00000000)|value
            else:self.ticks=(self.ticks&0xffffffff)|(value<<32)
            return
        offset=address-0x40000000;self.reg[offset]=value
        if offset==0x50:
            assert value==0x52454331 and self.locked
            assert ((self.reg[0x20]>>16)&255) in (0xe0,0xe1)
            self.recovery_count+=1
            previous=[a['count'] for a in self.axes]
            self.stop(False);self.locked=False;self.reg[0x20]=6
            self.reg[0x3c]+=1;self.reg[0x40]+=1
            if self.scenario=='recover_stale':self.axes[5]['count']=previous[5]
            if self.scenario=='recover_fast':self.axes[5]['vel']=bits(.2)
            if self.scenario=='recover_running':self.enabled=32
            if self.scenario=='recover_stop':self.put(symbols['g_arm_stop'][0],1)
            if self.scenario=='recover_offset':self.axes[4]['offset_bits']=123
            if self.scenario=='recover_tx_fail':self.locked=True;self.reg[0x20]=0xe2091a
            return
        if offset==0x1c:self.query=value
        if offset==8:
            if value==2:self.stop(True);self.reg[0x20]=0xe0091a;return
            assert value==1;self.command()
    def reject(self):
        self.reg[0x44]+=1;self.reg[0x20]=0x2040a
        if self.enabled:self.stop(True);self.reg[0x20]=0xe1091a
    def command(self):
        w=self.reg[0x10];value=self.reg[0x14];a=(w&255)-1;op=(w>>8)&7;index=(w>>11)&65535
        self.command_log.append((w,value));self.ticks+=33333
        if self.locked or not(0<=a<6) or self.reg[0x18]!=0:self.reject();return
        m=self.axes[a];result=0
        if op==0:
            if index==0x7019:m['cached']=m['p'];m['age']=self.ms()
            mapping={0x7005:m['mode'],0x7019:m['p'],0x701b:m['vel'],0x7029:m.get('zero_state',1),0x702b:m.get('offset_bits',0),0x7018:bits(10),0x700b:bits(6)}
            if index not in mapping:self.reject();return
            result=mapping[index]
        elif op==4 and a==0 and index==0 and value==0:self.stop()
        elif op==7 and a==0 and index==2 and value==0x484c4431 and (not self.enabled or self.path):
            self.hold=True;self.path=False;self.holdseq=0;self.verified_time=self.ms()
        elif op==7 and a==0 and index==3 and self.hold and value==self.holdseq+1:
            self.holdseq=value;result=value;self.verified_time=self.ms()
        elif op==7 and a==0 and index==4 and value==0x54524a31 and self.hold and self.enabled==63:
            self.path=True;self.hold=False;self.seq=0;self.staged=0;self.first_enable=self.ms();self.verified_time=self.ms()
        elif op==7 and a==0 and index==0 and value==0x54524a31 and not self.enabled:
            self.path=True;self.seq=0;self.staged=0
            for x in self.axes:x['preload']=False;x['cached']=None
        elif op==2 and index==0x7005 and value==1 and not(self.enabled&(1<<a)):m['mode']=1;result=1
        elif op==1 and not(self.enabled&(1<<a)):
            if index==0x7024 and .1<=fp(value)<=3.2:m['speed']=value
            elif index==0x7025 and .1<=fp(value)<=3.2:m['accel']=value
            elif index==0x7016 and abs(fp(value)-fp(m['p']))<=.001:m['preload']=True;m['last']=value
            else:self.reject();return
            result=value
        elif op==3 and value==0x50505431 and m['mode']==1 and m['speed'] and m['accel'] and m['preload']:
            if not self.enabled:self.first_enable=self.ms();self.verified_time=self.ms()
            self.enabled|=1<<a;self.ever=True;self.enable_count+=1;m['count']+=1
        elif op==5 and index==0x7016 and self.path and not(self.staged&(1<<a)) and m['preload'] and abs(fp(value)-fp(m['last']))<=.1001 and abs(fp(value))<16 and self.ms()-m['age']<500:
            m['target']=value;m['snapshot']=m['cached'];self.staged|=1<<a
        elif op==7 and a==0 and index==1 and self.path and value==self.seq+1 and self.enabled==63 and self.staged==63 and all(x['cached']==x['snapshot'] and self.ms()-x['age']<500 for x in self.axes):
            self.seq=value;self.staged=0;result=value
            for x in self.axes:x['p']=x['target'];x['last']=x['target'];x['vel']=0;x['count']+=1
            self.verified_time=self.ms();self.commits.append([self.ms(),value]+[fp(x['target']) for x in self.axes])
            if value==3:
                if self.scenario=='wrong_sequence_echo':result=value+1
                if self.scenario=='following_error':self.axes[0]['p']=bits(fp(self.axes[0]['p'])+.2)
                if self.scenario=='late_commit':self.ticks+=333333*200
        else:self.reject();return
        self.reg[0x3c]+=1;self.reg[0x40]+=1;self.reg[0x24]=result;self.reg[0x20]=6;self.reg[0x34]+=1


boot=new_cpu();run_to_idle(boot,entry)
assert words(boot,'g_arm_report')[:7]==(0x57465231,1,0,0,0,0,0)
assert words(boot,'g_approved_path_geometry')[:5]==(0x50494331,1,0,0,0)
snapshot=bytes(boot.mem_read(0x100000,0x100000))
reference=[0,1.57,0,0,1.57,0]
gains=[-1,-1,-1,-1,-1,1];zero=[.01,1.57,0,.02,1.57,-.03]
initial=[zero[a]+gains[a]*reference[a] for a in range(6)]
def config(valid=True,rates=(1,2)):
 data=struct.pack('<6I2f',0,0x53544f31 if valid else 0,50,50,500,55000,.001,.5)
 for a in range(6):data+=struct.pack('<3I10f',a+1,1,0,gains[a],0,-6,6,rates[0],rates[1],1.2,.099,.01,.02)
 return data

def poll(u):
 u.reg_write(UC_ARM_REG_LR,symbols['compute_idle'][0]);u.reg_write(UC_ARM_REG_SP,0x200000)
 run_to_idle(u,symbols['workflow_runtime_poll'][0])
def request(u,seq,op,axis=0,q=0,c=None,record=None,corrupt=False):
 data=struct.pack('<4If',seq,0x57464c31,op,axis,q)+(c or bytes(344))+(record or bytes(468))
 data+=struct.pack('<I',zlib.crc32(data)^(1 if corrupt else 0));assert len(data)==836
 u.mem_write(symbols['g_arm_request'][0],data);poll(u);return words(u,'g_arm_reply')
invalid=new_cpu(snapshot);assert request(invalid,1,100,c=config(False))[1]==1
assert request(invalid,2,100,c=config())[1]==0
assert request(invalid,2,1)[1]==24
assert request(invalid,3,1,corrupt=True)[1]==22
results=[{'scenario':'boot_configure_bad_config_replay_CRC','passed':True,'peripherals_mapped':False,'CAN_commands':0}]

# Minimal initial-pose mode uses the cold boot snapshot; no PREVIEW/config/IK.
minimal=new_cpu(snapshot);minimal_plant=Plant(minimal,'minimal_hold')
minimal_plant.axes[3]['zero_state']=0
assert request(minimal,1,102)[1]==0
pose=bytes(minimal.mem_read(symbols['g_initial_pose'][0],116))
assert zlib.crc32(pose[:-4])==struct.unpack_from('<I',pose,112)[0]
assert struct.unpack_from('<I',pose,28)[0]==0
assert all(((word>>8)&7)==0 for word,value in minimal_plant.command_log)
assert minimal_plant.enable_count==0 and words(minimal,'g_arm_report')[2]==9
assert request(minimal,2,103,record=pose.ljust(468,b'\0'))[1]==0
assert words(minimal,'g_arm_report')[2]==10 and minimal_plant.enabled==63 and minimal_plant.hold
assert not minimal_plant.commits and words(minimal,'g_arm_calibration')[0]==0
assert request(minimal,3,4)[1]==20 and request(minimal,4,5)[1]==20 and request(minimal,5,6)[1]==20
assert request(minimal,6,105)[1]==20  # No long geometry work while held.
for _ in range(100):minimal_plant.ticks+=333333*100;poll(minimal)
assert words(minimal,'g_arm_report')[2]==10 and minimal_plant.enabled==63 and minimal_plant.enable_count==6
assert words(minimal,'g_approved_path_geometry')[3]==0 and not minimal_plant.commits
assert all(abs(fp(minimal_plant.axes[a]['p'])-initial[a])<1e-6 for a in range(6))
stops_before_drag=minimal_plant.stop_requests
minimal_plant.axes[0]['p']=bits(initial[0]+.06)
minimal_plant.axes[0]['vel']=bits(.2)
for _ in range(5):minimal_plant.ticks+=333333*100;poll(minimal)
assert words(minimal,'g_arm_report')[2]==10 and minimal_plant.enabled==63
assert minimal_plant.stop_requests==stops_before_drag and minimal_plant.enable_count==6
minimal_plant.axes[0]['p']=bits(initial[0]);minimal_plant.axes[0]['vel']=bits(0)
minimal_plant.ticks+=333333*100;poll(minimal)
assert words(minimal,'g_arm_report')[2]==10 and minimal_plant.enabled==63
(root/'reports/arm_initial_pose_test.bin').write_bytes(pose)
results.append({'scenario':'capture_save_hold_without_config_or_IK','passed':True,'held_mask':63,'target_groups':0,'model_calibration_created':False,'manual_deflection_no_stop':True,'original_PP_target_retained':True})
minimal_plant.auto_heartbeat=False;minimal_plant.ticks+=333333*1100;poll(minimal)
assert words(minimal,'g_arm_report')[2]==0xe2 and words(minimal,'g_arm_report')[10]==1 and minimal_plant.enabled==0
results.append({'scenario':'minimal_hold_heartbeat_loss','passed':True,'motor_commands_after_fault':'stops only'})
restored_pose=new_cpu(snapshot)
assert request(restored_pose,1,104,record=pose.ljust(468,b'\0'))[1]==0
assert words(restored_pose,'g_arm_report')[2]==9
bad=bytearray(pose);bad[64]^=1
assert request(restored_pose,2,104,record=bytes(bad).ljust(468,b'\0'))[1]==22
results.append({'scenario':'raw_pose_restore_passive_CRC_rejection','passed':True,'peripherals_mapped':False})
moved=new_cpu(snapshot);moved_plant=Plant(moved,'moved_pose')
assert request(moved,1,104,record=pose.ljust(468,b'\0'))[1]==0
moved_plant.axes[3]['zero_state']=0;moved_plant.axes[0]['p']=bits(initial[0]+.01)
assert request(moved,2,103,record=pose.ljust(468,b'\0'))[1]==3
assert moved_plant.enable_count==0 and not moved_plant.enabled
results.append({'scenario':'saved_pose_mismatch_no_enable','passed':True,'enable_count':0})

# Explicit geometry is computed with DDR only, then reused for legacy cases.
preview=new_cpu(snapshot);assert request(preview,1,105)[1]==0
assert words(preview,'g_approved_path_geometry')[:5]==(0x50494331,1,1,232,1)
snapshot=bytes(preview.mem_read(0x100000,0x100000))

def setup(scenario,rates=(1,2)):
 u=new_cpu(snapshot);p=Plant(u,scenario);seq=2
 assert request(u,seq,100,c=config(rates=rates))[1]==0;seq+=1
 r=request(u,seq,1);seq+=1
 if scenario=='wrong_ABI':return u,p,seq,r
 assert r[1]==0,r
 for a in range(6):
  r=request(u,seq,2,a+1,reference[a]);seq+=1
  assert r[1]==0,(a,r,words(u,'g_arm_report')[:12])
 assert request(u,seq,3)[1]==0;seq+=1
 return u,p,seq,None

def finish(u,p,state):
 for _ in range(12000):
  report=words(u,'g_arm_report')
  if report[2] in (state,13,0xe2):return report
  p.ticks+=333333*20;poll(u)
 raise RuntimeError('Virtual workflow did not finish')

readonly=new_cpu(snapshot);readonly_plant=Plant(readonly,'readonly')
assert request(readonly,2,8)[1]==0 and readonly_plant.enable_count==0
assert all(((word>>8)&7)==0 for word,value in readonly_plant.command_log)
assert words(readonly,'g_arm_readback')[0:4]==(1,0,1,0)
results.append({'scenario':'explicit_readonly_without_calibration','passed':True,'CAN_commands':len(readonly_plant.command_log),'enable_count':0})

stop_cases={'explicit_stop':True,'stop_one_missing':False,'stop_running_feedback':False,
            'stop_feedback_error':False,'stop_near_zero_rs00':True,'stop_fast_el05':False,
            'stop_snapshot_race':False,'stop_delayed_feedback':True,'stop_late_feedback':False}
for scenario in ['nominal','wrong_sequence_echo','following_error','late_commit','host_lost','stop_unknown','wrong_ABI']+list(stop_cases):
 u,p,seq,r=setup(scenario)
 if scenario=='wrong_ABI':
  assert r[1]==5 and not p.command_log and not p.enabled
 elif scenario in ('host_lost','stop_unknown'):
  p.auto_heartbeat=False;p.ticks+=333333*1100;poll(u);r=words(u,'g_arm_report')
  if scenario=='host_lost':assert r[2]==0xe2 and r[11]==23 and r[10]==1 and p.enabled==0
  else:assert r[2]==0xe2 and r[3]==11 and r[11]==23 and r[10]==0 and p.enabled==0
 elif scenario in stop_cases:
  commands_before=len(p.command_log);stops_before=p.stop_requests;enables_before=p.enable_count
  p.put(symbols['g_arm_stop'][0],1);poll(u);r=words(u,'g_arm_report');trace=words(u,'g_arm_stop_trace')
  assert r[2]==0xe2 and r[11]==23 and p.locked
  assert bool(r[10])==stop_cases[scenario] and r[4]==(0 if stop_cases[scenario] else 63),(scenario,r[:12])
  assert r[3]==(23 if stop_cases[scenario] else 11)
  assert len(p.command_log)==commands_before and p.stop_requests==stops_before+1 and p.enable_count==enables_before
  assert trace[:2]==(0x53545031,1)
  if scenario=='stop_one_missing':assert trace[3]==0x37
  if scenario in ('stop_running_feedback','stop_snapshot_race','stop_late_feedback'):assert trace[3]==0x1f
  if scenario=='stop_feedback_error':assert trace[3]==0x3e
  if scenario=='stop_delayed_feedback':assert 150<=trace[2]<300
  if scenario=='stop_late_feedback':assert 300<=trace[2]<350
  if scenario in ('explicit_stop','stop_near_zero_rs00','stop_fast_el05'):assert trace[3]==63
  # No replay or renewed actuation after the latch, even on late feedback.
  p.ticks+=333333*400;poll(u);assert len(p.command_log)==commands_before and p.stop_requests==stops_before+1
  assert words(u,'g_arm_report')[10]==r[10]
 else:
  record=bytes(u.mem_read(symbols['g_arm_calibration'][0],468));assert zlib.crc32(record[:-4])==struct.unpack_from('<I',record,464)[0]
  assert request(u,seq,4)[1]==0;seq+=1;r=finish(u,p,4)
  if scenario=='nominal':
   assert r[2]==4 and p.enabled==63 and p.hold
   pick_count=words(u,'workspace')[0];(root/'reports/arm_workflow_pick_plan.bin').write_bytes(bytes(u.mem_read(symbols['workspace'][0],8+pick_count*60)))
   assert request(u,seq,5)[1]==0;seq+=1;r=finish(u,p,5);assert r[2]==5 and p.enabled==63
   deliver_count=words(u,'workspace')[0];(root/'reports/arm_workflow_deliver_plan.bin').write_bytes(bytes(u.mem_read(symbols['workspace'][0],8+deliver_count*60)))
   assert request(u,seq,6)[1]==0;seq+=1;r=finish(u,p,3);assert r[2]==3 and p.enabled==63
   return_count=words(u,'workspace')[0];(root/'reports/arm_workflow_return_plan.bin').write_bytes(bytes(u.mem_read(symbols['workspace'][0],8+return_count*60)))
   for a in range(6):assert abs(fp(p.axes[a]['p'])-initial[a])<1e-5
   stops_before_drag=p.stop_requests;p.axes[0]['p']=bits(initial[0]+.2);p.axes[0]['vel']=bits(1.3)
   for _ in range(5):p.ticks+=333333*100;poll(u)
   assert words(u,'g_arm_report')[2]==3 and p.enabled==63 and p.stop_requests==stops_before_drag
   p.axes[0]['p']=bits(initial[0]);p.axes[0]['vel']=bits(0);p.ticks+=333333*100;poll(u)
   assert words(u,'g_arm_report')[2]==3 and p.enabled==63
   before=len(p.commits);enabled_before=p.enable_count;assert request(u,seq-1,4)[1]==24;assert len(p.commits)==before and p.enable_count==enabled_before
   # An actual reset restores DDR defaults; import is passive with no mapped peripherals.
   restored=new_cpu(snapshot);assert request(restored,2,101,record=record)[1]==0
   bad=bytearray(record);bad[200]^=1;assert request(restored,3,101,record=bytes(bad))[1]==22
   (root/'reports/arm_test_calibration.bin').write_bytes(record)
   with (root/'reports/arm_workflow_trace.csv').open('w',newline='',encoding='utf-8') as f:
    writer=csv.writer(f);writer.writerow(['virtual_ms','sequence','motor1','motor2','motor3','motor4','motor5','motor6']);writer.writerows(p.commits)
  elif scenario=='late_commit':
   assert r[2]==13 and r[3]==0 and r[11]==0 and p.enabled==63 and p.hold,(scenario,r[:12])
   before=len(p.commits)
   for _ in range(5):p.ticks+=333333*60;poll(u)
   assert words(u,'g_arm_report')[2]==13 and len(p.commits)==before
  else:
   assert r[2]==0xe2 and r[11]=={'wrong_sequence_echo':5,'following_error':9}[scenario] and p.enabled==0,(scenario,r[:12])
 row={'scenario':scenario,'passed':True,'state':hex(words(u,'g_arm_report')[2]),'CAN_model_commands':len(p.command_log),'model_enables':p.enable_count,'model_enabled_mask':p.enabled}
 if scenario in stop_cases:
  row.update(stop_confirmed=bool(r[10]),reported_enabled_mask=r[4],stop_ack_mask=hex(trace[3]),
             stop_elapsed_ms=trace[2],no_CAN_queries_after_stop=True,no_auto_retry=True)
 results.append(row);print(json.dumps(row),flush=True)
layout={n:{'address':hex(symbols[n][0]),'bytes':symbols[n][1]} for n in ['_start','compute_idle','workflow_runtime_poll','g_arm_request','g_arm_reply','g_arm_report','g_arm_stop_trace','g_arm_timing','g_arm_calibration','g_arm_heartbeat','g_arm_stop','g_arm_readback','g_initial_pose','g_approved_path_geometry','workspace','g_arm_cartesian']}
layout['ELF_sha256']=hashlib.sha256(elfpath.read_bytes()).hexdigest()
(root/'reports/workflow_symbols.json').write_text(json.dumps(layout,indent=2)+'\n',encoding='utf-8')
(root/'reports/arm_workflow_verification.json').write_text(json.dumps({'status':'PASS_ACTUAL_ARM_OFFLINE_ONLY','ELF_sha256':layout['ELF_sha256'],'cases':results,'calibration':'synthetic only; not physical','hardware_access':False},indent=2)+'\n',encoding='utf-8')
