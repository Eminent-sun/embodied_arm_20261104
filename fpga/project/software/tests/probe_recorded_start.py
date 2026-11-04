"""Offline investigation of first-plan rejection, using the incident calibration."""
from pathlib import Path
import json,struct
ROOT=Path(__file__).resolve().parents[1]
source=(ROOT/'tests/verify_recorded_cycle_arm.py').read_text(encoding='utf-8').split('u,p,_=setup(servo=False);s=RampingServo(u,p)')[0]
source=source.replace('operator_logs/20261104_113335/calibration_latest.json','operator_logs/20261104_124450/calibration_latest.json')
ns={'__file__':str(ROOT/'tests/verify_recorded_cycle_arm.py')}
exec(compile(source,__file__,'exec'),ns)
rows=[]
for axis,delta in [(None,0),(2,-.0004),(2,.0004),(4,.0004),(4,-.0004),(2,-.0012),(4,-.0012)]:
    u,p,s=ns['setup']()
    req=ns['req'];words=ns['words'];record=ns['record']
    assert req(u,1,101,record=record)[1]==0 and req(u,2,1)[1]==0
    if axis is not None:
        initial=struct.unpack_from('<6f',record,440)
        p.axes[axis]['p']=ns['ns']['bits'](initial[axis]+delta)
    result=req(u,3,106,record=ns['cartesian_payload']((200,0,300,0,-90,0)))
    report=ns['sym']['g_arm_cartesian']
    raw=bytes(u.mem_read(report[0],report[1]))
    from sys import path
    path.insert(0,str(ROOT/'tools'))
    from workflow_protocol import cartesian_report
    row={'axis':None if axis is None else axis+1,'motor_delta_rad':delta,'reply':result,'cartesian':cartesian_report(raw),'state':words(u,'g_arm_report')[2]}
    expected=2 if delta<-.001 else 0
    assert result==(3,expected,106,0)
    assert words(u,'g_arm_report')[2]==3 and p.enabled==63
    assert not p.commits and not p.locked
    print(json.dumps(row),flush=True);rows.append(row)

# Runner must preserve verified hold when planning refuses a larger offset.
from recorded_cycle import RecordedCycleRunner,CyclePlanRejected
from tempfile import TemporaryDirectory
for operation in (106,107):
    u,p,s=ns['setup']()
    assert req(u,1,101,record=record)[1]==0 and req(u,2,1)[1]==0
    if operation==106:p.axes[2]['p']=ns['ns']['bits'](struct.unpack_from('<6f',record,440)[2]-.0012)
    class Worker:
        stops=0
        def read(self,name,count):
            ns['poll'](u)
            return bytes(u.mem_read(ns['sym'][name][0],count*4))
        def stop(self):self.stops+=1
    def submit(worker,sequence,op,record=None):
        if operation==107 and op==107:
            p.axes[2]['p']=ns['ns']['bits'](struct.unpack_from('<6f',ns['record'],440)[2]-.0012)
        return req(u,sequence,op,record=record)
    worker=Worker()
    with TemporaryDirectory() as folder:
        runner=RecordedCycleRunner(worker,submit,2,folder,progress=lambda _:None)
        try:runner.run()
        except CyclePlanRejected:pass
        else:raise AssertionError('Expected explicit planning rejection')
    assert worker.stops==0 and p.enabled==63 and not p.commits and words(u,'g_arm_report')[2]==3
    if operation==106:assert not s.reg[24]
    rows.append({'runner_rejected_operation':operation,'hold_preserved':True,'stop_writes':worker.stops,'passed':True})
import hashlib
out={'status':'PASS_ACTUAL_ARM_START_BOUNDARY_AND_REJECTION_HOLD','ELF_sha256':hashlib.sha256((ROOT/'build/arm_workflow.elf').read_bytes()).hexdigest(),
     'runner_sha256':hashlib.sha256((ROOT/'tools/recorded_cycle.py').read_bytes()).hexdigest(),
     'calibration_fixture_sha256':hashlib.sha256(record).hexdigest(),'cases':rows,'hardware_access':False}
(ROOT/'reports/recorded_start_reproduction.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('START_BOUNDARY_AND_REJECTION_HOLD_PASS',len(rows),flush=True)
