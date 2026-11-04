import importlib.util
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
import contextlib
import io
import json
import tempfile
import types

source = Path(__file__).resolve().parents[1] / "tools/recv_from_robstride_usbcan_periodic.py"
spec = importlib.util.spec_from_file_location("periodic_receiver", source)
receiver = importlib.util.module_from_spec(spec)
sys.modules[spec.name] = receiver
spec.loader.exec_module(receiver)


def packet(seq, can_id=0x1B345678, suffix=bytes.fromhex("11223344")):
    data = seq.to_bytes(4, "big") + suffix
    return b"AT" + ((can_id << 3) | 4).to_bytes(4, "big") + bytes([len(data)]) + data + b"\r\n"


class ReceiverTests(unittest.TestCase):
    def test_literal_wire_format(self):
        data = bytes.fromhex("41 54 D9 A2 B3 C4 08 00 00 03 E7 11 22 33 44 0D 0A")
        p = receiver.ATParser()
        frame = p.feed(data)[0]
        self.assertEqual(frame.can_id, 0x1B345678)
        self.assertEqual(int.from_bytes(frame.data[:4], "big"), 999)
        self.assertTrue(frame.extended_data)

    def test_all_fragment_boundaries(self):
        data = packet(256)
        for split in range(len(data) + 1):
            p = receiver.ATParser()
            frames = p.feed(data[:split]) + p.feed(data[split:])
            self.assertEqual(len(frames), 1)
            self.assertEqual(frames[0].data[:4], bytes.fromhex("00000100"))

    def test_coalescing_noise_and_header_split(self):
        p = receiver.ATParser()
        self.assertEqual(p.feed(b"garbageA"), [])
        frames = p.feed(packet(0)[1:] + packet(1) + packet(2))
        self.assertEqual(len(frames), 3)
        self.assertEqual(p.discarded_bytes, 7)

    def test_invalid_dlc_footer_and_recovery(self):
        p = receiver.ATParser()
        bad_dlc = b"AT" + bytes.fromhex("D9A2B3C4") + b"\x09"
        bad_tail = packet(4)[:-2] + b"XX"
        frames = p.feed(bad_dlc + bad_tail + packet(5))
        self.assertEqual(len(frames), 1)
        self.assertEqual(p.invalid_frames, 2)

    def test_truncated_packet_at_finish(self):
        p = receiver.ATParser()
        p.feed(packet(0)[:10])
        p.finish()
        self.assertEqual(p.invalid_frames, 1)
        self.assertFalse(p.buffer)

    def test_gaps_duplicates_and_late_arrivals(self):
        p = receiver.ATParser()
        s = receiver.Statistics(5)
        for f in p.feed(packet(0) + packet(2) + packet(2) + packet(1) + packet(4)):
            s.observe(f)
        r = s.report(p, 2, "test")
        self.assertEqual(r["missing_sequences"], 1)
        self.assertEqual(r["missing_sequence_sample"], [3])
        self.assertEqual(r["duplicate_sequences"], 1)
        self.assertEqual(r["out_of_order_sequences"], 1)
        self.assertEqual(r["average_receive_rate"], 2.5)

    def test_bad_payload_other_id_bad_dlc_out_of_range(self):
        p = receiver.ATParser()
        s = receiver.Statistics(2)
        frames = p.feed(packet(0, suffix=b"xxxx") + packet(1, can_id=3) + packet(99))
        for f in frames:
            s.observe(f)
        s.observe(receiver.Frame((0x1B345678 << 3) | 4, b"\x00"))
        self.assertEqual(s.total_frames, 4)
        self.assertEqual(s.expected_id_frames, 3)
        self.assertEqual(s.payload_errors, 2)
        self.assertEqual(s.out_of_range_sequences, 1)
        self.assertFalse(s.complete)

    def test_duplicates_cannot_complete_expected_count(self):
        p = receiver.ATParser()
        s = receiver.Statistics(3)
        for f in p.feed(packet(0) + packet(0) + packet(1)):
            s.observe(f)
        self.assertEqual(s.matched_frames, 3)
        self.assertFalse(s.complete)

    def test_rate_excludes_manual_wait_before_first_frame(self):
        p = receiver.ATParser()
        s = receiver.Statistics(3)
        for seq, stamp in enumerate([100.0, 100.01, 100.02]):
            s.observe(p.feed(packet(seq))[0], stamp)
        self.assertAlmostEqual(s.report(p, 20, "test")["average_receive_rate"], 100)

    def test_cli_writes_csv_raw_and_json_without_transmitting(self):
        class FakeSerial:
            def __init__(self, **kwargs):
                self.chunks = [packet(0)[:3], packet(0)[3:] + packet(1) + packet(2)]
                self.settings = kwargs

            @property
            def in_waiting(self):
                return len(self.chunks[0]) if self.chunks else 0

            def open(self):
                pass

            def close(self):
                pass

            def read(self, count):
                return self.chunks.pop(0) if self.chunks else b""

            def write(self, data):
                raise AssertionError("Receive-only program must never transmit")

        fake = types.SimpleNamespace(Serial=FakeSerial, EIGHTBITS=8, PARITY_NONE="N",
                                     STOPBITS_ONE=1, SerialException=OSError)
        with tempfile.TemporaryDirectory() as directory:
            with patch.dict(sys.modules, {"serial": fake}), contextlib.redirect_stdout(io.StringIO()):
                code = receiver.main(["--port", "OFFLINE_FAKE", "--expected-count", "3", "--output-dir", directory])
            self.assertEqual(code, 0)
            files = list(Path(directory).iterdir())
            raw = next(p for p in files if p.suffix == ".bin")
            log = next(p for p in files if p.suffix == ".csv")
            report = json.loads(next(p for p in files if p.suffix == ".json").read_text())
            self.assertEqual(raw.read_bytes(), packet(0) + packet(1) + packet(2))
            self.assertEqual(len(log.read_text().splitlines()), 4)
            self.assertEqual(report["matched_frames"], 3)
            self.assertEqual(report["result"], "PASS")

    def test_complete_360000_sequence_run_with_fragmentation(self):
        p = receiver.ATParser()
        s = receiver.Statistics(360000)
        for start in range(0, 360000, 128):
            chunk = b"".join(packet(n) for n in range(start, min(start + 128, 360000)))
            for f in p.feed(chunk[:13]) + p.feed(chunk[13:]):
                s.observe(f)
        r = s.report(p, 3600, "test")
        self.assertTrue(s.complete)
        self.assertEqual(r["matched_frames"], 360000)
        self.assertEqual(r["missing_sequences"], 0)
        self.assertEqual(r["average_receive_rate"], 100)
        self.assertEqual(r["result"], "PASS")


if __name__ == "__main__":
    unittest.main(verbosity=2)
