"""Compare RA8P1 constants with the supplied URDF; read-only, no hardware."""
from pathlib import Path
import hashlib,json,re,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
source=root/'vendor/ra8p1/urdf_kinematics.c'
text=source.read_text()
def table(name):
    body=re.search(r'static const float '+name+r'\[6\]\[3\]\s*=\s*\{(.*?)\};',text,re.S)[1]
    return [[float(x.strip().rstrip('f')) for x in row.split(',') if x.strip()] for row in re.findall(r'\{([^{}]+)\}',body)]
xyz,rpy=table('g_origin_xyz'),table('g_origin_rpy')
urdf=root.parent/'docs/reference/robotarm2V0.URDF.urdf'
model=ET.parse(urdf).getroot();joints=[]
for a in range(6):
    joint=model.find(f"joint[@name='joint{a+1}']")
    assert joint is not None
    p=[float(v) for v in joint.find('origin').get('xyz').split()]
    r=[float(v) for v in joint.find('origin').get('rpy').split()]
    axis=[float(v) for v in joint.find('axis').get('xyz').split()]
    assert p==xyz[a] and r==rpy[a] and axis==[0,0,1]
    joints.append({'id':a+1,'xyz_m':p,'rpy_rad':r,'axis':axis})
assert xyz[4]==xyz[5]==[0,0,0] and rpy[2][:2]==[0,0]
report={'status':'PASS_MODEL_SUPPORTS_ANALYTIC_SPHERICAL_WRIST',
        'original_URDF_sha256':hashlib.sha256(urdf.read_bytes()).hexdigest(),
        'original_C_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
        'all_six_URDF_joint_origins_match_C':True,'J2_J3_parallel':True,
        'J4_J5_J6_common_origin':True,'Link6_origin_is_wrist_center_in_this_model':True,
        'rounding_or_mechanical_parameter_changes':False,'joints':joints,
        'scope':'Matches the supplied URDF and operator spherical-wrist assertion; no physical measurement or tool/TCP calibration.'}
(root/'reports/spherical_wrist_audit.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(report['status'])
