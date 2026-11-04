"""Verify local output pairing and offline evidence; never accesses hardware."""
from pathlib import Path
import hashlib,json,re,zipfile
ROOT=Path(__file__).resolve().parents[1]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def entry(path):return {'path':path.relative_to(ROOT).as_posix(),'sha256':sha(path)}
def read(path):
    data=(ROOT/path).read_bytes()
    return data.decode('utf-16' if data[:2] in (b'\xff\xfe',b'\xfe\xff') else 'utf-8-sig')

def main():
    elf=ROOT/'software/build/arm_workflow.elf';elfsha=sha(elf)
    symbols=json.loads(read('software/reports/workflow_symbols.json'))
    assert symbols['ELF_sha256']==elfsha and symbols['g_gripper_report']['bytes']==52
    build=json.loads(read('software/reports/workflow_build_inputs.json'))
    assert build['ELF_sha256']==elfsha
    for item in build['sources']:assert sha(ROOT/'software'/item['path'])==item['sha256'],item['path']
    cases={}
    for report in ('gripper_arm_tests','dispatch_hold_arm'):
        data=json.loads(read('software/reports/'+report+'.json'))
        assert data['ELF_sha256']==elfsha and all(c['passed'] for c in data['cases'])
        cases[report]=len(data['cases'])
    assert cases=={'gripper_arm_tests':14,'dispatch_hold_arm':17}
    cycle=json.loads(read('software/reports/recorded_cycle_arm_path.json'))
    assert cycle['status']=='PASS_ACTUAL_ARM_RECORDED_CYCLE_OFFLINE'
    assert cycle['ELF_sha256']==elfsha
    prior=json.loads(read('history/before_settle_wait_fix_20261104/reports/gripper_signoff.json'))
    assert elfsha==next(item['sha256'] for item in prior['paired_files'] if item['path']=='software/build/arm_workflow.elf')
    assert cycle['runner_sha256']==sha(ROOT/'software/tools/recorded_cycle.py')
    assert cycle['log_sha256']==sha(ROOT/'software/operator_logs/20261104_113335/requests.jsonl')
    assert len(cycle['segments'])==6 and cycle['hardware_access'] is False
    assert cycle['segments'][0]['pose']==[180.,0.,190.,0.,-10.,0.]
    assert cycle['segments'][1]['pose']==[180.,0.,160.,0.,0.,0.]
    assert cycle['pickup_approach_raise_mm']==30 and cycle['pickup_wait_after_descent'] is True
    assert cycle['descent_monotonic_z_tested'] is True and cycle['descent_max_lateral_deviation_mm']<1.
    assert [w['seconds'] for w in cycle['waits']]==[5.,3.,2.]
    assert all(w['elapsed_s']>=w['seconds'] for w in cycle['waits'])
    assert cycle['gripper_targets_us']==[1110,1490,1110] and cycle['final_state']=='INITIAL_HOLD'
    assert cycle['calibration_fixture']=='operator_logs/20261104_130107/calibration_latest.json'
    assert cycle['initial_feedback_motor_offset_rad']=={'3':-.0004,'5':-.0004}
    assert [r['operation'] for r in cycle['readiness_rejected_requests']]==[106,107]
    assert all(r['result']==6 and r['no_motion_committed'] for r in cycle['readiness_rejected_requests'])
    assert cycle['preflight_transient_velocity_tested'] is True
    assert cycle['fixed_deadline_dwell_jitter_tested'] is True and cycle['dwell_jitter_samples']>1
    assert cycle['waits'][0]['elapsed_s']<5.2 and cycle['waits'][0]['jitter_samples']>1
    assert all(s['path_xyz_min_mm'][2]>=159.5 for s in cycle['segments'])
    start=json.loads(read('software/reports/recorded_start_reproduction.json'))
    assert start['status']=='PASS_ACTUAL_ARM_START_BOUNDARY_AND_REJECTION_HOLD'
    assert start['ELF_sha256']==elfsha and start['runner_sha256']==cycle['runner_sha256']
    assert start['calibration_fixture_sha256']==cycle['calibration_fixture_sha256']
    assert len(start['cases'])==9 and start['hardware_access'] is False
    assert all(c['state']==3 and c['reply'][1]==(2 if c['motor_delta_rad']<-.001 else 0) for c in start['cases'][:7])
    assert all(c['hold_preserved'] and c['stop_writes']==0 and c['passed'] for c in start['cases'][7:])
    assert 'PASS CARTESIAN 5605 CHECKS' in read('software/reports/cartesian_host_tests.log')
    python=read('reports/python_tests.log');assert re.search(r'\nOK\s*$',python)
    python_count=int(re.search(r'Ran (\d+) tests',python)[1]);assert python_count>=104
    assert 'PASS WORKFLOW 68 CHECKS' in read('reports/workflow_host_run.log')
    sim=read('simulation/servo/run.log');assert 'SERVO_AXI_PASS' in sim and not re.search(r'FAIL|Fatal:|ERROR:',sim)
    sim_count=int(re.search(r'SERVO_AXI_PASS checks=(\d+)',sim)[1])
    logs=read('reports/limits_1110_1490_build.log')
    assert 'NODEBUG_CORE_COUNT=0 NO_LTX_REQUIRED' in logs
    matches=re.findall(r'ROUTED_WNS=([-\d.]+) ROUTED_WHS=([-\d.]+)',logs)
    wns,whs=map(float,matches[-1]);assert wns>=0 and whs>=0
    assert 'DRC_ERROR_COUNT=0' in logs
    if (ROOT/'reports/implemented_io.log').exists():
        assert 'GRIPPER_IMPLEMENTED_IO_PASS servo_pwm=W19 CAN_TX=F17 CAN_RX=F16' in read('reports/implemented_io.log')
    slices=int(re.findall(r'ROUTED_SLICE=(\d+)',logs)[-1]);assert slices<=4400
    bd=json.loads(read('candidate/roboarm.srcs/sources_1/bd/can_test/can_test.bd'))['design']
    seg=bd['addressing']['/processing_system7_0']['address_spaces']['Data']['segments']
    assert seg['SEG_pl_motion_mailbox_reg0']['offset']=='0x40000000'
    assert seg['SEG_pl_servo_axi_reg0']['offset']=='0x40001000'
    assert bd['components']['pl_motion_mailbox']['parameters']['ABI_VERSION']['value']=='0x00020009'
    assert bd['addressing']['/pl_can_reader']['address_spaces']['M_AXI']['segments']['SEG_pl_servo_axi_reg0']['is_excluded']=='TRUE'
    with zipfile.ZipFile(ROOT/'bitstream/roboarm_arm_workflow.xsa') as z:
        bits=[n for n in z.namelist() if n.endswith('.bit')];assert len(bits)==1
        assert z.read(bits[0])==(ROOT/'bitstream/roboarm_arm_workflow.bit').read_bytes()
        assert z.read('ps7_init.tcl')==(ROOT/'bitstream/ps_init/ps7_init.tcl').read_bytes()
        hwh=z.read('can_test.hwh').decode();assert 'pl_servo_axi' in hwh and '0x40001000' in hwh
    preservation=json.loads(read('reports/motor_preservation.json'))
    assert preservation['all_original_motor_RTL_unchanged'] and preservation['motion_core_unchanged'] is False
    for item in preservation['preserved_files']:assert sha(ROOT/item['path'])==item['sha256']
    reviewed=preservation['reviewed_motion_changes'];assert len(reviewed)==1
    assert reviewed[0]['path']=='software/src/workflow_plan.c'
    assert sha(ROOT/reviewed[0]['path'])==reviewed[0]['sha256']
    assert sha(ROOT/reviewed[0]['baseline_copy'])==reviewed[0]['baseline_sha256']
    paths=[ROOT/'bitstream/roboarm_arm_workflow.bit',ROOT/'bitstream/roboarm_arm_workflow.xsa',
           ROOT/'bitstream/ps_init/ps7_init.tcl',elf,ROOT/'software/reports/workflow_symbols.json']
    paths+=sorted((ROOT/'software/tools').glob('*.py'))+sorted((ROOT/'software/tools').glob('*.tcl'))
    result={'status':'PASS_OFFLINE_ARM_GRIPPER','hardware_access':False,'physical_servo_tested':False,
      'BIT_requires_first_download':True,'pulse_limits_us':[1110,1490],'mailbox_ABI':'0x00020009','servo_AXI_base':'0x40001000','servo_pin':'W19 (J10 pin3)',
      'timing':{'WNS_ns':wns,'WHS_ns':whs,'slices':slices,'DRC_errors':0,'debug_cores':0},
      'validated_sources':[entry(ROOT/p) for p in ('candidate/rtl/pl_servo_axi.v','candidate/sim/tb_servo_axi.sv','software/src/gripper.c','software/tests/verify_gripper_arm.py','software/tests/test_gripper_protocol.py','software/tools/recorded_cycle.py','software/tests/test_recorded_cycle.py','software/tests/verify_recorded_cycle_arm.py','software/src/workflow_plan.c','software/tests/cartesian_tests.c','software/tests/probe_recorded_start.py')],
      'requires_software_reload_for_runpath_fix':False,'runpath_module_reloaded_per_explicit_cycle':True,
      'settle_wait_update_PC_only':True,'PS_ELF_changed_from_boundary_fix':False,
      'tests':{'PWM_AXI_assertions':sim_count,'python_tests':python_count,'host_workflow_checks':68,'cartesian_host_checks':5605,'start_boundary_and_rejected_hold_cases':9,'readiness_transient_ARM_rejections':2,'fixed_deadline_dwell_jitter':True,'recorded_cycle_segments':6,'pickup_approach_raise_mm':30,**cases},
      'motor_preservation':preservation,'paired_files':[entry(p) for p in paths],
      'limitations':['Offline simulation and implementation only; physical torque/arrival/grasp not measured.',
                     'PWM status is command output, not physical position feedback.',
                     'Existing CAN IP/reset and asynchronous external I/O timing warnings remain in full reports.']}
    (ROOT/'reports/gripper_signoff.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'status':result['status'],'timing':result['timing'],'tests':result['tests']},indent=2))

if __name__=='__main__':main()
