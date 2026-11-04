"""Actual ARM scheduler regression with synthetic CAN transaction delays; no hardware."""
from pathlib import Path
import hashlib,json,runpy,struct

ns=runpy.run_path(str(Path(__file__).with_name('emulate_recovery.py')))
globals().update({k:ns[k] for k in ('root','setup','poll','request','words','symbols','fp','bits','cart','finish')})
base=ns['ns']['ns']
results=[]
target=[200,0,100,0,-45,0]

def passed(name,**details):
    results.append({'scenario':name,'passed':True,**details})
    print(json.dumps(results[-1]),flush=True)

def delayed_motion(delay):
    u,p,seq,_=setup('schedule_nominal',rates=(.5,.5))
    assert cart(u,seq,107,target)[0][1]==0
    command=p.command
    def slow_command():
        p.ticks+=int(333333*delay)
        command()
    p.command=slow_command
    return u,p,seq+1

def advance(u,p,until=None):
    samples=[];previous=None
    for _ in range(16000):
        before=words(u,'g_arm_report')[7]
        p.ticks+=333333*20;poll(u)
        report=words(u,'g_arm_report');timing=words(u,'g_arm_timing')
        if report[7]!=before:
            assert report[7]==before+1,('skipped/burst sample',before,report[7])
            assert timing[:2]==(0x54494d31,1) and timing[13:15]==(1,50)
            started=timing[10]-timing[8]
            if previous is not None:assert started>=previous+50,(started,previous)
            samples.append({'frame':report[7],'start_ms':started,'complete_ms':timing[10],
                            'observe_ms':timing[6],'publish_ms':timing[7],'service_ms':timing[8]})
            previous=timing[10]
        if report[2]!=11 or (until and report[7]>=until):return report,timing,samples
    raise AssertionError('virtual scheduling loop did not finish')

u,p,seq=delayed_motion(3)
record=bytes(u.mem_read(symbols['g_arm_calibration'][0],468))
report,timing,trace=advance(u,p)
assert report[2]==12 and report[7:9]==(293,293) and p.enabled==63 and p.hold
assert timing[9]>50 and timing[12]==0 and timing[3]<55000
assert [c[1] for c in p.commits]==list(range(1,len(p.commits)+1))
assert len(trace)==293 and len(p.commits)>=293
# Arrival verification republishes the final target until three settled reads.
assert all(c[2:]==p.commits[292][2:] for c in p.commits[293:])
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==record
assert all(abs(fp(p.axes[a]['p'])-p.commits[-1][a+2])<1e-6 for a in range(6))
passed('serial_service_over_sample_period_all_293_frames_complete_without_catchup',
       injected_delay_per_transaction_ms=3,max_service_ms=timing[9],actual_virtual_elapsed_ms=timing[3],nominal_plan_ms=14600)
(root/'reports/arm_schedule_trace.json').write_text(json.dumps(trace,indent=2)+'\n',encoding='utf-8')

assert request(u,seq,108)[1]==0
report,timing,_=advance(u,p)
assert report[2]==3 and p.enabled==63 and timing[13]==1
initial=struct.unpack_from('<6f',record,440)
assert all(abs(fp(p.axes[a]['p'])-initial[a])<1e-6 for a in range(6))
passed('GOHOME_uses_same_completion_spacing_and_saved_HOME')

u,p,seq=delayed_motion(3)
advance(u,p,until=3);before=len(p.commits)
p.ticks+=333333*200;poll(u)
report=words(u,'g_arm_report');timing=words(u,'g_arm_timing')
assert report[2]==13 and report[11]==0 and timing[12]==2 and timing[5]>100
assert len(p.commits)==before and p.enabled==63 and p.hold
passed('real_dispatch_stall_pauses_holding_without_next_commit',lateness_ms=timing[5],timing_reason=timing[12])

u,p,seq=delayed_motion(8)
report,timing,_=advance(u,p)
assert report[2]==226 and report[11]==8 and timing[12]==1
assert report[7]<293 and timing[3]>55000 and not p.enabled
passed('total_55_second_limit_retained',frames=report[7],elapsed_ms=timing[3],timing_reason=timing[12])

for kind in ('STOP','host_loss'):
    u,p,seq=delayed_motion(3);advance(u,p,until=5);before=len(p.commits)
    if kind=='STOP':p.put(symbols['g_arm_stop'][0],1)
    else:p.auto_heartbeat=False;p.ticks+=333333*1100
    poll(u)
    assert words(u,'g_arm_report')[2]==226 and len(p.commits)==before and not p.enabled
    passed(kind+'_during_slow_serial_groups_prevents_next_target')

u,p,seq,_=setup('recover_nominal',rates=(.5,.5))
record=bytes(u.mem_read(symbols['g_arm_calibration'][0],468))
p.ticks+=333333*100;poll(u)
p.put(symbols['g_arm_stop'][0],1);poll(u)
assert request(u,seq,109)[1]==0;seq+=1
before=p.ms()
assert request(u,seq,110)[1]==0 and p.ms()>before
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==record
passed('RESUME_after_RECOVER_keeps_timer_monotonic_and_calibration')

cold=base['new_cpu']();base['run_to_idle'](cold,base['entry'])
# RESTORE touches only DDR: no virtual peripheral maps exist yet.
assert request(cold,1,101,record=record)[1]==0
plant=base['Plant'](cold,'fresh_resume')
plant.axes[5]['p']=bits(fp(plant.axes[5]['p'])+.2)
positions=[a['p'] for a in plant.axes]
assert request(cold,2,110)[1]==0
assert words(cold,'g_arm_report')[2]==12 and plant.enabled==63
assert [a['p'] for a in plant.axes]==positions and not plant.commits
assert bytes(cold.mem_read(symbols['g_arm_calibration'][0],468))==record
passed('fresh_ELF_RESTORE_then_RESUME_initializes_IO_and_holds_current_pose')
assert request(cold,3,108)[1]==0 and finish(cold,plant,3)[2]==3
initial=struct.unpack_from('<6f',record,440)
assert all(abs(fp(plant.axes[a]['p'])-initial[a])<1e-6 for a in range(6))
passed('fresh_ELF_restore_retains_original_GO_HOME')

out={'status':'PASS_ACTUAL_ARM_SCHEDULE_OFFLINE_ONLY',
     'ELF_sha256':hashlib.sha256((root/'build/arm_workflow.elf').read_bytes()).hexdigest(),
     'cases':results,'hardware_access':False,
     'scope':'Synthetic transaction delay and ideal motor tracking. Not a measured hardware timing or dynamics model.'}
(root/'reports/arm_schedule_verification.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('PASS ARM SCHEDULE',len(results),'SCENARIOS',flush=True)
