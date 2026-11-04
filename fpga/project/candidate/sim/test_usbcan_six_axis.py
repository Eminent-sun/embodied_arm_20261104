"""Offline parser/statistics/CLI tests. No serial device is opened."""
import contextlib
import io
import json
from pathlib import Path
import tempfile
import types
import unittest
from unittest.mock import patch

from tools import recv_robstride_six_axis as receiver


def packet(seq, axis, payload_axis=None, suffix=b'\xA5\x5A\xC3', flags=4):
    data = seq.to_bytes(4, 'big') + bytes([axis if payload_axis is None else payload_axis]) + suffix
    return b'AT' + (((0x1B345670 + axis) << 3) | flags).to_bytes(4, 'big') + bytes([len(data)]) + data + b'\r\n'


def run_stats(count, data):
    parser, stats = receiver.ATParser(), receiver.Statistics(count)
    for frame in parser.feed(data):
        stats.observe(frame)
    return parser, stats


class SixAxisTests(unittest.TestCase):
    def test_literal_packed_id_big_endian(self):
        wire = bytes.fromhex('41 54 D9 A2 B3 AC 08 00 00 01 00 05 A5 5A C3 0D 0A')
        p, s = run_stats(1000, wire)
        self.assertEqual(s.good_seen, {(256, 5)})
        self.assertEqual(s.report(p, 1, 'test')['per_axis_missing']['Axis5'], 999)

    def test_all_fragment_boundaries(self):
        wire = packet(0, 0) + packet(0, 1)
        for split in range(len(wire) + 1):
            p = receiver.ATParser()
            self.assertEqual(len(p.feed(wire[:split]) + p.feed(wire[split:])), 2)

    def test_100_and_1000_complete_cycles_with_noise_and_fragmentation(self):
        for count in (100, 1000):
            wire = b''.join(packet(seq, axis) for seq in range(count) for axis in range(6))
            p, s = receiver.ATParser(), receiver.Statistics(count)
            p.feed(b'noiseA')
            for start in range(0, len(wire), 127):
                for f in p.feed(wire[start:start + 127]):
                    s.observe(f)
            p.finish()
            r = s.report(p, 10, 'test')
            self.assertEqual(r['result'], 'PASS')
            self.assertEqual(r['unique_good_frames'], count * 6)
            self.assertEqual(r['complete_cycles'], count)
            self.assertEqual(r['missing_frames'], 0)
            self.assertEqual(r['per_axis_missing'], {f'Axis{i}': 0 for i in range(6)})

    def test_per_axis_loss_and_cycle_completeness(self):
        wire = b''.join(packet(seq, axis) for seq in range(3) for axis in range(6) if (seq, axis) not in {(1, 2), (2, 5)})
        p, s = run_stats(3, wire)
        r = s.report(p, 1, 'test')
        self.assertEqual((r['complete_cycles'], r['partial_cycles'], r['incomplete_cycles']), (1, 2, 2))
        self.assertEqual(r['per_axis_missing']['Axis2'], 1)
        self.assertEqual(r['per_axis_missing_cycle_sample']['Axis5'], [2])
        self.assertEqual(r['missing_frames'], 2)
        self.assertEqual(r['result'], 'FAIL')

    def test_whole_cycle_absent(self):
        p, s = run_stats(3, b''.join(packet(seq, axis) for seq in (0, 2) for axis in range(6)))
        self.assertEqual(s.report(p, 1, 'test')['incomplete_cycle_sample'], [1])

    def test_duplicate_does_not_complete(self):
        p, s = run_stats(1, packet(0, 0) * 6)
        self.assertFalse(s.complete)
        self.assertEqual(s.duplicate_frames, 5)
        self.assertEqual(s.report(p, 1, 'test')['missing_frames'], 5)

    def test_out_of_order_axis(self):
        p, s = run_stats(1, b''.join(packet(0, a) for a in (0, 2, 1, 3, 4, 5)))
        self.assertTrue(s.complete)
        self.assertEqual(s.out_of_order_frames, 1)
        self.assertEqual(s.report(p, 1, 'test')['result'], 'FAIL')

    def test_out_of_order_cycle(self):
        p, s = run_stats(2, b''.join(packet(seq, a) for seq in (1, 0) for a in range(6)))
        self.assertEqual(s.out_of_order_frames, 6)
        self.assertTrue(s.complete)

    def test_axis_payload_mismatch_stays_missing(self):
        p, s = run_stats(1, packet(0, 3, payload_axis=2))
        r = s.report(p, 1, 'test')
        self.assertEqual(r['payload_errors'], 1)
        self.assertEqual(r['per_axis_missing']['Axis3'], 1)
        self.assertEqual(r['unique_good_frames'], 0)

    def test_corrupt_suffix_stays_missing(self):
        p, s = run_stats(1, packet(0, 0, suffix=b'BAD'))
        self.assertEqual(s.report(p, 1, 'test')['missing_frames'], 6)
        self.assertEqual(s.payload_errors, 1)

    def test_out_of_range_sequence_never_completes(self):
        p, s = run_stats(1, packet(1, 0))
        self.assertEqual(s.out_of_range_cycles, 1)
        self.assertFalse(s.complete)

    def test_wrong_format_and_dlc(self):
        p, s = run_stats(1, packet(0, 0, flags=0))
        s.observe(receiver.Frame(((0x1B345670 << 3) | 4), b'\x00'))
        self.assertEqual(s.invalid_format_frames, 1)
        self.assertEqual(s.payload_errors, 1)
        self.assertFalse(s.complete)

    def test_unrelated_id_is_counted_separately(self):
        p, s = run_stats(1, packet(0, 7) + b''.join(packet(0, a) for a in range(6)))
        self.assertEqual(s.other_id_frames, 1)
        self.assertEqual(s.report(p, 1, 'test')['result'], 'PASS')

    def test_invalid_serial_packet_and_truncation(self):
        p = receiver.ATParser()
        p.feed(b'AT' + bytes.fromhex('D9A2B38409'))
        p.feed(packet(0, 0)[:-2] + b'XX' + packet(0, 1)[:10])
        p.finish()
        self.assertGreaterEqual(p.invalid_frames, 3)

    def test_receive_rate_excludes_initial_manual_wait(self):
        p, s = receiver.ATParser(), receiver.Statistics(1)
        for axis in range(6):
            s.observe(p.feed(packet(0, axis))[0], 100 + axis / 600)
        r = s.report(p, 120, 'test')
        self.assertAlmostEqual(r['average_receive_rate'], 600)
        self.assertIn('do not measure', r['timestamp_note'])

    def test_cli_100_and_1000_csv_bin_json_without_transmitting(self):
        for count in (100, 1000):
            wire = b''.join(packet(seq, axis) for seq in range(count) for axis in range(6))
            class FakeSerial:
                def __init__(self, **kwargs):
                    self.chunks = [wire[i:i + 4093] for i in range(0, len(wire), 4093)]
                @property
                def in_waiting(self):
                    return len(self.chunks[0]) if self.chunks else 0
                def open(self):
                    pass
                def close(self):
                    pass
                def read(self, size):
                    return self.chunks.pop(0) if self.chunks else b''
                def write(self, data):
                    raise AssertionError('Receive-only script must never transmit')
            fake = types.SimpleNamespace(Serial=FakeSerial, EIGHTBITS=8, PARITY_NONE='N', STOPBITS_ONE=1, SerialException=OSError)
            with tempfile.TemporaryDirectory() as directory, patch.dict('sys.modules', {'serial': fake}), contextlib.redirect_stdout(io.StringIO()):
                result = receiver.main(['--port', 'OFFLINE_FAKE', '--expected-cycles', str(count), '--output-dir', directory])
                files = list(Path(directory).iterdir())
                report = json.loads(next(p for p in files if p.suffix == '.json').read_text())
                self.assertEqual(result, 0)
                self.assertEqual(report['complete_cycles'], count)
                self.assertEqual(next(p for p in files if p.suffix == '.bin').read_bytes(), wire)
                self.assertEqual(len(next(p for p in files if p.suffix == '.csv').read_text().splitlines()), 1 + 6 * count)

    def test_receive_timeout_is_bounded_and_reports_incomplete(self):
        class NoDataSerial:
            def __init__(self, **kwargs):
                pass
            in_waiting = 0
            def open(self):
                pass
            def close(self):
                pass
            def read(self, size):
                return b''
        fake = types.SimpleNamespace(Serial=NoDataSerial, EIGHTBITS=8, PARITY_NONE='N', STOPBITS_ONE=1, SerialException=OSError)
        with tempfile.TemporaryDirectory() as directory, patch.dict('sys.modules', {'serial': fake}), contextlib.redirect_stdout(io.StringIO()):
            with patch.object(receiver.time, 'monotonic', side_effect=range(100)):
                code = receiver.main(['--port', 'OFFLINE_FAKE', '--expected-cycles', '100', '--timeout', '1', '--output-dir', directory])
            report = json.loads(next(Path(directory).glob('*.json')).read_text())
            self.assertEqual(code, 1)
            self.assertEqual(report['end_reason'], 'inactivity_timeout')
            self.assertEqual(report['missing_frames'], 600)


if __name__ == '__main__':
    unittest.main()
