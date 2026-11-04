"""Extract PS initialization files from this delivery's XSA, offline only."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parents[1]
output=root/'bitstream/ps_init'
output.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(root/'bitstream/roboarm_arm_workflow.xsa') as archive:
    for name in ('ps7_init.tcl','ps7_init.c','ps7_init.h','can_test.hwh'):
        (output/name).write_bytes(archive.read(name))
print('Matching PS init/HWH extracted from delivery XSA; no hardware access.')
