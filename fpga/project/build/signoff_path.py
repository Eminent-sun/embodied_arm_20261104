"""Read-only signoff checks; no hardware or downloads."""
from pathlib import Path
import hashlib,json,re,zipfile,xml.etree.ElementTree as ET
root=Path(__file__).resolve().parents[1]
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
def read_text_log(path):
    raw=path.read_bytes()
    return raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8-sig')
def bd_int(value):
    value=str(value)
    if value.startswith('"') and value.endswith('"'):return int(value[1:-1],2)
    return int(value,0)
expected={'tb_motion_mailbox':'PASS ALL 132 MAILBOX CHECKS','tb_motion_mailbox_v2':'PASS ALL 132 MAILBOX CHECKS',
 'tb_six_pp':'PASS ALL 366 SIX_PP CHECKS','tb_six_pp_two_turn':'PASS ALL 449 TWO_TURN CHECKS',
 'tb_six_stop_master':'PASS SIX STOP MASTER INTEGRATION','tb_pl_robstride_command_engine':'PASS ALL 30 CHECKS',
 'tb_v21_protocol_engine':'PASS ALL 10 CHECKS','tb_robstride_command_master':'RESULT: PASS V2.1 command/master integration',
 'tb_pp_commissioning':'PASS ALL 79 PP CHECKS','tb_pp_master':'PASS PP MASTER INTEGRATION',
 'tb_robstride_protocol':'RESULT: PASS (72 protocol/state checks)','tb_can_rx_service':'RESULT: PASS CAN_RX real_timing=0 (50 checks)',
 'tb_can_six_axis_tx':'RESULT: PASS SIX_AXIS real_timing=0 (45 checks)',
 'tb_path_pp':'PASS PATH_PP CONTINUATION AND GUARDS checks=1076',
 'tb_hold_pp':'PASS HOLD_PP CALIBRATION TRANSITIONS AND WATCHDOG checks=208'}
for name,marker in expected.items():
    paths=list(root.glob('simulation/*/'+name+'.run.log'));assert len(paths)==1,name
    s=paths[0].read_text(encoding='utf-8-sig',errors='replace')
    assert marker in s and not re.search(r'(?m)^FAIL\b|RESULT: FAIL|Fatal:|ERROR:',s),name
build=(root/'build/workflow_build.log').read_text(encoding='utf-8',errors='replace')
assert 'BIT_STATUS=write_bitstream Complete!' in build and 'DRC_ERROR_COUNT=0' in build
assert 'NODEBUG_CORE_COUNT=0 NO_LTX_REQUIRED' in build
wns,whs=map(float,re.search(r'(?m)^ROUTED_WNS=([\d.-]+) ROUTED_WHS=([\d.-]+)',build).groups());assert wns>=0 and whs>=0
post=(root/'build/post_build.log').read_text(encoding='utf-8',errors='replace')
assert 'INPUT_MISSING=0 INPUT_OUTSIDE=0' in post and 'NODEBUG_REOPEN_CORE_COUNT=0' in post and 'RECOVERY_PULSE_CELLS=1' in post and 'ERROR:' not in post
relocated=(root/'reports/relocated_open.log').read_text(encoding='utf-8',errors='replace')
assert 'RELOCATED_INPUT_MISSING=0 INPUT_OUTSIDE=0' in relocated and 'RELOCATED_IMPLEMENTATION_OPEN_PASS DEBUG_CORES=0' in relocated and 'ERROR:' not in relocated
baseline=json.loads((root/'reports/baseline_source_sha256.json').read_text(encoding='utf-8'))
for item in baseline['files']:
    if Path(item['path']).name not in ('pl_robstride_command_engine.v','pl_motion_mailbox.v'):assert sha(root/item['path'])==item['sha256'],item['path']
bd=json.loads((root/'candidate/roboarm.srcs/sources_1/bd/can_test/can_test.bd').read_text())['design']['components']
params=bd['pl_el05_single_tx']['parameters']
for key,value in {'ENABLE_PATH_PP':1,'ENABLE_HOLD_PP':1,'PATH_MAX_STEP_Q16':6554,'PATH_WINDOW_CYCLES':3000000000,
                  'PATH_LEASE_CYCLES':25000000,'PATH_POSITION_AGE_CYCLES':25000000}.items():assert bd_int(params[key]['value'])==value,key
assert bd_int(bd['pl_motion_mailbox']['parameters']['ABI_VERSION']['value'])==0x20008
assert not any(x in bd for x in ['ila_can_reader','vio_can_send','vio_feedback_debug','vio_el05_single_tx','line_scope'])
bit=root/'bitstream/roboarm_arm_workflow.bit';xsa=root/'bitstream/roboarm_arm_workflow.xsa'
assert sha(bit)==sha(root/'vivado2023_project/roboarm_ila_rx_debug.runs/impl_1/can_test_wrapper.bit')
assert not list((root/'bitstream').glob('*.ltx'))
with zipfile.ZipFile(xsa) as z:
    bits=[n for n in z.namelist() if n.endswith('.bit')];assert len(bits)==1 and hashlib.sha256(z.read(bits[0])).hexdigest()==sha(bit)
    for name in ('ps7_init.tcl','ps7_init.c','ps7_init.h','can_test.hwh'):assert z.read(name)==(root/'bitstream/ps_init'/name).read_bytes()
    hwh=ET.fromstring(z.read('can_test.hwh'))
    assert not any(any(x in m.attrib.get('VLNV','') for x in (':system_ila:',':vio:',':xsdbm:')) for m in hwh.iter('MODULE'))
    memory=[x.attrib for x in hwh.iter('MEMRANGE') if x.attrib.get('INSTANCE')=='pl_motion_mailbox']
    assert memory and all(int(x['BASEVALUE'],0)==0x40000000 and int(x['HIGHVALUE'],0)==0x40000fff for x in memory)
timing=(root/'reports/timing_summary.rpt').read_text(encoding='utf-8',errors='replace')
assert 'All user specified timing constraints are met.' in timing and 'checking no_clock (0)' in timing and 'checking unconstrained_internal_endpoints (0)' in timing
cdc=(root/'reports/cdc.rpt').read_text();rows=[line.split() for line in cdc.splitlines() if line.startswith('Info')]
assert len(rows)==2 and all(row[-3:-1]==['0','0'] for row in rows)
util=(root/'reports/utilization.rpt').read_text()
def n(label):return float(re.search(r'(?m)^\| '+re.escape(label)+r'\s+\|\s+([\d.]+)',util)[1])
resources={'slices':int(n('Slice')),'LUTs':int(n('Slice LUTs')),'FFs':int(n('Slice Registers')),'BRAM_tiles':n('Block RAM Tile')};assert resources['slices']<=4400
sw=root/'software';inputs=json.loads((sw/'reports/workflow_build_inputs.json').read_text(encoding='utf-8-sig'))
elf=sw/'build/arm_workflow.elf';assert inputs['ELF_sha256']==sha(elf)
for item in inputs['sources']:assert sha(sw/item['path'])==item['sha256'],item['path']
for name,value in [('urdf_kinematics.c','14b5c49d594a587fd74fa973a33d359a7eccb9d077d05bfb39f21cbbb5306b7e'),('urdf_kinematics.h','f31cf29280a29bf5d7f1ca8b75303540ee6ce064c3aea38efe8fa8fa23b722f4')]:assert sha(sw/'vendor/ra8p1'/name)==value
host=read_text_log(sw/'reports/executor_host_tests.log');assert 'PASS PATH_EXECUTOR 11 CASES' in host and 'FAIL' not in host
workflow_host=read_text_log(sw/'reports/workflow_host_tests.log');assert 'PASS WORKFLOW 68 CHECKS' in workflow_host and 'FAIL' not in workflow_host
arm=json.loads((sw/'reports/arm_workflow_verification.json').read_text());assert arm['ELF_sha256']==sha(elf) and len(arm['cases'])==22 and all(c['passed'] for c in arm['cases'])
assert any(c.get('manual_deflection_no_stop') and c.get('original_PP_target_retained') for c in arm['cases'])
layout=json.loads((sw/'reports/workflow_symbols.json').read_text());assert layout['ELF_sha256']==sha(elf)
assert layout['g_arm_stop_trace']['bytes']==112
assert layout['g_arm_report']['bytes']==120 and layout['g_arm_request']['bytes']==836
stop_expected={'explicit_stop':(True,0x3f,0),'stop_one_missing':(False,0x37,300),
 'stop_running_feedback':(False,0x1f,300),'stop_feedback_error':(False,0x3e,300),
 'stop_near_zero_rs00':(True,0x3f,0),'stop_fast_el05':(False,0x3f,300),
 'stop_snapshot_race':(False,0x1f,300),'stop_delayed_feedback':(True,0x3f,150),
 'stop_late_feedback':(False,0x1f,300)}
stop_cases={c['scenario']:c for c in arm['cases'] if c['scenario'] in stop_expected}
assert set(stop_cases)==set(stop_expected)
for name,(confirmed,mask,elapsed) in stop_expected.items():
    case=stop_cases[name]
    assert case['stop_confirmed']==confirmed and case['reported_enabled_mask']==(0 if confirmed else 63),name
    assert int(case['stop_ack_mask'],0)==mask and case['stop_elapsed_ms']==elapsed,name
    assert case['state']=='0xe2' and case['no_CAN_queries_after_stop'] and case['no_auto_retry'],name
protocol=json.loads((sw/'reports/workflow_protocol_tests.json').read_text());assert protocol['status']=='PASS_NO_HARDWARE' and protocol['checks']==8
plan=json.loads((sw/'reports/workflow_plan_verification.json').read_text());assert plan['status'].startswith('PASS_')
assert plan['clockwise_motor_position_increases_id3_id5_user_confirmed'] and plan['physical_joint_delta_from_home_deg_checked']==[[-100,100],[-90,90],[-120,0],[-120,120],[-100,0],None]
pose_tests=json.loads((sw/'reports/initial_pose_host_tests.json').read_text());assert pose_tests['status']=='PASS_OFFLINE_ONLY' and pose_tests['checks']==7
home=json.loads((sw/'config/urdf_home_candidate_20261104_01.json').read_text());assert home['nominal_urdf_home_joint_rad']==[0,1.57,0,0,1.57,0] and not home['physical_home_alignment_verified'] and not home['ready_for_motion']
live_pose=json.loads((sw/'config/home_20261104_live.json').read_text())
live_home=json.loads((sw/'config/urdf_home_live_candidate_20261104.json').read_text())
machine=json.loads((sw/'config/machine_live_candidate_20261104.json').read_text())
assert sha(sw/'config/home_20261104_live.json') and live_home['source_pose_sha256']==live_pose['sha256']==machine['source_home_pose_sha256']
assert live_home['clockwise_mechpos_increases_confirmed_for_id3_id5'] and len(live_home['candidate_motor_safe_range_intersection_rad'])==6
assert machine['stop_policy'] is None and not machine['ready_for_motion'] and not machine['physical_home_alignment_verified']
assert all(a['speed_rad_s']==.5 and a['accel_rad_s2']==.5 for a in machine['axis'])
approved=json.loads((sw/'config/accepted_path.json').read_text());assert approved['proposed_RPY_deg_now_accepted']==[0,-45,0] and not approved['physical_motion_authorized'] and approved['clockwise_sign_id3_id5_verified']
orientation=json.loads((sw/'config/negative45_path_candidate_20261104.json').read_text())
assert orientation['sample_count']==232 and orientation['geometry_math_passed'] and orientation['user_approved_orientation_change']
assert orientation['relative_to_home_joint_max_deg'][3]<120 and orientation['relative_to_home_joint_min_deg'][3]>-120
assert orientation['clockwise_motor_read_sign_id3_id5_verified'] and not orientation['runtime_motion_authorized']
result={'status':'OFFLINE_ARM_WORKFLOW_PASS_NOT_BOARD_TESTED','part':'xc7z010clg400-1','Vivado':'2023.1',
 'ABI':'0x00020008','mailbox_base':'0x40000000','resources':resources,'timing_ns':{'WNS':wns,'WHS':whs},
 'DRC':{'errors':0,'warnings':30},'methodology_warnings':7,'CDC':{'safe':115,'unsafe':0,'unknown':0},
 'debug_cores':0,'LTX_required':False,'RTL_regression_groups':15,'new_path_RTL_checks':1076,
 'host_executor_cases':11,'actual_ARM_executor_cases':22,'workflow_host_checks':68,'frozen_hold_RTL_checks':208,'record_protocol_checks':8,'source_URDF_algorithm_and_limits':'unchanged','initial_pose_host_checks':7,'nominal_URDF_home_mapping_checks':1,'boot_geometry':'deferred; explicit PREVIEW only','raw_pose_hold':'fresh PC reference before explicit enable; completed six-axis hold tolerates manual deflection and returns toward original PP target; motor/communication/watchdog guards remain; motion interfaces rejected',
 'stop_confirmation':{'status':'OFFLINE_PASS_NOT_BOARD_TESTED','deadline_ms':300,'trace_bytes':112,
   'method':'new coherent cached status frame per axis; mode0, no fault/integrity error, decoded type2 velocity within configured threshold; no normal CAN query after stop',
   'velocity_ranges_rad_s':{'ID2_RS00':[-33,33],'ID1_3_4_5_6_EL05':[-50,50]},
   'scenario_count':len(stop_cases),'PL_changed':False,'automatic_retry_or_unlock':False},
 'ZIP_extracted_Vivado_project_and_implementation_reopen':'PASS; missing/external inputs=0',
 'accepted_geometry_RPY_deg':[0,-45,0],'nominal_XYZ_order':'preserved','physical_tool':'none; Link6 reference',
 'synthetic_plan':plan,'physical_calibration':'Fresh raw motor HOME saved to PC; ID3/ID5 clockwise signs confirmed; user physical ranges encoded; model HOME alignment, stop behavior and board ELF remain unverified; raw hold is separate from fixed-path calibration',
 'board_downloaded_by_agent':False,'hardware_commands_sent_by_agent':False,
 'user_reported_prior_ELF_download':True,'new_ELF_downloaded':False,'last_user_reported_board_state':'FAULT_LOCKED / STOP_UNKNOWN after explicit STOP; six motor supplies then cut off, arm mechanically supported; new stop fix not board tested',
 'sha256':{'BIT':sha(bit),'XSA':sha(xsa),'ELF':sha(elf)}}
board_path=root/'reports/board_stop_20261104.json'
if board_path.exists() and json.loads(board_path.read_text())['local_ELF_sha256']==sha(elf):
    board=json.loads(board_path.read_text())
    assert board['status']=='PASS_USER_REPORTED_MANUAL_HOLD_STOP'
    after=board['after_stop'];trace=board['stop_trace']
    assert after['state']=='FAULT_LOCKED' and after['stop_confirmed'] and int(after['enabled_mask'],0)==0
    assert after['error']==after['fault_cause']==23 and int(trace['ack_mask'],0)==63
    assert 0<=trace['elapsed_ms']<300
    for a in range(6):
        status=int(trace['last_status'][a],0)
        assert trace['last_count'][a]!=trace['before_count'][a]
        assert status&0x20000 and status&255==a+1 and not status&0x10ff00
        scale=33 if a==1 else 50
        velocity=2*scale*trace['velocity_raw'][a]/65535-scale
        assert abs(velocity)<=board['hold_stop_velocity_threshold_rad_s']
    result['status']='OFFLINE_PASS_AND_USER_MANUAL_HOLD_STOP_PASS_PATH_NOT_BOARD_TESTED'
    result['stop_confirmation']['status']='OFFLINE_PASS_AND_ONE_USER_REPORTED_BOARD_STOP_PASS'
    result['stop_confirmation']['manual_board_evidence']='reports/board_stop_20261104.json'
    result['stop_confirmation']['observed_elapsed_ms']=trace['elapsed_ms']
    result['new_ELF_downloaded']=True
    result['new_ELF_download_evidence']='User console report with new stop_trace; board ELF digest not independently read'
    result['last_user_reported_board_state']='FAULT_LOCKED after explicit STOP, error23, stop_confirmed true, enabled_mask0; subsequent supply cutoff not reported'
    result['physical_calibration']='Raw reference saved; user manual hold-stop passed. Model HOME calibration and fixed-path motion remain unverified.'
else:
    result['last_user_reported_board_state']='Baseline workflow ELF: explicit STOP confirmed in 26 ms, mask0, FAULT_LOCKED. New Cartesian ELF not downloaded.'
    result['baseline_hold_stop_evidence']='reports/board_stop_20261104.json (different ELF; historical only)'
cart=json.loads((sw/'reports/arm_cartesian_verification.json').read_text())
assert cart['ELF_sha256']==sha(elf) and len(cart['cases'])==11 and all(c['passed'] for c in cart['cases'])
assert layout['g_arm_cartesian']['bytes']==144
assert 'PASS CARTESIAN 5449 CHECKS' in read_text_log(sw/'reports/cartesian_host_tests.log')
assert 'PASS SOLVER EQUIVALENCE 32 TARGETS' in read_text_log(sw/'reports/solver_equivalence.log')
assert 'PASS PIEPER 1012 FK_IK TARGETS' in read_text_log(sw/'reports/pieper_host_tests.log')
audit=json.loads((sw/'reports/spherical_wrist_audit.json').read_text());assert audit['all_six_URDF_joint_origins_match_C'] and audit['J4_J5_J6_common_origin']
cart_protocol=json.loads((sw/'reports/cartesian_protocol_tests.json').read_text());assert cart_protocol=={'status':'PASS_OFFLINE_ONLY','checks':4}
result['status']='CARTESIAN_PIEPER_OFFLINE_PASS_NOT_BOARD_TESTED'
result['new_ELF_downloaded']=False
result['current_cartesian_interface']={'coordinate_frame':'original URDF base','length_unit':'mm','orientation':'RPY degrees, Rz(yaw) Ry(pitch) Rx(roll)',
    'control_point':'Link6 origin / wrist center, no TCP offset','commands':['CHECKPOSE X Y Z R P Y','MOVETO X Y Z R P Y','GOHOME'],
    'method':'analytic shoulder/elbow + spherical wrist (Pieper); original DLS fallback; original FK residual validation',
    'interpolation':'joint-space quintic, not Cartesian straight-line','rate_caps':{'speed_rad_s':.5,'acceleration_rad_s2':.5},
    'actual_ARM_new_cases':11,'host_checks':5449,'analytic_FK_IK_cases':1012,'original_DLS_equivalence_cases':32,
    'PL_changed':False,'hardware_access':False,'motion_requires':'complete valid six-axis model calibration and saved initial pose, currently holding; raw HOLDINITIAL is insufficient'}
result['ZIP_extracted_Vivado_project_and_implementation_reopen']='Unchanged PL baseline evidence retained; no new PL build or board programming'
fault_path=root/'reports/board_cartesian_fault_20261104.json'
if fault_path.exists():
    observed=json.loads(fault_path.read_text())
    if observed['local_ELF_sha256']==sha(elf):
        result['status']='OFFLINE_PASS_BOARD_MOVETO_FAULT_NOT_CLEARED'
        result['new_ELF_downloaded']=True
        result['new_ELF_download_evidence']='Operator supplied Cartesian request and fault output; no independent board digest read'
        result['last_user_reported_board_state']='MOVETO stopped at 42/121: fault_cause9, stop error11, ack_mask63. Indicators stayed lit, torque lost, arm supported. Operator then re-downloaded; present state unread.'
        result['physical_calibration']='Operator CAL/SAVEINITIAL/EXPORT completed; Cartesian accuracy and physical HOME alignment not independently measured.'
        result['board_motion_fault_evidence']='reports/board_cartesian_fault_20261104.json'
        result['board_motion_complete']=False
        result['fault_diagnostics']='Host STATUS archives saved velocity, target and position error; --diagnose reads saved DDR only. Firmware and thresholds unchanged.'
tracking=json.loads((sw/'reports/cartesian_tracking_verification.json').read_text())
assert tracking['status']=='PASS_ARM_PLAN_TRACKING_MARGIN_OFFLINE_ONLY' and tracking['ELF_sha256']==sha(elf)
assert tracking['endpoint_unchanged'] and not tracking['board_motion_verified']
assert any(c['scenario']=='observed_ID6_error_still_trips_no_further_target_commit' for c in cart['cases'])
repeat=json.loads((root/'reports/board_cartesian_repeat_fault_20261104.json').read_text())
assert repeat['fault_detail']['violations_in_saved_values'][0]['motor_id']==6
assert abs(repeat['fault_detail']['saved_position_minus_target_rad'][5])>.099
result['status']='TRACKING_MARGIN_OFFLINE_PASS_BOARD_RETEST_PENDING'
result['last_user_reported_board_state']='Previous ELF repeated fault at 42/121; DDR confirmed ID6 error -0.10340649 rad over 0.099 rad. Stop unconfirmed. New retimed ELF not downloaded.'
result['board_motion_fault_evidence']='reports/board_cartesian_repeat_fault_20261104.json'
result['historical_motion_fault_resolved_on_board']=False
result['board_motion_complete']=False
result['new_ELF_downloaded']=False
result['tracking_margin']=tracking
result['current_cartesian_interface']['PS_target_rate_caps']={'speed_fraction_of_PP':.5,'acceleration_fraction_of_PP':.25}
result['current_cartesian_interface']['fixed_path_PICK_DELIVER_RETURN']='unchanged; tracking margin currently applies to MOVETO/GOHOME only'
result.pop('hardware_commands_sent_by_agent',None)
result['hardware_read_only_DDR_diagnosis_performed']=True
result['motor_control_commands_sent_by_agent']=False
result['physical_calibration']='Historical user CAL/SAVEINITIAL; model alignment and Cartesian accuracy not independently measured. New ELF requires operator setup after download.'
result['fault_diagnostics']='Repeat saved-DDR diagnosis archived; ongoing-motion STOP confirmation remains unresolved, guards unchanged.'
recovery=json.loads((sw/'reports/arm_recovery_verification.json').read_text())
assert recovery['ELF_sha256']==sha(elf) and len(recovery['cases'])==13 and all(c['passed'] for c in recovery['cases'])
for top,marker in [('tb_recover_pp','PASS RECOVER_PP'),('tb_recover_mailbox','PASS RECOVER_MAILBOX')]:
    log=read_text_log(root/'simulation/recovery'/f'{top}.run.log')
    assert marker in log and not re.search(r'(?m)^FAIL|Fatal:|ERROR:',log)
bridge=json.loads((sw/'reports/workflow_bridge_tests.json').read_text())
assert bridge['status']=='PASS_OFFLINE_STUBS_ONLY' and bridge['tests']==16
assert 'Ran 40 tests' in read_text_log(sw/'reports/schedule_python_tests.log') and '\nOK' in read_text_log(sw/'reports/schedule_python_tests.log')
result['status']='EXPLICIT_RECOVERY_OFFLINE_PASS_BOARD_RETEST_PENDING'
result['recovery']={'commands':['RECOVER','RESUME'],'ARM_cases':13,
 'mailbox_register':'0x40000050','key':'0x52454331','ABI':'0x00020008',
 'PL_behavior':'explicit E0/E1 recovery emits six type4 disable frames; healthy idle transport only; no parameter write or enable; failed TX remains locked; STOP dominates',
 'PS_behavior':'fresh stopped-mode status and position/velocity/zero/offset queries; keep valid calibration; recover to disabled standby; explicit RESUME preloads current pose',
 'hard_faults':'RX integrity, poisoned/pending transactions and uncertain TX are not cleared',
 'board_verified':False,'automatic_resume':False,'calibration_survives_hardware_power_cycle':False}
result['current_cartesian_interface']['commands']+=['RECOVER','RESUME']
result['current_cartesian_interface']['PL_changed']=True
result['stop_confirmation']['PL_changed']=True
result['tracking_margin']['PL_changed']=True
result['stop_confirmation']['automatic_retry_or_unlock']=False
result['RTL_regression_groups']=17
result['RTL_revalidated_this_revision']=14
result['unchanged_transport_historical_groups']=3
result['ZIP_extracted_Vivado_project_and_implementation_reopen']='New recovery implementation reopened and checked with all inputs inside delivery root'
result['hardware_read_only_DDR_diagnosis_performed']=False
result['hardware_access_this_revision']=False
result['new_ELF_downloaded']=False
result['last_user_reported_board_state']='Previous Cartesian firmware repeated tracking fault; new recovery BIT and ELF not downloaded by agent'
result['fault_diagnostics']='RECOVER archives the prior DDR fault snapshot before any command; automatic stopped confirmation remains unchanged; explicit recovery obtains fresh stopped feedback.'
schedule=json.loads((sw/'reports/arm_schedule_verification.json').read_text())
assert schedule['status']=='PASS_ACTUAL_ARM_SCHEDULE_OFFLINE_ONLY' and schedule['ELF_sha256']==sha(elf)
assert len(schedule['cases'])==9 and all(c['passed'] for c in schedule['cases'])
assert layout['g_arm_timing']['bytes']==64
reuse=json.loads((root/'reports/pl_reuse_manifest.json').read_text())
for item in reuse['files']:assert sha(root/item['path'])==item['sha256'],item['path']
assert sha(bit)=='9921322831ce1e1d6fabf4df04f7ae6e4b7a6a174e2b206c10bbf804df8f674f'
assert sha(xsa)=='73d1f4ba57496bf6632fed3e8efdf483af31ec29d2558d3f2f8e74d02fa5251c'
reopened=read_text_log(root/'reports/schedule_project_open.log')
assert 'RELOCATED_INPUT_MISSING=0 INPUT_OUTSIDE=0' in reopened and 'RELOCATED_IMPLEMENTATION_OPEN_PASS DEBUG_CORES=0' in reopened
result['status']='PS_SCHEDULING_OFFLINE_PASS_BOARD_RETEST_PENDING'
result['revision_scope']='PS scheduler and host timing diagnostics only; recovery PL/BIT/XSA reused byte-for-byte'
result['scheduling']=schedule
result['scheduling_policy']='MOVETO/GOHOME: verified previous group completion + configured sample interval; no catch-up/skipping; nominal plan duration excludes serial service time'
result['guards_retained']={'transaction_timeout_ms':50,'dispatch_lateness_ms':50,'max_job_ms':55000,'PL_lease_ms':500,'following_error_rad':.099,'velocity_trip_rad_s':.75,'stop_confirmation_ms':300}
result['current_cartesian_interface']['PL_changed']=False
result['stop_confirmation']['PL_changed']=False
result['tracking_margin']['PL_changed']=False
result['RTL_revalidated_this_revision']=0
result['RTL_regression_groups']=17
result['unchanged_transport_historical_groups']=3
result['PL_validation']='17 baseline groups and routed timing reports inherited; bound to unchanged source/BIT/XSA hashes. Project and routed implementation reopened in current delivery.'
result['ZIP_extracted_Vivado_project_and_implementation_reopen']='Prior recovery ZIP evidence retained; current schedule directory separately reopened; current ZIP checked by payload hashes'
result['hardware_read_only_DDR_diagnosis_performed']=True
result['hardware_access_this_revision']='saved-DDR read-only diagnosis on previous recovery ELF; no control commands'
result['last_user_reported_board_state']='Recovery ELF: sudden torque loss at frame191/293, fault_cause8, error11, stop unconfirmed; current physical support not confirmed in latest reply'
result['board_motion_fault_evidence']='reports/board_schedule_fault_20261104.json'
result['fault_diagnostics']='Timing trace distinguishes total deadline from dispatch stall; records observe/publish/service time in STATUS, diagnosis and pre-recovery archive. Original fault lacked timing evidence; specific late branch unproven.'
result['python_console_tests']=40
result['physical_calibration']='Prior operator calibration preserved in PC backup. ELF-only update may restore it only with motor zero relation unchanged; physical alignment not independently measured.'
result['manual_update']='Recover to verified disabled standby using old PS, close console, halt core0 and load only new ELF, RESTORE same-session PC record, explicit RESUME holds current pose. No automatic download or motion.'
overlay_path=root/'reports/id2_candidate_signoff.json'
if overlay_path.exists():
    overlay=json.loads(overlay_path.read_text())
    for item in overlay['files']:assert sha(root/item['path'])==item['sha256'],item['path']
    for path,digest in overlay['firmware_unchanged'].items():assert sha(root/path)==digest,path
    assert f"Ran {overlay['python_tests']} tests" in read_text_log(sw/'reports/id2_candidate_python_tests.log') and '\nOK' in read_text_log(sw/'reports/id2_candidate_python_tests.log')
    capture=json.loads((sw/'reports/config_home_capture_arm.json').read_text())
    assert capture['status']=='PASS_CONFIGURED_HOME_CAPTURE_ACTUAL_ARM_OFFLINE' and capture['ELF_sha256']==sha(elf)
    assert capture['old_capture_result']==20 and capture['new_capture_and_config_enables']==0 and capture['new_capture_and_config_motor_writes']==0
    result['host_mapping_candidate']=overlay
    result['python_console_tests']=overlay['python_tests']
    result['host_mapping_candidate_board_applied']=overlay.get('board_mapping_seen',False)
(root/'reports/workflow_signoff.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8');print(json.dumps(result,indent=2))
