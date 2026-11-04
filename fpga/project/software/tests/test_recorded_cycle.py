"""Exercise sequence ordering, measured completion, cancellation and failures."""
import json
import struct
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
from workflow_protocol import load_record
from recorded_cycle import APPROACH, TRANSFER, RETURN, RecordedCycleRunner, CycleError, CyclePaused, CyclePlanRejected


class Rig:
    def __init__(self):
        self.record = load_record(Path(__file__).resolve().parents[1] / 'operator_logs/20261104_113335/calibration_latest.json')
        self.home = struct.unpack_from('<6f', self.record, 440)
        self.state = 3; self.position = self.target = self.home
        self.t = 0.; self.done_at = 0.; self.frames = self.done_frames = 0
        self.seq = 0; self.pulse = self.active_pulse = 1400; self.enabled = False
        self.grip_done_at = 0.; self.stops = 0; self.stop_flag = 0
        self.commands = []; self.pose = [0.] * 6; self.cart_seq = 0
        self.pause_at = None; self.fail_pose = None; self.expire_at = None; self.no_arrival = False
        self.cart_error = 0; self.fail_operation = 107; self.fail_state = None; self.changed_target = False
        self.fail_result = 2; self.fail_remaining = None; self.fail_feedback_velocity = 0.
        self.velocity = (0.,) * 6

    def sleep(self, seconds):
        self.t += seconds
        if self.state == 11 and self.t >= self.done_at and not self.no_arrival:
            self.state = self.final_state; self.position = self.target; self.done_frames = self.frames
        if self.t >= self.grip_done_at:
            self.active_pulse = self.pulse
        if self.pause_at is not None and self.t >= self.pause_at:
            self.state = 13

    def read(self, name, count):
        if name == 'g_arm_calibration': return self.record
        if name == 'g_arm_stop': return struct.pack('<I', self.stop_flag)
        if name == 'g_arm_report':
            return struct.pack('<12I18f', 0x57465231, 1, self.state, 0, 63, 63, 1,
                               self.done_frames, self.frames, 0, 0, 0,
                               *self.position, *self.velocity, *self.target)
        if name == 'g_arm_cartesian':
            return struct.pack('<10I26f', 0x43505231, 1, self.cart_seq, self.cart_error, 0, int(not self.cart_error), 10, 500, 1, 1,
                               *self.pose, *([0.] * 6), *([0.] * 6), *self.target, 0., 0.)
        if name == 'g_gripper_report':
            expired = self.expire_at is not None and self.t >= self.expire_at
            return struct.pack('<13I', 0x53525631, 1, self.seq, 0, 1, int(self.enabled and not expired),
                               int(self.active_pulse != self.pulse), int(expired), self.active_pulse,
                               self.pulse, 10, 5, int(self.t * 50))
        raise AssertionError(name)

    def submit(self, worker, sequence, operation, record=None):
        self.seq = sequence
        action = None
        if operation == 111:
            _, _, action, pulse, _, _ = struct.unpack_from('<6I', record)
            if action == 2:
                self.pulse = pulse; self.enabled = True; self.grip_done_at = self.t + .3
        elif operation in (106, 107, 108):
            if operation in (106, 107):
                self.pose = struct.unpack_from('<6f', record, 16); self.cart_seq = sequence
                if operation == self.fail_operation and self.fail_pose == tuple(self.pose) and self.fail_remaining != 0:
                    if self.fail_remaining is not None: self.fail_remaining -= 1
                    self.cart_error = self.fail_result
                    self.velocity = (self.fail_feedback_velocity,) * 6
                    if self.fail_state is not None: self.state = self.fail_state
                    if self.changed_target: self.target = tuple(x + .1 for x in self.target)
                    return sequence, self.fail_result, operation, 0
                self.cart_error = 0
            if operation != 106:
                self.state = 11; self.frames = 10; self.done_frames = 0; self.done_at = self.t + .5
                self.final_state = 12 if operation == 107 else 3
        self.commands.append((self.t, sequence, operation, action, self.pulse, tuple(self.pose)))
        return sequence, 0, operation, 0

    def stop(self):
        self.stops += 1; self.stop_flag = 1


class RecordedCycleTests(unittest.TestCase):
    def runner(self, rig, folder):
        return RecordedCycleRunner(rig, rig.submit, 20, folder, progress=lambda _: None,
                                   clock=lambda: rig.t, sleep=rig.sleep)

    def test_complete_order_arrival_delays_and_one_return(self):
        rig = Rig()
        with tempfile.TemporaryDirectory() as folder:
            runner = self.runner(rig, folder); runner.run()
            self.assertTrue(Path(folder, 'recorded_cycle.jsonl').exists())
        commands = [c for c in rig.commands if c[2] != 111 or c[3] == 2]
        self.assertEqual([c[4] for c in commands if c[2] == 111], [1110, 1490, 1110])
        self.assertEqual([c[5] for c in commands if c[2] == 107], [p.pose for p in APPROACH + TRANSFER + RETURN])
        self.assertEqual(sum(c[2] == 108 for c in commands), 1)
        self.assertEqual([c[1] for c in rig.commands], list(range(21, runner.sequence + 1)))
        events = runner.events
        dwells = [e for e in events if e['event'] == 'dwell_finished']
        self.assertEqual([e['seconds'] for e in dwells], [5., 3., 2.])
        self.assertTrue(all(e['elapsed_s'] >= e['seconds'] for e in dwells))
        pick = next(e for e in events if e['event'] == 'waypoint_arrived' and e['source_request'] == 54)
        high = next(e for e in events if e['event'] == 'waypoint_arrived' and tuple(e['pose']) == APPROACH[0].pose)
        pick_wait = next(e for e in events if e['event'] == 'dwell_started')
        close = next(e for e in events if e['event'] == 'gripper_requested' and e['pulse_us'] == 1490)
        self.assertLess(high['time_monotonic_s'],pick['time_monotonic_s'])
        self.assertGreaterEqual(pick_wait['time_monotonic_s'],pick['time_monotonic_s'])
        self.assertFalse(any(e['event']=='gripper_requested' and e['pulse_us']==1490 and e['time_monotonic_s']<pick['time_monotonic_s'] for e in events))
        self.assertGreaterEqual(close['time_monotonic_s'] - pick['time_monotonic_s'], 5.)
        delivered = next(e for e in events if e['event'] == 'waypoint_arrived' and e['source_request'] == 155)
        opened = [e for e in events if e['event'] == 'gripper_requested' and e['pulse_us'] == 1110][-1]
        self.assertGreaterEqual(opened['time_monotonic_s'] - delivered['time_monotonic_s'], 3.)
        open_reached = [e for e in events if e['event'] == 'gripper_pulse_reached' and e['pulse_us'] == 1110][-1]
        release_wait = [e for e in events if e['event'] == 'dwell_started'][-1]
        return_move = next(e for e in events if e['event'] == 'move_accepted' and e['phase'] == '返回初始位置')
        self.assertGreaterEqual(release_wait['time_monotonic_s'], open_reached['time_monotonic_s'])
        self.assertGreaterEqual(return_move['time_monotonic_s'] - open_reached['time_monotonic_s'], 2.)
        self.assertEqual(events[-1]['event'], 'cycle_completed')
        self.assertEqual(rig.state, 3); self.assertEqual(rig.active_pulse, 1110); self.assertEqual(rig.stops, 0)

    def test_initial_pose_required_without_any_actuation(self):
        rig = Rig(); rig.state = 12
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.commands, []); self.assertEqual(rig.stops, 0)

    def test_pending_stop_rejected_without_clearing_it(self):
        rig = Rig(); rig.stop_flag = 1
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.commands, []); self.assertEqual(rig.stop_flag, 1)

    def test_paused_hold_cancels_remaining_steps_and_preserves_hold(self):
        rig = Rig(); rig.pause_at = 1.
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePaused):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 0)
        self.assertFalse(any(c[2] == 111 and c[3] == 2 and c[4] == 1490 for c in rig.commands))

    def test_rejected_move_preserves_confirmed_hold_and_cancels_rest(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePlanRejected):
            runner = self.runner(rig, folder); runner.run()
        self.assertEqual(rig.stops, 0); self.assertEqual(rig.state, 3)
        self.assertEqual(runner.events[-1]['event'], 'cycle_rejected_hold')
        self.assertTrue(any(e['event'] == 'cartesian_reply' and e['report']['result'] == 2 for e in runner.events))
        self.assertFalse(any(c[2] == 108 for c in rig.commands))
        self.assertFalse(any(c[2] == 111 and c[3] == 2 and c[4] == 1490 for c in rig.commands))

    def test_rejected_preview_preserves_hold_without_open_or_motion(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePlanRejected):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 0); self.assertEqual(rig.commands, [])
        self.assertFalse(rig.enabled)

    def test_planning_error_with_fault_still_requests_stop(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_state = 226
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 1)

    def test_planning_error_with_changed_target_still_requests_stop(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.changed_target = True
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 1)

    def test_transient_not_stopped_waits_for_three_samples_then_completes(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106
        rig.fail_result = 6; rig.fail_remaining = 1
        with tempfile.TemporaryDirectory() as folder:
            runner = self.runner(rig, folder); runner.run()
        started = next(e for e in runner.events if e['event'] == 'settle_wait_started')
        ready = next(e for e in runner.events if e['event'] == 'settle_wait_ready')
        self.assertGreaterEqual(ready['time_monotonic_s'] - started['time_monotonic_s'], .3 - 1e-9)
        self.assertEqual(rig.stops, 0); self.assertEqual(runner.events[-1]['event'], 'cycle_completed')

    def test_rejected_not_stopped_move_rechecked_without_replaying_accepted_motion(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_result = 6; rig.fail_remaining = 1
        with tempfile.TemporaryDirectory() as folder:
            runner = self.runner(rig, folder); runner.run()
        self.assertEqual([c[5] for c in rig.commands if c[2] == 107], [p.pose for p in APPROACH + TRANSFER + RETURN])
        self.assertEqual(rig.stops, 0)

    def test_persistent_not_stopped_has_three_attempt_limit_and_keeps_hold(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106; rig.fail_result = 6
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePlanRejected):
            runner = self.runner(rig, folder); runner.run()
        self.assertEqual(sum(e['event'] == 'request' and e['operation'] == 106 for e in runner.events), 3)
        self.assertEqual(rig.stops, 0); self.assertFalse(rig.enabled)

    def test_unsettled_feedback_times_out_without_opening_or_changing_hold_target(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106; rig.fail_result = 6
        rig.fail_feedback_velocity = .04
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePlanRejected):
            runner = self.runner(rig, folder); runner.run()
        start=next(e['time_monotonic_s'] for e in runner.events if e['event']=='settle_wait_started')
        self.assertGreaterEqual(rig.t-start,5.);self.assertLess(rig.t-start,5.2)
        self.assertEqual(rig.stops, 0); self.assertFalse(rig.enabled)
        self.assertFalse(next(e for e in runner.events if e['event'] == 'plan_rejected_hold')['settled'])

    def test_fault_during_readiness_wait_still_requests_stop(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106; rig.fail_result = 6
        original_sleep = rig.sleep
        def fail_after_wait(seconds):
            original_sleep(seconds)
            if runner.started:rig.state = 226
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner = self.runner(rig, folder); runner.sleep = fail_after_wait; runner.run()
        self.assertEqual(rig.stops, 1)

    def test_velocity_above_safety_limit_is_not_treated_as_settling(self):
        rig = Rig(); rig.fail_pose = APPROACH[0].pose; rig.fail_operation = 106; rig.fail_result = 6
        rig.fail_feedback_velocity = 1.
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 1); self.assertFalse(rig.enabled)

    def test_disabled_gripper_aborts_during_travel(self):
        rig = Rig(); rig.expire_at = 1.
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            self.runner(rig, folder).run()
        self.assertEqual(rig.stops, 1)

    def test_no_arrival_does_not_start_pick_timer(self):
        rig = Rig(); rig.no_arrival = True
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner = self.runner(rig, folder); runner.run()
        self.assertEqual(rig.stops, 1)
        self.assertFalse(any(e['event'] == 'dwell_started' for e in runner.events))

    def test_descent_must_arrive_before_pick_wait_or_close(self):
        rig=Rig();submit=rig.submit
        def missing_descent(worker,sequence,operation,record=None):
            reply=submit(worker,sequence,operation,record=record)
            if operation==107 and tuple(rig.pose)==APPROACH[1].pose:rig.no_arrival=True
            return reply
        rig.submit=missing_descent
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner=self.runner(rig,folder);runner.run()
        self.assertTrue(any(e['event']=='waypoint_arrived' and tuple(e['pose'])==APPROACH[0].pose for e in runner.events))
        self.assertFalse(any(e['event']=='dwell_started' for e in runner.events))
        self.assertEqual([e['pulse_us'] for e in runner.events if e['event']=='gripper_requested'],[1110])
        self.assertEqual(rig.stops,1)

    def test_rejected_descent_cancels_before_pick_wait_or_close(self):
        rig=Rig();rig.fail_pose=APPROACH[1].pose
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CyclePlanRejected):
            runner=self.runner(rig,folder);runner.run()
        self.assertEqual(rig.state,12);self.assertEqual(rig.stops,0)
        self.assertFalse(any(e['event']=='dwell_started' for e in runner.events))
        self.assertEqual([e['pulse_us'] for e in runner.events if e['event']=='gripper_requested'],[1110])

    def test_ctrl_c_requests_stop_and_does_not_replay(self):
        rig = Rig()
        with tempfile.TemporaryDirectory() as folder:
            runner = self.runner(rig, folder)
            def interrupt(seconds):
                if runner.started: raise KeyboardInterrupt
                rig.sleep(seconds)
            runner.sleep = interrupt
            with self.assertRaises(KeyboardInterrupt): runner.run()
        self.assertEqual(rig.stops, 1)
        self.assertFalse(any(c[2] in (107,108) for c in rig.commands))

    def test_preflight_transient_velocity_waits_without_actuation(self):
        rig = Rig(); rig.velocity = (.04,) * 6
        original_sleep = rig.sleep
        def settle(seconds):
            self.assertEqual(rig.commands, [])
            original_sleep(seconds); rig.velocity = (0.,) * 6
        with tempfile.TemporaryDirectory() as folder:
            runner = self.runner(rig, folder); runner.sleep = settle; runner.preflight()
        self.assertGreaterEqual(rig.t, .3 - 1e-9)
        self.assertTrue(any(e['event'] == 'hold_not_ready' for e in runner.events))
        self.assertEqual(rig.stops, 0)

    def test_preflight_persistent_velocity_refuses_with_diagnostics_no_stop(self):
        rig = Rig(); rig.velocity = (.04,) * 6
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner = self.runner(rig, folder); runner.run()
        self.assertEqual(rig.commands, []); self.assertEqual(rig.stops, 0)
        self.assertGreaterEqual(rig.t, 5.)
        diagnostic=next(e for e in runner.events if e['event']=='hold_not_ready')
        self.assertIn('arrival_velocity_rad_s',diagnostic)

    def test_gripper_transient_velocity_does_not_drop_arm_torque(self):
        rig=Rig(); read=rig.read; injected=False
        def noisy_read(name,count):
            nonlocal injected
            if name=='g_arm_report' and rig.enabled and not injected:
                injected=True;rig.velocity=(.04,)*6
                data=read(name,count);rig.velocity=(0.,)*6;return data
            return read(name,count)
        rig.read=noisy_read
        with tempfile.TemporaryDirectory() as folder:self.runner(rig,folder).run()
        self.assertTrue(injected);self.assertEqual(rig.stops,0)

    def test_frequent_dwell_jitter_cannot_restart_timer_or_drop_torque(self):
        rig=Rig();read=rig.read;injected=0
        def noisy_read(name,count):
            nonlocal injected
            starts=[e for e in runner.events if e['event']=='dwell_started']
            finishes=[e for e in runner.events if e['event']=='dwell_finished']
            if name=='g_arm_report' and len(starts)>len(finishes) and int(rig.t*10)%4==0:
                injected+=1;rig.velocity=(.04,)*6
                data=read(name,count);rig.velocity=(0.,)*6;return data
            return read(name,count)
        rig.read=noisy_read
        with tempfile.TemporaryDirectory() as folder:
            runner=self.runner(rig,folder);runner.run()
        start=next(e for e in runner.events if e['event']=='dwell_started')
        waits=[e for e in runner.events if e['event']=='dwell_finished']
        close=next(e for e in runner.events if e['event']=='gripper_requested' and e['pulse_us']==1490)
        self.assertGreater(injected,5)
        self.assertTrue(all(w['seconds']<=w['elapsed_s']<w['seconds']+.1 for w in waits))
        self.assertGreaterEqual(close['time_monotonic_s']-start['time_monotonic_s'],5.)
        self.assertLess(close['time_monotonic_s']-start['time_monotonic_s'],5.4)
        self.assertFalse(any(e['event']=='dwell_restarted' for e in runner.events))
        self.assertEqual(rig.stops,0)

    def test_dwell_safety_violation_aborts_before_close(self):
        rig=Rig();read=rig.read
        def unsafe_read(name,count):
            if name=='g_arm_report' and any(e['event']=='dwell_started' for e in runner.events):
                rig.velocity=(1.,)*6
            return read(name,count)
        rig.read=unsafe_read
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner=self.runner(rig,folder);runner.run()
        self.assertEqual(rig.stops,1)
        self.assertFalse(any(e['event']=='gripper_requested' and e['pulse_us']==1490 for e in runner.events))

    def test_persistent_unsettled_after_dwell_cannot_close_or_wait_forever(self):
        rig=Rig();read=rig.read
        def unsettled_read(name,count):
            if name=='g_arm_report' and any(e['event']=='dwell_finished' for e in runner.events):
                rig.velocity=(.04,)*6
            return read(name,count)
        rig.read=unsettled_read
        with tempfile.TemporaryDirectory() as folder, self.assertRaises(CycleError):
            runner=self.runner(rig,folder);runner.run()
        end=next(e for e in runner.events if e['event']=='dwell_finished')
        self.assertLess(rig.t-end['time_monotonic_s'],5.2)
        self.assertEqual(rig.stops,1)
        self.assertFalse(any(e['event']=='gripper_requested' and e['pulse_us']==1490 for e in runner.events))

    def test_recorded_endpoints_and_generated_lifts_are_distinguished(self):
        path = Path(__file__).resolve().parents[1] / 'operator_logs/20261104_113335/requests.jsonl'
        index = {r['request']: r for r in map(json.loads, path.read_text(encoding='utf-8').splitlines())}
        for point in APPROACH + TRANSFER + RETURN:
            if point.request is None:continue
            row = index[point.request]
            self.assertEqual(row['reply'][1], 0); self.assertTrue(row['cartesian']['plan_valid'])
            self.assertEqual(tuple(map(float, row['parameters'])), point.pose)
        self.assertEqual([p.request for p in APPROACH+TRANSFER+RETURN],[None,54,53,155,None])
        self.assertEqual(APPROACH[0].pose,(180.,0.,190.,0.,-10.,0.))
        self.assertEqual(APPROACH[1].pose,(180.,0.,160.,0.,0.,0.))
        self.assertEqual(APPROACH[0].pose[2]-APPROACH[1].pose[2],30.)
        self.assertEqual(TRANSFER[0].pose,(180.,0.,170.,0.,0.,0.))
        self.assertEqual(RETURN[0].pose,(180.,-150.,200.,-60.,-90.,0.))


if __name__ == '__main__': unittest.main()
