"""Actual ARM ELF against a virtual mailbox and ideal tracking plant only.
No hardware/debugger/network. Synthetic calibration below is NOT for real use.
"""
import argparse,csv,hashlib,json,struct,sys,time
from pathlib import Path
parser=argparse.ArgumentParser();parser.add_argument('--deps',type=Path,required=True);args=parser.parse_args();sys.path.insert(0,str(args.deps))
from unicorn import Uc,UC_ARCH_ARM,UC_MODE_ARM,UC_HOOK_MEM_READ,UC_HOOK_MEM_WRITE
from unicorn.arm_const import UC_ARM_REG_CPSR,UC_ARM_REG_SP,UC_ARM_REG_LR,UC_ARM_REG_PC,UC_CPU_ARM_CORTEX_A9
from elftools.elf.elffile import ELFFile
root=Path(__file__).resolve().parents[1];elfpath=root/'build/path_executor.elf'
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
boot=new_cpu();run_to_idle(boot,entry)
assert words(boot,'g_path_execution_report')[:4]==(0x50544831,1,10,1)
assert words(boot,'g_path_request')[0:2]==(0,0)
assert words(boot,'g_approved_path_geometry')[0:5]==(0x50494331,1,1,232,1)
snapshot=bytes(boot.mem_read(0x100000,0x100000));geometry_address=symbols['g_approved_path_geometry'][0]
initial_model=struct.unpack('<6f',bytes(boot.mem_read(geometry_address+60+28,24)))
# Distinct negative/positive gains and offsets exercise float bit handling.
gains=[-1,-1,-1,-1,-1,1];zero=[.01,1.57,0,.02,1.57,-.03]
initial=[zero[a]+gains[a]*initial_model[a] for a in range(6)]
def config(valid=True):
    data=struct.pack('<6I2f',0x43414c31 if valid else 0,0x53544f31,50,50,500,55000,.001,.5)
    for a in range(6):data+=struct.pack('<3I10f',a+1,1,0,gains[a],zero[a],-6,6,1,2,1.2,.099,.01,.02)
    assert len(data)==344;return data
def call_service(u,sequence,configuration):
    u.mem_write(symbols['g_path_request'][0],struct.pack('<2I',sequence,0x52554e31)+configuration)
    u.reg_write(UC_ARM_REG_LR,symbols['compute_idle'][0]);u.reg_write(UC_ARM_REG_CPSR,0x1d3);u.reg_write(UC_ARM_REG_SP,0x200000)
    run_to_idle(u,symbols['path_executor_service'][0])
    return words(u,'g_path_execution_report')
# Invalid configuration must return with peripheral memory completely unmapped.
invalid=new_cpu(snapshot);bad=call_service(invalid,1,config(False));assert bad[2:4]==(0xe0,1)
results=[{'scenario':'boot_and_invalid_calibration','passed':True,'peripheral_memory_mapped':False,'CAN_commands':0}]

class Plant:
    def __init__(self,u,scenario):
        self.u=u;self.scenario=scenario;self.reg={0:0x43414e36,4:0x20006,0x20:0,0x24:0,0x28:0x3f0b,0x30:0,0x34:0,0x38:0,0x3c:0,0x40:0,0x44:0,0x48:0,0x4c:0}
        if scenario=='wrong_ABI':self.reg[4]=0x20005
        self.ticks=0;self.timer_enabled=False;self.path=False;self.seq=0;self.staged=0;self.enabled=0;self.locked=False;self.ever=False
        self.command_log=[];self.commits=[];self.stop_requests=0;self.enable_count=0;self.query=0;self.first_enable=None;self.verified_time=0
        self.axes=[{'p':bits(initial[a]),'vel':0,'mode':0,'speed':0,'accel':0,'preload':False,'last':bits(initial[a]),'target':bits(initial[a]),'cached':None,'snapshot':None,'age':0,'count':0} for a in range(6)]
        u.mem_map(0x40000000,0x1000);u.mem_map(0xf8f00000,0x1000)
        u.hook_add(UC_HOOK_MEM_READ,self.read,begin=0x40000000,end=0x40000fff)
        u.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=0x40000000,end=0x40000fff)
        u.hook_add(UC_HOOK_MEM_READ,self.read,begin=0xf8f00200,end=0xf8f00208)
        u.hook_add(UC_HOOK_MEM_WRITE,self.write,begin=0xf8f00200,end=0xf8f00208)
    def ms(self):return self.ticks/333333.
    def put(self,address,value):self.u.mem_write(address,struct.pack('<I',value&0xffffffff))
    def stop(self,emergency=False):
        self.stop_requests+=1;self.enabled=0;self.path=False;self.staged=0
        for a in self.axes:
            a['vel']=0
            if not(self.scenario=='stop_unknown' and self.ever):a['count']+=1
        if emergency:self.locked=True
    def read(self,u,access,address,size,value,data):
        if address in (0xf8f00200,0xf8f00204,0xf8f00208):
            if address==0xf8f00200 and self.timer_enabled:self.ticks+=33333
            if self.enabled and self.path and (self.ms()-self.verified_time>500 or self.ms()-self.first_enable>60000 or any(self.ms()-a['age']>=500 for a in self.axes)):
                self.stop(True);self.reg[0x20]=0xe1091a
            self.put(address,(self.ticks>>(32 if address==0xf8f00204 else 0)) if address!=0xf8f00208 else int(self.timer_enabled));return
        offset=address-0x40000000
        if offset==0x2c:
            a=self.query&7;p=(self.query>>8)&31;m=self.axes[a]
            v=m['count'] if p==1 else ((a+1)|(0x20000 if m['count'] else 0)|(0x200 if self.enabled&(1<<a) else 0)) if p==0 else 0
        else:v=self.reg.get(offset,0)
        self.put(address,v)
    def write(self,u,access,address,size,value,data):
        if address in (0xf8f00200,0xf8f00204,0xf8f00208):
            if address==0xf8f00208:self.timer_enabled=bool(value&1)
            elif address==0xf8f00200:self.ticks=(self.ticks&0xffffffff00000000)|value
            else:self.ticks=(self.ticks&0xffffffff)|(value<<32)
            return
        offset=address-0x40000000;self.reg[offset]=value
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
            mapping={0x7005:m['mode'],0x7019:m['p'],0x701b:m['vel'],0x7029:1,0x702b:0,0x7018:bits(10),0x700b:bits(6)}
            if index not in mapping:self.reject();return
            result=mapping[index]
        elif op==4 and a==0 and index==0 and value==0:self.stop()
        elif op==7 and a==0 and index==0 and value==0x54524a31 and not self.enabled:
            self.path=True;self.seq=0;self.staged=0
            for x in self.axes:x['preload']=False;x['cached']=None
        elif op==2 and index==0x7005 and value==1 and not self.enabled:m['mode']=1;result=1
        elif op==1 and not self.enabled:
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
                if self.scenario=='late_commit':self.ticks+=333333*100
        else:self.reject();return
        self.reg[0x3c]+=1;self.reg[0x40]+=1;self.reg[0x24]=result;self.reg[0x20]=6;self.reg[0x34]+=1

for scenario in ['nominal','wrong_sequence_echo','following_error','late_commit','stop_unknown','wrong_ABI']:
    u=new_cpu(snapshot);plant=Plant(u,scenario);r=call_service(u,1,config())
    expected={'nominal':0,'wrong_sequence_echo':5,'following_error':9,'late_commit':8,'stop_unknown':11,'wrong_ABI':5}[scenario]
    assert r[3]==expected,(scenario,r[:12])
    count,duration=words(u,'g_path_workspace')[:2]
    if scenario=='nominal':
        assert r[2]==100 and r[5]==count and r[9]==1 and plant.enable_count==6 and plant.enabled==0,(r[:12],count,plant.enable_count,plant.enabled)
        before=len(plant.command_log);call_service(u,1,config());assert len(plant.command_log)==before and words(u,'g_path_service_rejection')[0]==3
        second=call_service(u,2,config());assert second[3]==0 and second[9]==1 and plant.enable_count==12
        with (root/'reports/arm_executor_trace.csv').open('w',newline='',encoding='utf-8') as f:
            writer=csv.writer(f);writer.writerow(['virtual_ms','sequence','motor1','motor2','motor3','motor4','motor5','motor6']);writer.writerows(plant.commits)
        (root/'reports/arm_compiled_plan.bin').write_bytes(bytes(u.mem_read(symbols['g_path_workspace'][0],8+count*60)))
    if scenario=='stop_unknown':
        assert not r[9];before=len(plant.command_log);call_service(u,2,config());assert len(plant.command_log)==before and words(u,'g_path_service_rejection')[0]==4
    if scenario=='wrong_ABI':assert not plant.command_log and plant.enable_count==0
    row={'scenario':scenario,'passed':True,'error':r[3],'phase':hex(r[2]),'frames_completed':r[5],
         'planned_frames':count,'planned_duration_ms':duration,'commands':len(plant.command_log),'enable_count':plant.enable_count,
         'stop_confirmed':r[9],'virtual_execution_ms':r[7]}
    results.append(row);print(json.dumps(row),flush=True)
result={'status':'PASS_ACTUAL_ARM_OFFLINE_ONLY','ELF_sha256':hashlib.sha256(elfpath.read_bytes()).hexdigest(),
        'model':'virtual ABI 0x20006 mailbox; ideal instantaneous target tracking, not motor dynamics','calibration':'synthetic signs/offsets/rates; NOT physical calibration',
        'cases':results,'hardware_access':False}
(root/'reports/arm_executor_verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
(root/'reports/executor_elf_layout.json').write_text(json.dumps({n:{'address':hex(symbols[n][0]),'bytes':symbols[n][1]} for n in ['_start','compute_idle','g_path_request','g_path_execution_report','g_approved_path_geometry','g_path_workspace','path_executor_service']},indent=2)+'\n',encoding='utf-8')
