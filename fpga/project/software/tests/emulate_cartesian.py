"""Run the existing ARM regressions once, then Cartesian cases. No hardware."""
from pathlib import Path
import csv,json,math,re,runpy,struct,sys
folder=Path(__file__).resolve().parent
ns=runpy.run_path(str(folder/'emulate_workflow.py'))
globals().update({k:ns[k] for k in ('root','new_cpu','run_to_idle','entry','symbols','words','request','setup','finish','poll','bits','fp')})
from unicorn import UC_HOOK_CODE
sys.path.insert(0,str(root/'tools'))
from workflow_protocol import cartesian_payload,cartesian_report

def cart(u,seq,op,values):
    reply=request(u,seq,op,record=cartesian_payload(values))
    data=cartesian_report(bytes(u.mem_read(symbols['g_arm_cartesian'][0],144)))
    assert data['sequence']==seq and data['result']==reply[1]
    return reply,data

cases=[]
def passed(name,**kwargs):
    row={'scenario':name,'passed':True,**kwargs};cases.append(row);print(json.dumps(row),flush=True)

target=[200,0,100,0,-45,0]
cold=new_cpu();run_to_idle(cold,entry)
r,d=cart(cold,1,106,target)
assert r[1]==0 and d['model_only'] and not d['plan_valid'] and d['solver']=='Pieper spherical wrist'
assert d['position_error_mm']<=.5 and d['orientation_error_rad']<=.00873
assert words(cold,'g_arm_report')[2:5]==(0,0,0)
passed('pure_model_CHECKPOSE_no_peripheral_mapping',solution=d)
assert cart(cold,2,107,target)[0][1]==20 and request(cold,3,108)[1]==20
passed('MOVETO_GOHOME_without_calibration_rejected')
bad=bytearray(cartesian_payload(target));struct.pack_into('<I',bad,8,2)
assert request(cold,4,106,record=bytes(bad))[1]==22
bad=bytearray(cartesian_payload(target));bad[44]=1
assert request(cold,5,106,record=bytes(bad))[1]==22
assert request(cold,6,106,record=cartesian_payload(target),corrupt=True)[1]==22
assert cart(cold,7,106,[999999,0,0,0,-45,0])[0][1]==2
passed('frame_padding_CRC_unreachable_rejected_no_peripherals')

u,p,seq,_=setup('cartesian_nominal',rates=(.5,.5))
calibration_before=bytes(u.mem_read(symbols['g_arm_calibration'][0],468))
before=(len(p.commits),p.enable_count)
r,d=cart(u,seq,106,target);seq+=1
assert r[1]==0 and d['plan_valid'] and not d['model_only'] and words(u,'g_arm_report')[2]==3
assert (len(p.commits),p.enable_count)==before and p.hold
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==calibration_before
assert all(fp(a['speed'])==.5 and fp(a['accel'])==.5 for a in p.axes)
passed('calibrated_preview_retains_hold_no_target_commit',plan=d)
r,d=cart(u,seq,107,target);seq+=1
assert r[1]==0 and words(u,'g_arm_report')[2]==11
assert cart(u,seq,107,target)[0][1]==20;seq+=1
assert finish(u,p,12)[2]==12 and p.enabled==63 and p.hold and p.enable_count==6
count=words(u,'workspace')[0]
(root/'reports/arm_cartesian_plan.bin').write_bytes(bytes(u.mem_read(symbols['workspace'][0],8+count*60)))
(root/'reports/arm_cartesian_calibration.bin').write_bytes(bytes(u.mem_read(symbols['g_arm_calibration'][0],468)))
passed('MOVETO_reaches_cartesian_hold_busy_rejected',frames=count,duration_ms=d['duration_ms'])
# Derive an independently oriented reachable pose from original model tables.
source=(root/'vendor/ra8p1/urdf_kinematics.c').read_text()
def table(name):
    body=re.search(r'static const float '+name+r'\[6\]\[3\]\s*=\s*\{(.*?)\};',source,re.S)[1]
    return [[float(x.strip().rstrip('f')) for x in row.split(',') if x.strip()] for row in re.findall(r'\{([^{}]+)\}',body)]
def rot(v):
    cr,cp,cy=map(math.cos,v);sr,sp,sy=map(math.sin,v)
    return [[cy*cp,cy*sp*sr-sy*cr,cy*sp*cr+sy*sr],[sy*cp,sy*sp*sr+cy*cr,sy*sp*cr-cy*sr],[-sp,cp*sr,cp*cr]]
def mul(a,b):return [[sum(a[i][k]*b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
xyz,angles=table('g_origin_xyz'),table('g_origin_rpy')
def fk(q):
    r=[[1.,0,0],[0,1.,0],[0,0,1.]];v=[0.,0,0]
    for a in range(6):
        v=[v[j]+sum(r[j][k]*xyz[a][k] for k in range(3)) for j in range(3)]
        r=mul(mul(r,rot(angles[a])),rot((0,0,q[a])))
    return [x*1000 for x in v],r
q=[.5,2.,-.8,.3,1.,.4];pos,rotm=fk(q)
rpy=[math.atan2(rotm[2][1],rotm[2][2]),math.atan2(-rotm[2][0],math.hypot(rotm[0][0],rotm[1][0])),math.atan2(rotm[1][0],rotm[0][0])]
arbitrary=pos+[math.degrees(x) for x in rpy]
r,d=cart(u,seq,107,arbitrary);seq+=1
assert r[1]==0 and d['solver']=='Pieper spherical wrist' and finish(u,p,12)[2]==12
passed('arbitrary_XYZ_and_all_three_RPY_components',target=arbitrary,solution=d)
count=words(u,'workspace')[0]
plan=bytes(u.mem_read(symbols['workspace'][0],8+count*60))
frames=[struct.unpack_from('<3I12f',plan,8+i*60) for i in range(count)]
last=frames[-1];checkpos,checkrot=fk(last[3:9])
assert math.dist(checkpos,pos)<=.5
trace=sum(checkrot[i][j]*rotm[i][j] for i in range(3) for j in range(3))
assert math.acos(max(-1,min(1,(trace-1)/2)))<=.00873
prev=[0.]*6;maxv=maxa=0.
for i in range(1,count):
    for a in range(6):
        delta=frames[i][9+a]-frames[i-1][9+a];v=abs(delta)/.05;acc=abs(delta-prev[a])/.0025;prev[a]=delta
        assert abs(delta)<=.099001 and v<=.25001 and acc<=.1251
        maxv=max(maxv,v);maxa=max(maxa,acc)
passed('independent_FK_endpoint_and_discrete_rates',max_velocity_rad_s=maxv,max_acceleration_rad_s2=maxa)
assert request(u,seq,108)[1]==0;seq+=1
assert finish(u,p,3)[2]==3 and p.enabled==63 and p.enable_count==6
for a in range(6):assert abs(fp(p.axes[a]['p'])-ns['initial'][a])<1e-5
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==calibration_before
assert all(fp(a['speed'])==.5 and fp(a['accel'])==.5 for a in p.axes)
passed('GOHOME_returns_saved_six_joint_pose_without_reenable')
# The observed position lag must still trip; retiming must not mask the guard.
u,p,seq,_=setup('cartesian_following_guard',rates=(.5,.5))
assert cart(u,seq,107,target)[0][1]==0
for _ in range(1000):
    if words(u,'g_arm_report')[7]>=42:break
    p.ticks+=333333*20;poll(u)
assert words(u,'g_arm_report')[2]==11
report=bytes(u.mem_read(symbols['g_arm_report'][0],120))
target6=struct.unpack_from('<f',report,116)[0]
p.axes[5]['p']=bits(target6-.10340649)
before=len(p.commits)
p.ticks+=333333*50;poll(u)
assert words(u,'g_arm_report')[2]==226 and words(u,'g_arm_report')[11]==9
assert len(p.commits)==before and not p.enabled
passed('observed_ID6_error_still_trips_no_further_target_commit',injected_error_rad=.10340649)
# Inject explicit STOP on entry to the real ARM analytic solver.
u,p,seq,_=setup('stop_during_cartesian',rates=(.5,.5))
before=len(p.commits);start=symbols['pieper_kinematics_inverse'][0]
def inject_stop(cpu,address,size,unused):p.put(symbols['g_arm_stop'][0],1)
hook=u.hook_add(UC_HOOK_CODE,inject_stop,begin=start,end=start)
r,d=cart(u,seq,107,target);u.hook_del(hook)
assert r[1]!=0 and words(u,'g_arm_report')[2]==226 and words(u,'g_arm_report')[10]==1
assert p.enabled==0 and len(p.commits)==before
passed('STOP_during_actual_ARM_IK_no_motion_commit')
u,p,seq,_=setup('speed_limit_reject',rates=(1,2))
before=len(p.commits);assert cart(u,seq,107,target)[0][1]==1 and len(p.commits)==before
passed('MOVETO_rejects_limits_above_approved_point5')
layout=json.loads((root/'reports/workflow_symbols.json').read_text())
out={'status':'PASS_ACTUAL_ARM_CARTESIAN_OFFLINE_ONLY','ELF_sha256':layout['ELF_sha256'],'cases':cases,'hardware_access':False,'physical_calibration':'synthetic only'}
(root/'reports/arm_cartesian_verification.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('PASS ARM CARTESIAN',len(cases),'SCENARIOS',flush=True)
