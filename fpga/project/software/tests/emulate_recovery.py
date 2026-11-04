"""Actual ARM recovery/hold flow after legacy and Cartesian cases. Offline."""
from pathlib import Path
import hashlib,json,runpy,struct
ns=runpy.run_path(str(Path(__file__).with_name('emulate_cartesian.py')))
globals().update({k:ns[k] for k in ('root','setup','poll','request','words','symbols','fp','bits','cart','finish')})
results=[]
def passed(name,**details):
    results.append({'scenario':name,'passed':True,**details})
    print(json.dumps(results[-1]),flush=True)
def faulted():
    u,p,seq,_=setup('recover_nominal',rates=(.5,.5))
    record=bytes(u.mem_read(symbols['g_arm_calibration'][0],468))
    p.put(symbols['g_arm_stop'][0],1);poll(u)
    assert words(u,'g_arm_report')[2]==226
    return u,p,seq,record

u,p,seq,record=faulted()
# The arm has moved away from initial HOME while disabled. Recovery preserves
# mapping, and RESUME preloads this position rather than returning to HOME.
p.axes[5]['p']=bits(fp(p.axes[5]['p'])+.2)
current=[a['p'] for a in p.axes];enabled=p.enable_count;commits=len(p.commits)
before=len(p.command_log)
assert request(u,seq,109)[1]==0
assert words(u,'g_arm_report')[2:7]==(1,0,0,63,1)
assert words(u,'g_arm_report')[10]==1 and p.enable_count==enabled and not p.enabled
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==record
assert len(p.commits)==commits and all(((w>>8)&7)==0 for w,v in p.command_log[before:])
assert not words(u,'g_arm_cartesian')[5]
passed('RECOVER_stop_and_reads_only_retains_calibration',recovery_bursts=p.recovery_count)
assert request(u,seq,109)[1]==24 and p.recovery_count==1;seq+=1
assert request(u,seq,109)[1]==20 and p.recovery_count==1;seq+=1
passed('replayed_RECOVER_and_RECOVER_outside_fault_rejected')
assert request(u,seq,110)[1]==0;seq+=1
assert words(u,'g_arm_report')[2]==12 and p.enabled==63 and p.enable_count==enabled+6
assert [a['p'] for a in p.axes]==current and len(p.commits)==commits
assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==record
passed('RESUME_enables_current_pose_without_homing_or_recalibration')
assert request(u,seq,108)[1]==0
assert finish(u,p,3)[2]==3
saved_initial=struct.unpack_from('<6f',record,440)
assert all(abs(fp(p.axes[a]['p'])-saved_initial[a])<1e-6 for a in range(6))
passed('GOHOME_after_recovery_uses_original_saved_HOME')

for scenario in ('recover_stale','recover_fast','recover_running','recover_stop','recover_tx_fail'):
    u,p,seq,record=faulted();p.scenario=scenario;enables=p.enable_count;commits=len(p.commits)
    assert request(u,seq,109)[1]!=0
    assert words(u,'g_arm_report')[2]==226 and p.enable_count==enables and len(p.commits)==commits
    assert bytes(u.mem_read(symbols['g_arm_calibration'][0],468))==record
    assert request(u,seq+1,110)[1]!=0
    passed(scenario+'_cannot_resume_or_replay')

u,p,seq,record=faulted();p.reg[0x28]|=1<<24
assert request(u,seq,109)[1]!=0 and not p.recovery_count
passed('poisoned_mailbox_not_unlocked')
u,p,seq,record=faulted();p.auto_heartbeat=False;p.ticks+=333333*1100
assert request(u,seq,109)[1]!=0 and not p.recovery_count
passed('stale_host_cannot_recover')
u,p,seq,record=faulted();p.scenario='recover_offset'
assert request(u,seq,109)[1]==0 and words(u,'g_arm_report')[2:7]==(0,0,0,0,0)
assert request(u,seq+1,110)[1]!=0 and not p.enabled
passed('changed_motor_offset_invalidates_saved_calibration')
u,p,seq,record=faulted()
before=p.enable_count
assert request(u,seq,109,axis=1)[1]==22 and not p.recovery_count;seq+=1
assert request(u,seq,109,corrupt=True)[1]==22 and not p.recovery_count;seq+=1
assert request(u,seq,109)[1]==0;seq+=1
p.axes[2]['p']=bits(7.)
assert request(u,seq,110)[1]!=0 and p.enable_count==before
passed('malformed_recovery_and_out_of_range_resume_rejected')
out={'status':'PASS_ACTUAL_ARM_RECOVERY_OFFLINE_ONLY',
     'ELF_sha256':hashlib.sha256((root/'build/arm_workflow.elf').read_bytes()).hexdigest(),
     'cases':results,'hardware_access':False,'physical_calibration':'synthetic only'}
(root/'reports/arm_recovery_verification.json').write_text(json.dumps(out,indent=2)+'\n',encoding='utf-8')
print('PASS ARM RECOVERY',len(results),'SCENARIOS',flush=True)
