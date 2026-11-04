"""Exercise the shipped ARM ELF plus real host helpers with a virtual CAN plant.
No debugger, serial port, network, or hardware access. Synthetic motion only.
"""
import ast,hashlib,json,struct,sys,tempfile
from pathlib import Path
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
from workflow_protocol import load_record,pack_config,pose_info
from prepare_machine_config import prepare_for_home_calibration
from prepare_home_alignment import ID2_POSITIVE_CANDIDATE

# Reuse the existing ELF loader/virtual mailbox definitions, without running
# unrelated baseline suites or rewriting their reports. --deps is parsed by
# that loader exactly as in emulate_workflow.py.
source=ROOT/'tests/emulate_workflow.py'
tree=ast.parse(source.read_text(encoding='utf-8'),filename=str(source))
nodes=[]
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='boot' for t in node.targets):break
    nodes.append(node)
nodes.extend(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('poll','request'))
ns={'__file__':str(source),'__name__':'offline_config_home_plant'}
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'),ns)
old=load_record(ROOT/'tests/fixtures/old_direction_calibration.json')
ns['initial']=list(struct.unpack_from('<6f',old,440))
u=ns['new_cpu']();ns['run_to_idle'](u,ns['entry'])
plant=ns['Plant'](u,'config_home_candidate')
for a in range(6):
    plant.axes[a]['zero_state']=struct.unpack_from('<I',old,60+a*52)[0]
request,words,symbols,poll=(ns[k] for k in ('request','words','symbols','poll'))

assert request(u,1,101,record=old)[1]==0
assert request(u,2,1)[1]==0 and plant.enabled==63
plant.put(symbols['g_arm_stop'][0],1);poll(u)
assert words(u,'g_arm_report')[2]==226
assert request(u,3,109)[1]==0
assert words(u,'g_arm_report')[2:7]==(1,0,0,63,1)
assert words(u,'g_arm_report')[10]==1
before=len(plant.command_log);enables=plant.enable_count
assert request(u,4,102)[1]==20
assert len(plant.command_log)==before

class Worker:
    def read(self,name,count):return bytes(u.mem_read(symbols[name][0],count*4))
    def request(self,data):u.mem_write(symbols['g_arm_request'][0],data);poll(u)

class Bridge:
    def __init__(self):self.writes=[]
    def read(self,address,count):return bytes(u.mem_read(address,count*4))
    def write(self,address,data):self.writes.append((address,data));u.mem_write(address,data)

# Reproduce old console QUIT while inactive, then the explicit new reconnect.
plant.put(symbols['g_arm_stop'][0],1);poll(u)
bridge=Bridge();layout={n:{'address':hex(a),'bytes':s} for n,(a,s) in symbols.items()}
console.reconnect_confirmed_disabled(bridge,layout)
assert bridge.writes==[(symbols['g_arm_stop'][0],bytes(4))]
assert words(u,'g_arm_report')[2]==1 and not plant.enabled
worker=Worker()
with tempfile.TemporaryDirectory() as tmp,patch('builtins.print'):
    pose=console.capture_home_to_file(worker,5,Path(tmp)/'home.json',Path(tmp))
    config=prepare_for_home_calibration(pose,ID2_POSITIVE_CANDIDATE)
    assert console.submit_request(worker,6,100,config=config)[1]==0
assert plant.enable_count==enables and not plant.enabled and not plant.commits
assert all(((word>>8)&7)==0 for word,value in plant.command_log[before:])
assert words(u,'g_arm_report')[2:7]==(1,0,0,0,0)
assert worker.read('g_initial_pose',29)==bytes(116)
console.require_id2_positive_record(worker.read('g_arm_calibration',117))
query_count=len(plant.command_log)-before
assert console.submit_request(worker,7,1)[1]==0 and plant.enable_count==enables
home=[0,1.57,0,0,1.57,0]
for a,q in enumerate(home):
    assert console.submit_request(worker,8+a,2,axis=a+1,reference=q)[1]==0
assert console.submit_request(worker,14,3)[1]==0
assert words(u,'g_arm_report')[2:7]==(3,0,63,63,1)
assert plant.enable_count==enables+6
record=worker.read('g_arm_calibration',117)
console.require_id2_positive_record(record)
assert all(abs(p-q)<1e-6 for p,q in zip(pose_info(pose)['position_rad'],struct.unpack_from('<6f',record,440)))
result={'status':'PASS_CONFIGURED_HOME_CAPTURE_ACTUAL_ARM_OFFLINE',
        'ELF_sha256':hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest(),
        'old_capture_result':20,'old_capture_CAN_commands':0,'new_capture_queries':query_count,
        'new_capture_and_config_motor_writes':0,'new_capture_and_config_enables':0,
        'reconnect_only_writes_stop_word':True,'explicit_CAL_SAVEINITIAL_passed':True,
        'raw_PS_reference_buffer_unchanged':True,'hardware_access':False}
(ROOT/'reports/config_home_capture_arm.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result))
