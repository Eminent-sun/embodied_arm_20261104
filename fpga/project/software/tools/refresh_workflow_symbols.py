"""Refresh console symbol addresses immediately after an ARM ELF build.

Offline only: reads the local ELF with arm-none-eabi-nm, never connects to XSCT.
"""
import argparse
import hashlib
import json
import re
import subprocess
from pathlib import Path

NAMES = (
    'g_gripper_report', '_start', 'compute_idle', 'workflow_runtime_poll', 'g_arm_request',
    'g_arm_reply', 'g_arm_report', 'g_arm_stop_trace', 'g_arm_calibration', 'g_arm_heartbeat',
    'g_arm_stop', 'g_arm_readback', 'g_initial_pose',
    'g_approved_path_geometry', 'workspace', 'g_arm_cartesian', 'g_arm_timing',
)
SIZES = {
    'g_gripper_report': 52,
    'g_arm_request': 836, 'g_arm_reply': 16, 'g_arm_report': 120,
    'g_arm_stop_trace': 112,
    'g_arm_timing': 64,
    'g_arm_cartesian': 144,
    'g_arm_calibration': 468, 'g_arm_heartbeat': 4, 'g_arm_stop': 4,
    'g_arm_readback': 144, 'g_initial_pose': 116,
    'g_approved_path_geometry': 19260, 'workspace': 122888,
}
ROW = re.compile(r'^([0-9A-Fa-f]+)(?:\s+([0-9A-Fa-f]+))?\s+([A-Za-z])\s+(\S+)$')


def refresh(elf: Path, nm: Path, output: Path):
    result = subprocess.run([str(nm), '-S', str(elf)], check=True,
                            capture_output=True, text=True)
    symbols = {}
    for line in result.stdout.splitlines():
        match = ROW.fullmatch(line.strip())
        if not match or match[4] not in NAMES:
            continue
        name = match[4]
        if name in symbols:
            raise ValueError(f'Duplicate ELF symbol: {name}')
        symbols[name] = {'address': hex(int(match[1], 16)),
                         'bytes': int(match[2], 16) if match[2] else 0}
    if set(symbols) != set(NAMES):
        raise ValueError(f'Missing ELF symbols: {sorted(set(NAMES) - set(symbols))}')
    for name, size in SIZES.items():
        if symbols[name]['bytes'] != size:
            raise ValueError(f'Unexpected {name} ABI size: {symbols[name]["bytes"]}')
    symbols['ELF_sha256'] = hashlib.sha256(elf.read_bytes()).hexdigest()
    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_name(output.name + '.tmp')
    temporary.write_text(json.dumps(symbols, indent=2) + '\n', encoding='utf-8')
    temporary.replace(output)
    return symbols


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('elf', type=Path)
    parser.add_argument('nm', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    data = refresh(args.elf, args.nm, args.output)
    print(f'ELF/symbol pairing refreshed: {data["ELF_sha256"]}')
