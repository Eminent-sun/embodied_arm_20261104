"""Offline ARM investigation only: higher pickup approach and descent."""
from pathlib import Path
import json,tempfile

root=Path(__file__).resolve().parents[1]
source=root/'software/tests/verify_recorded_cycle_arm.py'
prefix=source.read_text(encoding='utf-8').split("folder=ROOT/'reports/recorded_cycle_virtual'")[0]
ns={'__file__':str(source),'__name__':'pick_approach_probe'}
exec(compile(prefix,str(source),'exec'),ns)
from recorded_cycle import RecordedCycleRunner,Waypoint
from workflow_protocol import cartesian_payload,cartesian_report

results=[]
with tempfile.TemporaryDirectory() as folder:
    runner=RecordedCycleRunner(ns['VirtualWorker'](),ns['submit'],2,folder,
        progress=lambda text:print(text,flush=True),clock=lambda:ns['p'].ms()/1000,sleep=ns['advance'])
    runner.preflight()
    for pose in [(180,0,190,0,0,0),(180,0,190,0,-10,0)]:
        runner.sequence+=1
        reply=ns['req'](ns['u'],runner.sequence,106,record=cartesian_payload(pose))
        info=cartesian_report(runner.worker.read('g_arm_cartesian',36))
        row={'pose':pose,'reply':reply,'cartesian':info};results.append(row)
        print(json.dumps(row),flush=True)
    assert results[0]['reply'][1]==2 and results[1]['reply'][1]==0
    runner.grip(1110,'Virtual gripper open')
    runner.move(Waypoint(None,(180.,0.,190.,0.,-10.,0.)),'approach')
    runner.move(Waypoint(54,(180.,0.,160.,0.,0.,0.)),'descend')

out={'hardware_access':False,'candidates':results,'accepted_segments':ns['segments']}
(root/'software/reports/pick_approach_30mm_probe.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('PICK_APPROACH_30MM_PROBE_PASS',flush=True)
