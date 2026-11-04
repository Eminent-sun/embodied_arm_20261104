"""Independent checks on ARM-generated samples; no hardware motor model."""
from pathlib import Path
import hashlib,json,struct

root=Path(__file__).resolve().parents[1]
report=root/'reports'
def plan(name):
    data=(report/name).read_bytes()
    count,duration=struct.unpack_from('<2I',data)
    assert len(data)==8+count*60
    rows=[struct.unpack_from('<3I12f',data,8+i*60) for i in range(count)]
    assert rows[0][0]==0 and rows[-1][0]==duration
    assert all(rows[i][0]-rows[i-1][0]==50 for i in range(1,count))
    return rows,duration

old,old_ms=plan('baseline_6s_cartesian_plan.bin')
new,new_ms=plan('arm_cartesian_plan.bin')
assert old_ms==6000 and new_ms>old_ms and new_ms<=55000
for a in range(6):
    assert abs(new[0][9+a]-old[0][9+a])<1e-6
    assert abs(new[-1][9+a]-old[-1][9+a])<1e-6
    assert new[-1][9+a]==new[-2][9+a]
    assert abs(new[-2][9+a]-new[-3][9+a])<1e-6
assert new[-1][2]==1 and not any(f[2] for f in new[:-1])
cal=(report/'arm_cartesian_calibration.bin').read_bytes()
axes=[struct.unpack_from('<3I10f',cal,56+a*52) for a in range(6)]
assert all(a[7]==.5 and a[8]==.5 for a in axes)

def rates(rows):
    previous=[0.]*6;max_v=[0.]*6;max_a=[0.]*6
    for i in range(1,len(rows)):
        for a in range(6):
            d=rows[i][9+a]-rows[i-1][9+a]
            max_v[a]=max(max_v[a],abs(d)/.05)
            max_a[a]=max(max_a[a],abs(d-previous[a])/.0025)
            previous[a]=d
    return max_v,max_a

v,a=rates(new)
assert all(x<=.25001 for x in v) and all(x<=.1251 for x in a)
# Illustrate sensitivity to a chosen fixed 350 ms delay. This is not measured
# motor latency, PP dynamics, stopping behaviour or a board PASS criterion.
def delayed_error(rows):
    return max(abs(row[9+a]-rows[max(0,i-7)][9+a]) for i,row in enumerate(rows) for a in range(6))
old_lag,new_lag=delayed_error(old),delayed_error(new)
assert old_lag>.099 and new_lag<.099
result={'status':'PASS_ARM_PLAN_TRACKING_MARGIN_OFFLINE_ONLY',
    'ELF_sha256':hashlib.sha256((root/'build/arm_workflow.elf').read_bytes()).hexdigest(),
    'target_base_xyz_mm':[200,0,100],'target_rpy_deg':[0,-45,0],
    'old_duration_ms':old_ms,'new_duration_ms':new_ms,'frames':len(new),'sample_ms':50,
    'max_motor_velocity_rad_s_by_axis':v,'max_motor_acceleration_rad_s2_by_axis':a,
    'motor_PP_speed_rad_s':.5,'motor_PP_accel_rad_s2':.5,
    'PS_target_speed_cap_rad_s':.25,'PS_target_accel_cap_rad_s2':.125,
    'following_error_limit_rad':.099,'endpoint_unchanged':True,'calibration':'synthetic test record',
    'delay_sensitivity':{'assumed_delay_ms':350,'old_max_error_rad':old_lag,'new_max_error_rad':new_lag,
       'meaning':'illustrative fixed delay only; not a calibrated RobStride dynamics model'},
    'duration_scope':'Nominal plan samples only; completion spacing adds communication/verification time on the board',
    'board_motion_verified':False,'PL_changed':False}
(report/'cartesian_tracking_verification.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps(result,indent=2))
