"""Read archived evidence only. Never connects to hardware or runs motion/tests."""
from pathlib import Path
import csv,hashlib,json,math,re,shutil
import os
SOURCE=Path(__file__).resolve().parent
H=Path(os.environ['FPGA_AUDIT_OUTPUT']).resolve()
P=SOURCE.parents[2]/'fpga/project'
M=json.loads((H/'evidence_manifest.json').read_text(encoding='utf-8'))
def save(src,rel):
    data=src.read_bytes();dest=H/'evidence'/rel;dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(data)
    M.append({'source':str(src),'copy':str(dest.relative_to(H)),'sha256':hashlib.sha256(data).hexdigest(),'size':len(data),'source_mtime_ns':src.stat().st_mtime_ns})
    return dest
files=['software/reports/pieper_host_tests.log','software/reports/cartesian_host_tests.log',
       'software/reports/cartesian_tracking_verification.json','software/reports/arm_schedule_verification.json',
       'software/reports/dispatch_hold_arm.json','software/reports/recorded_cycle_arm_path.json',
       'reports/python_tests.log','reports/recorded_cycle_final_run.log','simulation/servo/run.log',
       'software/tools/workflow_bridge.tcl','software/reports/workflow_symbols.json']
for f in files:save(SOURCE/'evidence/project'/f,Path('project')/f)
old=SOURCE/'evidence/historical/poweron_read_results.json'
oldcopy=save(old,Path('historical/poweron_read_results.json'))
hist=json.loads(oldcopy.read_text(encoding='utf-8'))
transactions=hist['transactions'];checks=[]
for t in transactions:
    src=SOURCE/'evidence/historical/ila'/Path(t['capture']).name
    data=src.read_bytes()
    checks.append({'motor':t['motor'],'index':t['index'],'capture_sha_matches':hashlib.sha256(data).hexdigest()==t['sha256'],'fresh_completion':t['fresh_completion'],'matched_wire_reply':t['matched_wire_reply']})
    save(src,Path('historical/ila')/src.name)
sign=json.loads((H/'evidence/project/reports/gripper_signoff.json').read_text(encoding='utf-8'))
hashchecks=[]
for section in ['validated_sources','paired_files']:
    for f in sign[section]:
        path=P/f['path'];actual=hashlib.sha256(path.read_bytes()).hexdigest() if path.exists() else None
        hashchecks.append({'path':f['path'],'expected':f['sha256'],'actual':actual,'match':actual==f['sha256']})
hold=list(csv.DictReader((H/'hold_snapshots.csv').open(encoding='utf-8-sig')))
errors=[float(x['error_rad']) for x in hold]
stoprows=[]
for p in sorted((H/'evidence/operator_logs').rglob('fault_snapshots.jsonl')):
    for row in map(json.loads,p.read_text(encoding='utf-8').splitlines()):
        trace=row.get('stop_trace') or {}
        if trace:stoprows.append({'session':p.parent.name,'time':row.get('time'),'elapsed_ms':trace.get('elapsed_ms'),'ack_mask':trace.get('ack_mask'),'stop_confirmed':(row.get('status') or {}).get('stop_confirmed')})
supp={'historical_reads':{'date':hist['time'],'n':len(transactions),'verified_passed':sum(all(x[k] for k in ['capture_sha_matches','fresh_completion','matched_wire_reply']) for x in checks),'checks':checks,'scope':'2026-11-02 old parameter-debug BIT, five motors, not current PC-FPGA link or long-run reliability'},
 'signoff_hash_verification':hashchecks,
 'hold_snapshot_pooled_rmse_rad':math.sqrt(sum(x*x for x in errors)/len(errors)),
 'stop_snapshots':stoprows,
 'simulation_status':{'servo_axi':'SERVO_AXI_PASS checks=246','scope':'historical RTL simulation; TB LEASE_MS=100, deployed RTL default=1000; not physical PWM measurement'},
 'no_hardware_access':True,'no_tests_rerun':True}
(H/'supplement_summary.json').write_text(json.dumps(supp,ensure_ascii=False,indent=2),encoding='utf-8')
(H/'evidence_manifest.json').write_text(json.dumps(M,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'historical_n':len(transactions),'historical_validated':supp['historical_reads']['verified_passed'],'signoff_hash_matches':sum(x['match'] for x in hashchecks),'signoff_hash_total':len(hashchecks),'pooled_hold_rmse':supp['hold_snapshot_pooled_rmse_rad'],'stop_snapshots':stoprows},ensure_ascii=False,indent=2))
