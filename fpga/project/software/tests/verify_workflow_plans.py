"""Independent double precision FK and motor discrete rate checks. Offline."""
from pathlib import Path
import json,math,re,struct
root=Path(__file__).resolve().parents[1]
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
 for a in range(6):
  p=[p[j]+sum(r[j][k]*xyz[a][k] for k in range(3)) for j in range(3)]
  r=mul(mul(r,rot(angles[a])),rot((0,0,q[a])))
 return [x*1000 for x in p],r
def distance_segment(p,a,b):
 d=[b[i]-a[i] for i in range(3)];den=sum(x*x for x in d)
 u=max(0,min(1,sum((p[i]-a[i])*d[i] for i in range(3))/den)) if den else 0
 return math.sqrt(sum((p[i]-a[i]-u*d[i])**2 for i in range(3)))
record=(root/'reports/arm_test_calibration.bin').read_bytes();dt=struct.unpack_from('<I',record,32)[0]*.001
axes=[struct.unpack_from('<3I10f',record,56+a*52) for a in range(6)]
assert axes[2][3]==-1 and axes[4][3]==-1
home=[0.,1.57,0.,0.,1.57,0.]
physical_delta_deg=[(-100.,100.),(-90.,90.),(-120.,0.),(-120.,120.),(-100.,0.),None]
points=[[200,0,100],[120,280,200],[120,280,40],[120,280,200],[250,0,100],[350,0,100],[250,0,100]]
target_r=rot((0,-math.pi/4,0));rows=[]
for name,expected,laststage in [('pick',[120,280,40],2),('deliver',[350,0,100],5),('return',None,7)]:
 blob=(root/f'reports/arm_workflow_{name}_plan.bin').read_bytes();count,duration=struct.unpack_from('<2I',blob)
 frames=[struct.unpack_from('<3I12f',blob,8+i*60) for i in range(count)]
 maxv=maxa=maxp=maxo=0.;samples=0;prior=[0.]*6
 for i,f in enumerate(frames):
  q=f[3:9];motor=f[9:15];assert f[0]==i*round(dt*1000)
  for a in range(6):
   axis=axes[a];assert lo[a]-1e-6<=q[a]<=hi[a]+1e-6
   if physical_delta_deg[a] is not None:
    low_deg,high_deg=physical_delta_deg[a]
    delta=q[a]-home[a]
    assert math.radians(low_deg)-1e-5<=delta<=math.radians(high_deg)+1e-5,(name,i,a,delta)
   assert axis[5]<=motor[a]<=axis[6] and abs(motor[a]-(axis[4]+axis[3]*q[a]))<1e-5
   if i:
    delta=motor[a]-frames[i-1][9+a];v=abs(delta)/dt;accel=abs(delta-prior[a])/(dt*dt)
    assert abs(delta)<=.099001 and v<=axis[7]*1.0001 and accel<=axis[8]*1.0001
    maxv=max(maxv,v);maxa=max(maxa,accel);prior[a]=delta
  if 0<f[1]<7:
   p,r=fk(q);pe=distance_segment(p,points[f[1]-1],points[f[1]])
   co=sum(r[j][k]*target_r[j][k] for j in range(3) for k in range(3));oe=math.acos(max(-1,min(1,(co-1)/2)))
   assert pe<=.5 and oe<=.00873,(i,pe,oe)
   samples+=1;maxp=max(maxp,pe);maxo=max(maxo,oe)
 end,_=fk(frames[-1][3:9])
 if expected is not None:assert math.dist(end,expected)<=.5
 else:
  initial=struct.unpack_from('<6f',record,440)
  assert all(abs(frames[-1][9+a]-initial[a])<1e-5 for a in range(6))
 rows.append({'operation':name,'frames':count,'duration_ms':duration,'independent_FK_samples':samples,'max_position_segment_error_mm':maxp,'max_orientation_error_rad':maxo,'max_discrete_motor_velocity_rad_s':maxv,'max_discrete_motor_acceleration_rad_s2':maxa,'endpoint_mm':end})
out={'status':'PASS_SYNTHETIC_PLAN_ONLY','plans':rows,
     'physical_joint_delta_from_home_deg_checked':physical_delta_deg,
     'clockwise_motor_position_increases_id3_id5_user_confirmed':True,
     'limitation':'No real dynamics, continuous jerk or collision proof; historical physical HOME has not been verified for this power cycle; stage0 is joint-space approach/alignment.'}
(root/'reports/workflow_plan_verification.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8');print(json.dumps(out,indent=2))
