"""Independent checks of actual ARM-generated schedule; test calibration only."""
import json,math,re,struct
from pathlib import Path
root=Path(__file__).resolve().parents[1]
blob=(root/'reports/arm_compiled_plan.bin').read_bytes();count,duration=struct.unpack_from('<2I',blob)
frames=[struct.unpack_from('<3I12f',blob,8+i*60) for i in range(count)]
source=(root/'vendor/ra8p1/urdf_kinematics.c').read_text()
def table(name):
    text=re.search(r'static const float '+name+r'\[6\]\[3\]\s*=\s*\{(.*?)\};',source,re.S)[1]
    return [[float(x.strip().rstrip('f')) for x in row.split(',') if x.strip()] for row in re.findall(r'\{([^{}]+)\}',text)]
def vector(name):return [float(x.strip().rstrip('f')) for x in re.search(r'static const float '+name+r'\[6\]\s*=\s*\{(.*?)\};',source,re.S)[1].split(',')]
def rot(a):
    cr,cp,cy=map(math.cos,a);sr,sp,sy=map(math.sin,a)
    return [[cy*cp,cy*sp*sr-sy*cr,cy*sp*cr+sy*sr],[sy*cp,sy*sp*sr+cy*cr,sy*sp*cr-cy*sr],[-sp,cp*sr,cp*cr]]
def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
xyz,angles=table('g_origin_xyz'),table('g_origin_rpy');lo,hi=vector('g_joint_min'),vector('g_joint_max')
def fk(q):
    r=[[1.,0,0],[0,1.,0],[0,0,1.]];p=[0.,0,0]
    for i in range(6):
        p=[p[j]+sum(r[j][k]*xyz[i][k] for k in range(3)) for j in range(3)]
        r=mul(mul(r,rot(angles[i])),rot((0,0,q[i])))
    return [x*1000 for x in p],r
points=[[200,0,100],[120,280,200],[120,280,40],[120,280,200],[250,0,100],[350,0,100],[250,0,100]]
target_r=rot((0,math.pi/4,0));maxv=maxa=maxpe=maxoe=0.;previous_delta=[0.]*6;checked=0
motion_end={stage:next(f[0] for f in frames if f[1]==stage and f[2]) for stage in range(8)}
stage_start={stage:max(f[0] for f in frames if f[1]==stage-1) for stage in range(1,8)}
for i,f in enumerate(frames):
    t,stage,last=f[:3];q=f[3:9];motor=f[9:15]
    assert t==i*50 and all(lo[a]-1e-6<=q[a]<=hi[a]+1e-6 for a in range(6))
    if i:
        delta=[motor[a]-frames[i-1][9+a] for a in range(6)]
        maxv=max(maxv,max(abs(v)/.05 for v in delta));maxa=max(maxa,max(abs(delta[a]-previous_delta[a])/.0025 for a in range(6)))
        assert max(abs(v) for v in delta)<.09901
        previous_delta=delta
    if stage in range(1,7):
        u=min(1.,(t-stage_start[stage])/(motion_end[stage]-stage_start[stage]));s=u*u*u*(10+u*(-15+6*u))
        expected=[points[stage-1][j]+(points[stage][j]-points[stage-1][j])*s for j in range(3)]
        actual,r=fk(q);pe=math.dist(actual,expected)
        relative=mul(target_r,list(map(list,zip(*r))));skew=[relative[2][1]-relative[1][2],relative[0][2]-relative[2][0],relative[1][0]-relative[0][1]]
        oe=math.atan2(math.sqrt(sum(x*x for x in skew)),sum(relative[j][j] for j in range(3))-1)
        assert pe<=.5001 and oe<=.008731,(i,stage,pe,oe)
        checked+=1;maxpe=max(maxpe,pe);maxoe=max(maxoe,oe)
assert maxv<=1.0001 and maxa<=2.0001
assert max(abs(x-y) for x,y in zip(frames[0][9:15],frames[-1][9:15]))<1e-6
result={'status':'PASS_SYNTHETIC_TIMED_PLAN_ONLY','frames':count,'duration_ms':duration,'sample_ms':50,
        'max_discrete_motor_velocity_rad_s':maxv,'max_discrete_motor_acceleration_rad_s2':maxa,
        'synthetic_test_caps':{'speed_rad_s':1,'accel_rad_s2':2},'independent_FK_samples':checked,
        'max_cartesian_error_mm':maxpe,'max_orientation_error_rad':maxoe,
        'return_to_measured_start':True,'return_motor_zero':False,
        'limitation':'Discrete setpoint checks and ideal tracking only; not continuous acceleration/collision/real motor tracking validation.'}
(root/'reports/timed_plan_verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,indent=2))
