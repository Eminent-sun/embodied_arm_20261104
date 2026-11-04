"""Actual ARM ELF against a synthetic mailbox; no hardware/debugger access."""
import ast,hashlib,json,struct,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from workflow_protocol import load_record,cartesian_payload
source=ROOT/'tests/emulate_workflow.py'
tree=ast.parse(source.read_text(encoding='utf-8'),filename=str(source));nodes=[]
for node in tree.body:
    if isinstance(node,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='boot' for t in node.targets):break
    nodes.append(node)
nodes.extend(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in ('poll','request'))
ns={'__file__':str(source),'__name__':'dispatch_hold_virtual_plant'}
exec(compile(ast.Module(body=nodes,type_ignores=[]),str(source),'exec'),ns)
record=load_record(ROOT/'tests/fixtures/latehold_calibration.json')
ns['initial']=list(struct.unpack_from('<6f',record,440))
req,words,sym,poll,bits=(ns[k] for k in ('request','words','symbols','poll','bits'))
results=[]
def passed(name,**details):
    row={'scenario':name,'passed':True,**details};results.append(row);print(json.dumps(row),flush=True)
def setup(frames=3):
    u=ns['new_cpu']();ns['run_to_idle'](u,ns['entry']);p=ns['Plant'](u,'dispatch_hold')
    for a in range(6):p.axes[a]['zero_state']=struct.unpack_from('<I',record,60+a*52)[0]
    assert req(u,1,101,record=record)[1]==0 and req(u,2,1)[1]==0
    assert req(u,3,107,record=cartesian_payload([200,0,100,0,0,0]))[1]==0
    for _ in range(5000):
        if words(u,'g_arm_report')[7]>=frames:break
        p.ticks+=333333*20;poll(u)
        assert words(u,'g_arm_report')[2]==11
    assert words(u,'g_arm_report')[7]==frames
    return u,p
def late(u,p,ms):
    # Stop normal polling at a completed group. Then advance the real timer
    # seen by the ELF to next_due + the requested delay, without CAN traffic.
    t=words(u,'g_arm_timing');epoch=words(u,'g_arm_workflow')
    # next_frame_due is the final uint32_t of arm_workflow_t.
    due=epoch[-1]
    p.ticks=(due+ms)*333333
    poll(u)
    return words(u,'g_arm_report'),words(u,'g_arm_timing')
def unchanged_motor_writes(p,start):
    return all(((w>>8)&7)==0 or (((w>>8)&7)==7 and (w>>11) in (2,3)) for w,v in p.command_log[start:])

for ms in (91,100):
    u,p=setup();commits=len(p.commits);stops=p.stop_requests
    r,t=late(u,p,ms)
    assert r[2]==11 and r[7]==4 and len(p.commits)==commits+1
    assert p.enabled==63 and p.stop_requests==stops and t[15]==100
    passed('dispatch_'+str(ms)+'ms_continues',threshold_ms=t[15])

u,p=setup();commits=len(p.commits);stops=p.stop_requests;enables=p.enable_count;commands=len(p.command_log)
target=bytes(u.mem_read(sym['g_arm_report'][0]+96,24))
r,t=late(u,p,101)
assert r[2:7]==(13,0,63,63,1) and r[7]==3 and r[11]==0 and t[12]==2 and t[15]==100
assert p.hold and not p.path and p.stop_requests==stops and p.enable_count==enables
assert len(p.commits)==commits and unchanged_motor_writes(p,commands)
for _ in range(150):p.ticks+=333333*20;poll(u)
assert words(u,'g_arm_report')[2]==13 and words(u,'g_arm_report')[7]==3
assert p.enabled==63 and len(p.commits)==commits and p.stop_requests==stops
assert bytes(u.mem_read(sym['g_arm_report'][0]+96,24))==target
passed('101ms_freezes_verified_target_and_holds_for_3s_no_disable_reenable_or_replay')

assert req(u,4,108)[1]==0
for _ in range(5000):
    p.ticks+=333333*20;poll(u)
    if words(u,'g_arm_report')[2]!=11:break
assert words(u,'g_arm_report')[2]==3 and p.enabled==63
assert all(abs(ns['fp'](p.axes[a]['p'])-ns['initial'][a])<1e-6 for a in range(6))
passed('explicit_GOHOME_after_pause_returns_saved_initial_and_holds')

# Motor still decelerating: preserve its committed PP target, not the fresh
# measured position. The virtual plant does not model physical braking forces.
u,p=setup();axis=p.axes[5];old=axis['target'];axis['p']=bits(ns['fp'](old)-.01);axis['vel']=bits(.15)
r,t=late(u,p,120)
assert r[2]==13 and axis['target']==old and p.enabled==63
axis['p']=old;axis['vel']=0;p.ticks+=333333*60;poll(u)
assert words(u,'g_arm_report')[2]==13
passed('moving_axis_keeps_last_PP_target_until_settled')

for kind in ('STOP','host_loss','CAN_fault','motor_fault','tracking_fault','speed_fault'):
    u,p=setup();late(u,p,120);commits=len(p.commits);enables=p.enable_count
    if kind=='STOP':p.put(sym['g_arm_stop'][0],1)
    elif kind=='host_loss':p.auto_heartbeat=False;p.ticks+=333333*1100
    elif kind=='CAN_fault':p.reg[0x30]=1
    elif kind=='motor_fault':p.axes[1]['status_extra']=0x400
    elif kind=='tracking_fault':p.axes[1]['p']=bits(ns['fp'](p.axes[1]['p'])+.2)
    else:p.axes[1]['vel']=bits(.8)
    p.ticks+=333333*60;poll(u)
    assert words(u,'g_arm_report')[2]==226 and not p.enabled
    assert len(p.commits)==commits and p.enable_count==enables
    passed(kind+'_during_PAUSED_HOLD_still_stops')

for kind in ('tracking_fault','CAN_fault','hold_reply_failure','transaction_timeout','lease_expired'):
    u,p=setup();commits=len(p.commits);enables=p.enable_count;ms=120
    if kind=='tracking_fault':p.axes[1]['p']=bits(ns['fp'](p.axes[1]['p'])+.2)
    elif kind=='CAN_fault':p.reg[0x30]=1
    elif kind=='lease_expired':ms=600
    else:
        original=p.command
        def command():
            w=p.reg[0x10];op=(w>>8)&7;index=w>>11
            if kind=='transaction_timeout' and op==0:
                p.reg[0x20]=1;return
            original()
            if kind=='hold_reply_failure' and op==7 and index==2:p.reg[0x24]=1
        p.command=command
    r,t=late(u,p,ms)
    assert r[2]==226 and not p.enabled and len(p.commits)==commits and p.enable_count==enables
    passed(kind+'_cannot_enter_PAUSED_HOLD')

# The user's exact failure point: 255/293 and 91 ms delay now progresses.
u,p=setup(255);commits=len(p.commits);r,t=late(u,p,91)
assert r[2]==11 and r[7]==256 and len(p.commits)==commits+1 and p.enabled==63
passed('reported_frame255_delay91ms_advances_to256_without_disable')
out={'status':'PASS_ACTUAL_ARM_DISPATCH_HOLD_OFFLINE','ELF_sha256':hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest(),
     'cases':results,'dispatch_limit_ms':100,'CAN_transaction_timeout_ms':50,'hardware_access':False,
     'plant_limitation':'Synthetic transport and ideal tracking; physical deceleration/torque and collision clearance are not verified.'}
(ROOT/'reports/dispatch_hold_arm.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('PASS DISPATCH HOLD',len(results),'SCENARIOS',flush=True)
