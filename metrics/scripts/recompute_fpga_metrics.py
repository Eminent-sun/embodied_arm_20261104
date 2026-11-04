"""Recompute the delivered frozen FPGA snapshot into a fresh output directory."""
import argparse, os, subprocess, sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--output',type=Path,required=True)
a=p.parse_args();out=a.output.resolve()
if out.exists():raise SystemExit('Output must be a new directory')
if out.is_relative_to(root):raise SystemExit('Use an output directory outside the delivery tree')
out.mkdir(parents=True)
env=dict(os.environ,FPGA_AUDIT_OUTPUT=str(out),PYTHONDONTWRITEBYTECODE='1',PYTHONUTF8='1')
for name in ['audit.py','supplement.py','make_report.py']:
    subprocess.run([sys.executable,str(root/'metrics/fpga/audit'/name)],env=env,check=True)
print('Recomputed frozen evidence in '+str(out))
