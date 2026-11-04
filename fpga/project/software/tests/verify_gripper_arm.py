"""Execute the delivered ARM ELF with virtual AXI registers; no board access.
Uses the established six-axis ideal plant to test isolation/coexistence.
"""
import ast,hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from gripper_protocol import gripper_payload
from workflow_protocol import load_record,cartesian_payload
source=ROOT/'tests/emulate_workflow.py'
tree=ast.parse(source.read_text(encoding='utf-8'));nodes=[]
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='boot' for t in node.targets):break
    nodes.append(node)
nodes.extend(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('poll','request'))
ns={'__file__':str(source),'__name__':'gripper_virtual_plant'}
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'),ns)
record=load_record(ROOT/'tests/fixtures/latehold_calibration.json')
ns['initial']=list(struct.unpack_from('<6f',record,440))
req,words,sym,poll=(ns[k] for k in ('request','words','symbols','poll'))
results=[]
def passed(name):results.append({'scenario':name,'passed':True});print('PASS',name,flush=True)

class Servo:
    def __init__(self,u):
        self.u=u;self.writes=[];self.reg={0:0x53525631,4:0x10000,8:0,12:1400,16:10,20:5,24:0,28:1400,32:1400,36:0}
        u.mem_map(0x40001000,0x1000)
        u.hook_add(ns['UC_HOOK_MEM_READ'],self.read,begin=0x40001000,end=0x40001fff)
        u.hook_add(ns['UC_HOOK_MEM_WRITE'],self.write,begin=0x40001000,end=0x40001fff)
    def read(self,u,access,address,size,value,data):u.mem_write(address,struct.pack('<I',self.reg.get(address-0x40001000,0)))
    def write(self,u,access,address,size,value,data):
        off=address-0x40001000;self.writes.append((off,value));self.reg[off]=value
        if off==8:
            self.reg[24]=value
            if value:self.reg[28]=self.reg[32]=self.reg[12]

def setup(servo=True,abi=0x20009):
    u=ns['new_cpu']();ns['run_to_idle'](u,ns['entry'])
    assert words(u,'g_gripper_report')[:6]==(0x53525631,1,0,0,0,0)
    p=ns['Plant'](u,'gripper');p.reg[4]=abi
    for a in range(6):p.axes[a]['zero_state']=struct.unpack_from('<I',record,60+a*52)[0]
    return u,p,Servo(u) if servo else None
def grip(u,seq,*args):return req(u,seq,111,record=gripper_payload(list(args)))

u,p,s=setup();assert grip(u,1,'STATUS')[1]==0 and not s.writes and not p.command_log
assert grip(u,2,'OPEN')[1]==0 and s.reg[32]==1220 and s.reg[24]&1
assert words(u,'g_arm_report')[2:7]==(0,0,0,0,0) and not p.command_log
passed('boot_disabled_status_read_only_gripper_enable_no_CAN_or_arm_calibration')
for seq,action,value in [(3,'CLOSE',1360),(4,'INIT',1110)]:
    assert grip(u,seq,action)[1]==0 and s.reg[32]==value
assert grip(u,5,'US','1300','2','40')[1]==0 and s.reg[32]==1300 and s.reg[16]==2 and s.reg[20]==2
assert grip(u,6,'OFF')[1]==0 and s.reg[24]==0
assert not p.command_log;passed('all_presets_custom_pulse_and_OFF_stay_independent')

u,p,s=setup(servo=False,abi=0x20008)
assert grip(u,1,'OPEN')[1]==41 and not p.command_log
passed('old_BIT_rejected_before_accessing_unmapped_PWM_address')
u,p,s=setup();s.reg[0]=0
assert grip(u,1,'OPEN')[1]==41 and not s.writes
passed('wrong_PWM_ID_rejected_without_writes')
u,p,s=setup()
bad=bytearray(gripper_payload(['OPEN']));struct.pack_into('<I',bad,12,2000)
assert req(u,1,111,record=bytes(bad))[1]==40 and not s.writes
bad=bytearray(gripper_payload(['OPEN']));bad[24]=1
assert req(u,2,111,record=bytes(bad))[1]==40 and not s.writes
assert req(u,3,111,record=gripper_payload(['OPEN']),corrupt=True)[1]==22 and not s.writes
passed('bounds_padding_CRC_fail_without_actuation')
assert grip(u,4,'OPEN')[1]==0
n=len(s.writes);assert grip(u,4,'CLOSE')[1]==24 and len(s.writes)==n
passed('replayed_request_rejected')
p.ticks+=333333*200;poll(u);assert (0x28,0x4b49434b) in s.writes and s.reg[24]==1
passed('live_host_renews_PL_lease')
# Emulate an independently expired PL lease; a late refresh must not reenable.
s.reg[24]=8;s.reg[8]=0;p.ticks+=333333*200;poll(u)
assert not words(u,'g_gripper_report')[5] and words(u,'g_gripper_report')[7]
assert not any(off==8 and v==1 for off,v in s.writes[n:])
passed('expired_PL_lease_visible_without_automatic_reenable')
assert grip(u,5,'OPEN')[1]==0
p.put(sym['g_arm_stop'][0],1);poll(u);assert s.reg[24]==0
assert grip(u,6,'CLOSE')[1]==42 and s.reg[24]==0
assert grip(u,7,'OFF')[1]==0
passed('STOP_disables_PWM_and_blocks_enable_OFF_still_available')
u,p,s=setup();assert grip(u,1,'OPEN')[1]==0
p.auto_heartbeat=False;p.ticks+=333333*1100;poll(u);assert s.reg[24]==0
passed('lost_console_heartbeat_disables_PWM')

u,p,s=setup();assert req(u,1,101,record=record)[1]==0 and req(u,2,1)[1]==0
assert grip(u,3,'CLOSE')[1]==0
assert req(u,4,107,record=cartesian_payload([200,0,100,0,0,0]))[1]==0
for _ in range(5000):
    p.ticks+=333333*20;poll(u)
    assert s.reg[24]==1
    if words(u,'g_arm_report')[2]!=11:break
assert words(u,'g_arm_report')[2]==12 and p.enabled==63 and len(p.commits)>1
assert len([1 for off,v in s.writes if off==8 and v==1])==1
passed('full_cartesian_motion_coexists_with_gripper_hold_without_reenable')
assert req(u,5,108)[1]==0
while words(u,'g_arm_report')[7]<3:p.ticks+=333333*20;poll(u)
due=words(u,'g_arm_workflow')[-1];p.ticks=(due+120)*333333;poll(u)
assert words(u,'g_arm_report')[2]==13 and s.reg[24]==1 and p.enabled==63
passed('dispatch_PAUSED_HOLD_retains_gripper_PWM')
p.reg[0x30]=1;p.ticks+=333333*60;poll(u)
assert words(u,'g_arm_report')[2]==226 and s.reg[24]==0
passed('arm_fault_disables_gripper_without_automatic_restart')
u,p,s=setup()
for seq,pulse in [(1,1110),(2,1490)]:
    assert grip(u,seq,'US',str(pulse))[1]==0 and s.reg[32]==pulse and s.reg[24]==1
for seq,pulse in [(3,1109),(4,1491)]:
    invalid=bytearray(gripper_payload(['INIT']));struct.pack_into('<I',invalid,12,pulse)
    before=list(s.writes)
    assert req(u,seq,111,record=bytes(invalid))[1]==40 and s.writes==before
assert not p.command_log
passed('expanded_1110_1490_endpoints_accepted_outside_rejected_no_CAN')
out={'status':'PASS_ACTUAL_ARM_GRIPPER_OFFLINE','ELF_sha256':hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest(),'cases':results,'hardware_access':False,'limitation':'Virtual peripheral and ideal arm tracking, not servo mechanics.'}
(ROOT/'reports/gripper_arm_tests.json').write_text(json.dumps(out,indent=2)+'\n')
print('GRIPPER_ARM_PASS',len(results))
