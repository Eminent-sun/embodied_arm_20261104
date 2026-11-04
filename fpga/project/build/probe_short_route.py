from pathlib import Path
src=Path('software/tests/verify_recorded_cycle_arm.py').read_text(encoding='utf-8')
ns={'__file__':str(Path('software/tests/verify_recorded_cycle_arm.py').resolve()),'__name__':'route_probe'}
exec(compile(src.split("folder=ROOT/'reports/recorded_cycle_virtual'")[0],ns['__file__'],'exec'),ns)
import tempfile
from recorded_cycle import RecordedCycleRunner,APPROACH
from workflow_protocol import cartesian_payload,cartesian_report
with tempfile.TemporaryDirectory() as folder:
 r=RecordedCycleRunner(ns['VirtualWorker'](),ns['submit'],2,folder,progress=lambda _:None,clock=lambda:ns['p'].ms()/1000,sleep=ns['advance'])
 r.preflight();r.move(APPROACH[0],'probe')
 print('PICK REACHED',flush=True)
 candidates=[(180,0,z,0,pitch,0) for pitch in [0,-10,-20,-30,-60,-90] for z in [170,180,190,200]]+[(180,-150,170,-60,-90,0)]
 for pose in candidates:
  r.sequence+=1;reply=ns['req'](ns['u'],r.sequence,106,record=cartesian_payload(pose))
  info=cartesian_report(r.worker.read('g_arm_cartesian',36))
  print(pose,reply[1],info.get('target_joint_rad'),flush=True)
