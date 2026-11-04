"""Pure offline golden checks; never import CAN/serial or open hardware.

The literal wire bytes and decoded answers were transcribed from the cited
manual field layouts. This reference uses byte operations/struct, not RTL logic.
Temporal acceptance and transaction matching are tested in XSim, not inferred here.
"""
import json
from pathlib import Path
import struct
import unittest


VECTORS = json.loads((Path(__file__).with_name('robstride_golden_vectors.json')).read_text())['vectors']


class GoldenTests(unittest.TestCase):
    def test_id_fields_and_complete_wire_payloads(self):
        for v in VECTORS:
            with self.subTest(v=v['name']):
                ident = int(v['id'], 16)
                data = bytes.fromhex(v['bytes'])
                self.assertEqual(len(data), 8)
                self.assertLess(ident, 1 << 29)
                self.assertEqual(ident >> 24, v['kind'])
                tx = v['kind'] == 18 or v.get('direction') == 'tx'
                self.assertEqual((ident >> (0 if tx else 8)) & 255, v['motor'])
                self.assertEqual((ident >> (8 if tx else 0)) & 255, v['host'])

    def test_ordinary_status_big_endian_unsigned(self):
        v = VECTORS[0]
        self.assertEqual(list(struct.unpack('>4H', bytes.fromhex(v['bytes']))), v['raw'])
        ident = int(v['id'], 16)
        self.assertEqual((ident >> 22) & 3, v['pattern'])
        self.assertEqual((ident >> 16) & 63, v['error'])

    def test_parameter_index_value_and_status(self):
        for v in VECTORS:
            if 'index' not in v:
                continue
            with self.subTest(v=v['name']):
                index, reserved, bits = struct.unpack('<HHI', bytes.fromhex(v['bytes']))
                self.assertEqual(index, v['index'])
                self.assertEqual(reserved, 0)
                self.assertEqual(bits, int(v['value_bits'], 16))
                if 'status' in v:
                    self.assertEqual((int(v['id'], 16) >> 16) & 255, v['status'])

    def test_full_fault_warning(self):
        v = next(v for v in VECTORS if v['kind'] == 21)
        fault, warning = struct.unpack('<II', bytes.fromhex(v['bytes']))
        self.assertEqual(fault, int(v['fault'], 16))
        self.assertEqual(warning, int(v['warning'], 16))
        self.assertTrue(fault & (1 << 31))
        self.assertTrue(warning & (1 << 31))

    def test_literal_axi_words(self):
        v = next(v for v in VECTORS if 'idr' in v)
        wire = bytes.fromhex(v['bytes'])
        self.assertEqual(int.from_bytes(wire[:4], 'big'), int(v['dw1'], 16))
        self.assertEqual(int.from_bytes(wire[4:], 'big'), int(v['dw2'], 16))
        idr = int(v['idr'], 16)
        self.assertTrue(idr & (1 << 19))
        self.assertFalse(idr & 1)
        self.assertEqual(((idr >> 21) << 18) | ((idr >> 1) & 0x3FFFF), int(v['id'], 16))

    def test_ieee754_examples(self):
        for name, value in [('write_speed_1', 1.0), ('write_position_minus1', -1.0),
                            ('write_speed_2', 2.0), ('write_position_0', 0.0)]:
            v = next(v for v in VECTORS if v['name'] == name)
            self.assertEqual(struct.unpack('<f', bytes.fromhex(v['bytes'])[4:])[0], value)


if __name__ == '__main__':
    unittest.main(verbosity=2)
