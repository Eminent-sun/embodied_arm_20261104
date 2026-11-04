"""Generate a scheduling adaptation; preserve the original vendor source.

The only inserted operation is an abortable service call before each IK
iteration. All mathematics, seeds, limits and convergence parameters stay
byte-for-byte identical to the reference. No hardware access here.
"""
from pathlib import Path
import hashlib,json,re

root=Path(__file__).resolve().parents[1]
source=root/'vendor/ra8p1/urdf_kinematics.c'
raw=source.read_bytes()
assert hashlib.sha256(raw).hexdigest()=='14b5c49d594a587fd74fa973a33d359a7eccb9d077d05bfb39f21cbbb5306b7e'
text=raw.decode('utf-8-sig')
needle='for (unsigned iteration = 0U; iteration < IK_MAX_ITERATIONS; iteration++)\n        {'
text=text.replace('\r\n','\n')
assert text.count(needle)==1
insertion='\n            if (arm_kinematics_service()) { memset(result, 0, sizeof(*result)); return false; }'
prefix='/* Generated scheduling adaptation. Do not edit; vendor source is unchanged. */\nextern int arm_kinematics_service(void);\n'
generated=prefix+text.replace(needle,needle+insertion)
assert generated[len(prefix):].replace(insertion,'')==text
out=root/'build/urdf_kinematics_cooperative.c'
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(generated,encoding='utf-8')
model=[]
for name in ('g_origin_xyz','g_origin_rpy','g_joint_min','g_joint_max'):
    match=re.search(r'static const float '+name+r'(\[[^;]+?;)',text,re.S)
    assert match,name
    model.append('static const float '+name.replace('g_','pieper_')+match[1])
(root/'build/urdf_model_parameters.h').write_text('/* Generated from unchanged RA8P1 model. */\n'+'\n'.join(model)+'\n',encoding='utf-8')
(root/'reports/cooperative_solver_source.json').write_text(json.dumps({
    'vendor_sha256':hashlib.sha256(raw).hexdigest(),
    'generated_sha256':hashlib.sha256(out.read_bytes()).hexdigest(),
    'changes':'One abortable service call per IK iteration; equations/model/limits/seeds unchanged',
    'mathematical_source_identity_after_removing_hook':True},indent=2)+'\n',encoding='utf-8')
print('Cooperative solver generated; original algorithm source preserved.')
