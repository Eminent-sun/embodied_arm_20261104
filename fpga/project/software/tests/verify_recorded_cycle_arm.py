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
record=load_record(ROOT/'operator_logs/20261104_130107/calibration_latest.json')
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



from recorded_cycle import APPROACH,TRANSFER,RETURN,RecordedCycleRunner
import math,re

class RampingServo(Servo):
    def __init__(self,u,plant):
        self.plant=plant;self.last_step=plant.ms();self.last_kick=plant.ms()
        super().__init__(u)
    def advance(self):
        now=self.plant.ms()
        if self.reg[24]&1:
            if now-self.last_kick>1000:
                self.reg[8]=0;self.reg[24]=8;return
            period=max(1,self.reg[20])*20
            steps=int((now-self.last_step)/period)
            if steps:
                self.last_step+=steps*period
                delta=self.reg[32]-self.reg[28]
                change=min(abs(delta),steps*self.reg[16])
                self.reg[28]+=change if delta>0 else -change
            self.reg[24]=1|(2 if self.reg[28]!=self.reg[32] else 0)
        self.reg[36]=int(now/20)
    def read(self,u,access,address,size,value,data):
        self.advance();super().read(u,access,address,size,value,data)
    def write(self,u,access,address,size,value,data):
        self.advance();off=address-0x40001000
        self.writes.append((off,value));self.reg[off]=value
        if off==8:
            if not value:self.reg[24]=0
            else:
                enabled=bool(self.reg[24]&1);self.reg[32]=self.reg[12]
                if not enabled:self.reg[28]=self.reg[32]
                self.reg[24]=1|(2 if self.reg[28]!=self.reg[32] else 0)
                self.last_kick=self.last_step=self.plant.ms()
        elif off==0x28:self.last_kick=self.plant.ms()

u,p,_=setup(servo=False);s=RampingServo(u,p)
assert req(u,1,101,record=record)[1]==0 and req(u,2,1)[1]==0
# Incident HOME is on J3/J5 upper joint limits. Inject a small outward
# encoder displacement instead of testing only ideal boundary feedback.
initial=struct.unpack_from('<6f',record,440)
for a in (2,4):p.axes[a]['p']=ns['bits'](initial[a]-.0004)
segments=[]
axes=[struct.unpack_from('<3I10f',record,56+a*52) for a in range(6)]
source=(ROOT/'vendor/ra8p1/urdf_kinematics.c').read_text()
def table(name):
    text=re.search(r'static const float '+name+r'\[6\]\[3\]\s*=\s*\{(.*?)\};',source,re.S)[1]
    return [[float(x.strip().rstrip('f')) for x in row.split(',') if x.strip()] for row in re.findall(r'\{([^{}]+)\}',text)]
def vector(name):return [float(x.strip().rstrip('f')) for x in re.search(r'static const float '+name+r'\[6\]\s*=\s*\{(.*?)\};',source,re.S)[1].split(',')]
def rot(a):
    cr,cp,cy=map(math.cos,a);sr,sp,sy=map(math.sin,a)
    return [[cy*cp,cy*sp*sr-sy*cr,cy*sp*cr+sy*sr],[sy*cp,sy*sp*sr+cy*cr,sy*sp*cr-cy*sr],[-sp,cp*sr,cp*cr]]
def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
xyz,angles=table('g_origin_xyz'),table('g_origin_rpy');joint_lo,joint_hi=vector('g_joint_min'),vector('g_joint_max')
def fk(q):
    r=[[1.,0,0],[0,1.,0],[0,0,1.]];pos=[0.,0,0]
    for a in range(6):
        pos=[pos[j]+sum(r[j][k]*xyz[a][k] for k in range(3)) for j in range(3)]
        r=mul(mul(r,rot(angles[a])),rot((0,0,q[a])))
    return [x*1000 for x in pos],r

def verify_plan(operation,payload):
    count,duration=words(u,'workspace')[:2]
    raw=bytes(u.mem_read(sym['workspace'][0],8+count*60))
    frames=[struct.unpack_from('<3I12f',raw,8+i*60) for i in range(count)]
    maxv=maxa=0.;prior=[0.]*6;dt=struct.unpack_from('<I',record,32)[0]/1000
    path_xyz=[fk(frame[3:9])[0] for frame in frames]
    assert all(all(math.isfinite(x) for x in point) for point in path_xyz)
    assert min(point[2] for point in path_xyz)>=159.5
    # Match every emitted joint to the actual planner's quintic, including
    # its two final stationary frames. The route has no wrist branch jumps.
    ticks=count-3
    physical_lo=[-1.7453293,-.0007964,-2.0943951,-2.0943951,-.1753293,-3.14]
    physical_hi=[1.7453293,3.1407964,0.,2.0943951,1.57,3.14]
    for i,frame in enumerate(frames):
        for a,axis in enumerate(axes):
            q,motor=frame[3+a],frame[9+a]
            assert joint_lo[a]-1e-6<=q<=joint_hi[a]+1e-6
            assert physical_lo[a]-1e-6<=q<=physical_hi[a]+1e-6
            assert axis[5]-1e-6<=motor<=axis[6]+1e-6
            assert abs(motor-(axis[4]+axis[3]*q))<1e-5
            fraction=min(i/ticks,1.);blend=fraction**3*(10+fraction*(-15+6*fraction))
            assert abs(q-(frames[0][3+a]+blend*(frames[-1][3+a]-frames[0][3+a])))<4e-6
            if i:
                delta=motor-frames[i-1][9+a];velocity=abs(delta)/dt;acceleration=abs(delta-prior[a])/(dt*dt)
                assert velocity<=axis[7]*.501 and acceleration<=axis[8]*.251,(i,a,velocity,acceleration)
                assert abs(delta)<=axis[10]+1e-6
                maxv=max(maxv,velocity);maxa=max(maxa,acceleration);prior[a]=delta
    endpoint,_=fk(frames[-1][3:9]);pose=None;position_error=None;orientation_error=None
    if operation==107:
        pose=struct.unpack_from('<6f',payload,16);position_error=math.dist(endpoint,pose[:3]);assert position_error<=.5
        _,actual=fk(frames[-1][3:9]);desired=rot(tuple(math.radians(x) for x in pose[3:]))
        cosine=(sum(actual[j][k]*desired[j][k] for j in range(3) for k in range(3))-1)/2
        orientation_error=math.acos(max(-1,min(1,cosine)));assert orientation_error<=.00873
    else:
        home=struct.unpack_from('<6f',record,440)
        assert all(abs(x-y)<1e-5 for x,y in zip(frames[-1][9:15],home))
    (ROOT/'reports'/f'recorded_cycle_{len(segments):02d}.bin').write_bytes(raw)
    segments.append({'operation':operation,'pose':pose,'frames':count,'duration_ms':duration,
                     'max_discrete_velocity_rad_s':maxv,'max_discrete_acceleration_rad_s2':maxa,
                     'endpoint_position_error_mm':position_error,'endpoint_orientation_error_rad':orientation_error,
                     'path_xyz_min_mm':[min(point[a] for point in path_xyz) for a in range(3)],
                     'path_xyz_max_mm':[max(point[a] for point in path_xyz) for a in range(3)]})

class VirtualWorker:
    preflight_samples=0
    dwell_jitter_samples=0
    def read(self,name,count):
        if name=='g_arm_report' and 'runner' in globals():
            starts=[e for e in runner.events if e['event']=='dwell_started']
            finishes=[e for e in runner.events if e['event']=='dwell_finished']
            active=len(starts)>len(finishes) and starts[-1]['seconds']==5.
            # Intermittent .04 rad/s feedback reproduces the incident below
            # the unchanged hold safety threshold. No 5-second quiet interval.
            noisy=active and int((p.ms()/1000-starts[-1]['time_monotonic_s'])*10)%4==0
            p.axes[1]['vel']=ns['bits'](.04 if noisy else 0.)
            if noisy:self.dwell_jitter_samples+=1
        if name=='g_arm_report' and self.preflight_samples<=2:
            p.axes[1]['vel']=ns['bits'](.04 if self.preflight_samples<2 else 0.)
            self.preflight_samples+=1
        poll(u)
        return bytes(u.mem_read(sym[name][0],count*4))
    def stop(self):
        p.put(sym['g_arm_stop'][0],1);poll(u)

readiness_rejected_requests=[]
def submit(worker,sequence,operation,record=None):
    # Actual PS observe() sees one velocity sample above the unchanged .03
    # arrival threshold at the first preview and the first MOVETO. The next
    # samples settle. No fake reply or bypass of ARM readiness checks.
    inject=operation in (106,107) and operation not in [r['operation'] for r in readiness_rejected_requests]
    commits_before=len(p.commits)
    if inject:p.axes[1]['vel']=ns['bits'](.04)
    result=req(u,sequence,operation,record=record)
    if inject:
        p.axes[1]['vel']=ns['bits'](0.)
        assert result[1]==6 and len(p.commits)==commits_before and p.enabled==63
        readiness_rejected_requests.append({'operation':operation,'sequence':sequence,'result':result[1],'no_motion_committed':True})
    if operation in (107,108):
        print('ARM segment',len(segments)+1,'result',result[1],flush=True)
        if result[1]==0:verify_plan(operation,record)
    return result

def advance(seconds):
    remaining=seconds
    while remaining>1e-12:
        step=min(.02,remaining);p.ticks+=max(1,round(333333000*step));poll(u);s.advance();remaining-=step

folder=ROOT/'reports/recorded_cycle_virtual';folder.mkdir(exist_ok=True)
worker=VirtualWorker()
runner=RecordedCycleRunner(worker,submit,2,folder,progress=lambda text:print(text,flush=True),clock=lambda:p.ms()/1000,sleep=advance)
runner.run()
assert any(e['event']=='hold_not_ready' and e['label']=='RUNPATH 前置检查' for e in runner.events)
assert len(segments)==len(APPROACH)+len(TRANSFER)+len(RETURN)+1==6
assert tuple(segments[0]['pose'])==(180.,0.,190.,0.,-10.,0.)
assert tuple(segments[1]['pose'])==(180.,0.,160.,0.,0.,0.)
# Descent retains the existing joint interpolation: sample its lateral drift
# and monotonic height rather than claim a Cartesian straight-line move.
descent_raw=(ROOT/'reports/recorded_cycle_01.bin').read_bytes()
descent_count=struct.unpack_from('<I',descent_raw)[0]
descent_xyz=[fk(struct.unpack_from('<3I12f',descent_raw,8+i*60)[3:9])[0] for i in range(descent_count)]
assert all(b[2]<=a[2]+.001 for a,b in zip(descent_xyz,descent_xyz[1:]))
assert max(math.hypot(p[0]-180.,p[1]) for p in descent_xyz)<1.
assert [r['operation'] for r in readiness_rejected_requests]==[106,107]
assert len([e for e in runner.events if e['event']=='settle_wait_ready'])==2
report=words(u,'g_arm_report');assert report[2]==3 and report[4:7]==(63,63,1)
assert s.reg[28]==s.reg[32]==1110 and s.reg[24]==1
assert len([1 for off,value in s.writes if off==8 and value==1])==3
waits=[e for e in runner.events if e['event']=='dwell_finished']
assert [e['seconds'] for e in waits]==[5.,3.,2.]
assert all(e['elapsed_s']>=e['seconds'] for e in waits)
assert waits[0]['elapsed_s']<5.2 and waits[0]['jitter_samples']>1 and worker.dwell_jitter_samples>1
assert not any(e['event']=='dwell_restarted' for e in runner.events)
requests=[e for e in runner.events if e['event']=='gripper_requested']
assert [e['pulse_us'] for e in requests]==[1110,1490,1110]
pick=next(e for e in runner.events if e['event']=='waypoint_arrived' and e['source_request']==54)
high=next(e for e in runner.events if e['event']=='waypoint_arrived' and tuple(e['pose'])==APPROACH[0].pose)
assert high['time_monotonic_s']<pick['time_monotonic_s']
assert next(e for e in runner.events if e['event']=='dwell_started')['time_monotonic_s']>=pick['time_monotonic_s']
delivery=next(e for e in runner.events if e['event']=='waypoint_arrived' and e['source_request']==155)
assert requests[1]['time_monotonic_s']-pick['time_monotonic_s']>=5
assert requests[2]['time_monotonic_s']-delivery['time_monotonic_s']>=3
open_reached=[e for e in runner.events if e['event']=='gripper_pulse_reached' and e['pulse_us']==1110][-1]
release_wait=[e for e in runner.events if e['event']=='dwell_started'][-1]
return_move=next(e for e in runner.events if e['event']=='move_accepted' and e['phase']=='返回初始位置')
assert release_wait['time_monotonic_s']>=open_reached['time_monotonic_s']
assert return_move['time_monotonic_s']-open_reached['time_monotonic_s']>=2
out={'status':'PASS_ACTUAL_ARM_RECORDED_CYCLE_OFFLINE','ELF_sha256':hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest(),
     'runner_sha256':hashlib.sha256((ROOT/'tools/recorded_cycle.py').read_bytes()).hexdigest(),
     'log_sha256':hashlib.sha256((ROOT/'operator_logs/20261104_113335/requests.jsonl').read_bytes()).hexdigest(),
     'calibration_fixture_sha256':hashlib.sha256(record).hexdigest(),'segments':segments,'waits':waits,
     'calibration_fixture':'operator_logs/20261104_130107/calibration_latest.json',
     'initial_feedback_motor_offset_rad':{'3':-.0004,'5':-.0004},
     'readiness_rejected_requests':readiness_rejected_requests,
     'preflight_transient_velocity_tested':True,
     'fixed_deadline_dwell_jitter_tested':True,'dwell_jitter_samples':worker.dwell_jitter_samples,
     'pickup_approach_raise_mm':30,'pickup_wait_after_descent':True,
     'descent_monotonic_z_tested':True,'descent_max_lateral_deviation_mm':max(math.hypot(p[0]-180.,p[1]) for p in descent_xyz),
     'virtual_elapsed_s':p.ms()/1000,'gripper_targets_us':[1110,1490,1110],
     'final_state':'INITIAL_HOLD','hardware_access':False,
     'limitation':'Actual ARM ELF with virtual ramping PWM and ideal motor tracking; no collision, grasp or loaded dynamics proof. Historical calibration is a test fixture only.'}
(ROOT/'reports/recorded_cycle_arm_path.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('RECORDED_CYCLE_ARM_PASS segments=6 approach_raise=30mm wait_after_descent=5s final=INITIAL_HOLD open=1110',flush=True)
