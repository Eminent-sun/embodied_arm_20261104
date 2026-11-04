from pathlib import Path
import csv, hashlib, json, math, platform, re, shutil, statistics
from datetime import datetime

import os
SOURCE = Path(__file__).resolve().parent
HERE = Path(os.environ['FPGA_AUDIT_OUTPUT']).resolve()
HERE.mkdir(parents=True, exist_ok=True)
PROJECT = SOURCE / 'evidence/project'
EVIDENCE = HERE / 'evidence'
EVIDENCE.mkdir(exist_ok=True)

def digest(data): return hashlib.sha256(data).hexdigest()
manifest = []
def snapshot(path, relative):
    data = path.read_bytes()
    out = EVIDENCE / relative
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_bytes(data)
    manifest.append({'source': str(path), 'copy': str(out.relative_to(HERE)), 'sha256': digest(data), 'size': len(data), 'source_mtime_ns': path.stat().st_mtime_ns})
    return out

def quantiles(values):
    a = sorted(values)
    if not a: return {'n': 0}
    # Nearest-rank empirical quantiles, no interpolation, maximum retained.
    return {'n':len(a), 'p50': a[math.ceil(.50*len(a))-1], 'p95': a[math.ceil(.95*len(a))-1], 'p99': a[math.ceil(.99*len(a))-1], 'max':a[-1], 'min':a[0], 'mean':statistics.mean(a)}

def write_csv(name, rows):
    if not rows: return
    with (HERE / name).open('w', encoding='utf-8-sig', newline='') as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0])); w.writeheader(); w.writerows(rows)

cycles, dwells, holds, moves, session_rows, fault_rows, reply_rows = [], [], [], [], [], [], []
for session in sorted((SOURCE / 'evidence/operator_logs').iterdir()):
    if not session.is_dir(): continue
    files = {}
    for name in ['recorded_cycle.jsonl', 'requests.jsonl', 'fault_snapshots.jsonl', 'before_recovery.jsonl']:
        src = session / name
        if src.exists():
            p = snapshot(src, Path('operator_logs') / session.name / name)
            files[name] = [json.loads(x) for x in p.read_text(encoding='utf-8').splitlines() if x.strip()]
    events = files.get('recorded_cycle.jsonl', [])
    current = None
    active_move = None
    for row in events:
        event = row['event']; t = row.get('time_monotonic_s')
        if event == 'cycle_started':
            if current:
                current['outcome'] = 'missing_terminal_before_next_start'; cycles.append(current)
            current = {'session': session.name, 'start_s':t,'end_s':'', 'duration_s':'', 'outcome':'missing_terminal', 'final_state':'', 'gripper_pulse_us':'', 'evidence':str(Path('evidence/operator_logs')/session.name/'recorded_cycle.jsonl')}
        if event in ['cycle_completed','cycle_rejected_hold','cycle_paused','cycle_aborted']:
            if current:
                current.update(end_s=t, duration_s=t-current['start_s'],outcome=event, final_state=row.get('final_state',''),gripper_pulse_us=row.get('gripper_pulse_us',''))
                cycles.append(current); current=None
        if event == 'dwell_finished':
            dwells.append({'session':session.name,'time_s':t,'requested_s':row['seconds'],'elapsed_s':row['elapsed_s'],'overshoot_ms':1000*(row['elapsed_s']-row['seconds']), 'unsettled_snapshot_count':row.get('jitter_samples',0),'label':row['label']})
        if event == 'hold_ready':
            a=row['arm']
            for axis,(p,target,vel) in enumerate(zip(a['position_rad'],a['target_rad'],a['velocity_rad_s']),1):
                holds.append({'session':session.name,'time_s':t,'axis':axis,'position_rad':p,'target_rad':target,'error_rad':p-target,'abs_error_rad':abs(p-target),'velocity_rad_s':vel,'label':row['label']})
        if event == 'move_accepted': active_move=row
        if event == 'waypoint_arrived' and active_move and active_move.get('source_request')==row.get('source_request'):
            moves.append({'session':session.name,'request':row['source_request'],'accepted_s':active_move['time_monotonic_s'],'arrived_s':t,'duration_s':t-active_move['time_monotonic_s'],'phase':row['phase']});active_move=None
        if event == 'request':
            reply=row.get('reply',[])
            reply_rows.append({'session':session.name,'request':row.get('request'),'operation':row.get('operation'),'result':reply[1] if len(reply)>1 else None})
    if current: cycles.append(current)
    for row in files.get('fault_snapshots.jsonl',[]):
        status=row.get('status') or {}; timing=row.get('timing') or {}
        fault_rows.append({'session':session.name,'time':row.get('time'),'state':status.get('state'),'error':status.get('error'),'fault_cause':status.get('fault_cause'),'stop_confirmed':status.get('stop_confirmed'), 'sample_ms':timing.get('sample_ms'),'last_service_ms':timing.get('last_service_ms'),'max_service_ms':timing.get('max_service_ms'),'scope':'stored DDR snapshot, not fresh physical observation'})
    if files:
        cs=[x for x in cycles if x['session']==session.name]
        session_rows.append({'session':session.name,'events':len(events),'cycle_starts':len(cs),'cycle_completions':sum(x['outcome']=='cycle_completed' for x in cs),'fault_snapshots':len(files.get('fault_snapshots.jsonl',[]))})

for name, rows in [('cycles.csv',cycles),('dwells.csv',dwells),('hold_snapshots.csv',holds),('move_durations.csv',moves),('sessions.csv',session_rows),('fault_snapshots.csv',fault_rows),('request_results.csv',reply_rows)]:write_csv(name,rows)

for p in [PROJECT/'reports'/n for n in ['utilization.rpt','timing_summary.rpt','drc.rpt','cdc.rpt','gripper_signoff.json']] + [PROJECT/'candidate/rtl/pl_servo_axi.v',PROJECT/'candidate/sim/tb_servo_axi.sv',PROJECT/'software/build/arm_workflow.elf',PROJECT/'software/tools/recorded_cycle.py']:
    snapshot(p, Path('project')/p.relative_to(PROJECT))
util=(EVIDENCE/'project/reports/utilization.rpt').read_text()
resources={}
for key,label in [('lut','Slice LUTs'),('ff','Slice Registers'),('slice','Slice'),('bram','Block RAM Tile'),('dsp','DSPs')]:
    m=re.search(r'^\| '+re.escape(label)+r'\s*\|\s*([\d.]+)\s*\|\s*0\s*\|\s*0\s*\|\s*([\d.]+)\s*\|\s*([\d.]+)',util,re.M)
    assert m,label
    resources[key]={'used':float(m[1]),'capacity':float(m[2]),'percent':float(m[3])}
timing=(EVIDENCE/'project/reports/timing_summary.rpt').read_text()
m=re.search(r'WNS\(ns\).*?\n\s*-+.*?\n\s*([\d.-]+)\s+([\d.-]+)\s+(\d+)\s+(\d+)\s+([\d.-]+)',timing,re.S)
assert m, 'timing summary'
timing_info={'wns_ns':float(m[1]),'tns_ns':float(m[2]),'setup_failing_endpoints':int(m[3]),'whs_ns':float(m[5]),'scope':'existing routed report; not new implementation or physical timing measurement','warnings':'2 no_input_delay, 2 no_output_delay; CDC/reset warnings remain'}
complete=[x for x in cycles if x['outcome']=='cycle_completed']
closed=[x for x in cycles if x['outcome'] in ['cycle_completed','cycle_rejected_hold','cycle_paused','cycle_aborted']]
outcomes={o:sum(x['outcome']==o for x in cycles) for o in sorted(set(x['outcome'] for x in cycles))}
per_axis={str(axis):{'n':len(v:=[x['error_rad'] for x in holds if x['axis']==axis]),'rmse_rad':math.sqrt(statistics.mean(x*x for x in v)) if v else None,'absolute_error_rad':quantiles([abs(x) for x in v])} for axis in range(1,7)}
summary={'created_local':datetime.now().isoformat(timespec='seconds'),'project':str(PROJECT),'guide_section':'3.2.4; printed pages 13-14, PDF pages 16-17',
 'quantile_method':'nearest_rank', 'resources':resources,'timing':timing_info,
 'path_cycle_log_audit':{'started':len(cycles),'outcomes':outcomes,'completed_over_all_started_percent':100*len(complete)/len(cycles) if cycles else None,'completed_over_known_terminal_percent':100*len(complete)/len(closed) if closed else None,'completed_duration_s':quantiles([x['duration_s'] for x in complete]),'scope':'uncontrolled development logs across route/calibration revisions; controller completion only; grasp/object success and interventions not observed'},
 'dwell_overshoot_ms':quantiles([x['overshoot_ms'] for x in dwells]),'accepted_to_arrived_move_s':quantiles([x['duration_s'] for x in moves]),
 'hold_snapshot_error':{'per_axis':per_axis,'pooled_abs_error_rad':quantiles([x['abs_error_rad'] for x in holds]),'scope':'selected settled snapshots with serial per-axis readings; not trajectory RMSE or external positioning accuracy'},
 'fault_log':{'snapshot_count':len(fault_rows),'unique_session_time_pairs':len(set((x['session'],x['time']) for x in fault_rows)),'sessions_with_fault_snapshots':len(set(x['session'] for x in fault_rows)),'unconfirmed_stop_snapshot_count':sum(x['stop_confirmed'] is False for x in fault_rows),'scope':'snapshots can repeat a latched incident; no incident rate or MTBF denominator'},
 'recorded_cycle_request_results':{'count':len(reply_rows),'nonzero_result_count':sum(x['result'] not in [0,None] for x in reply_rows),'scope':'application result codes include readiness/plan rejections; not communication packet loss'},
 'hardware_access_this_audit':False}
(HERE/'measured_summary.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
(HERE/'evidence_manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
