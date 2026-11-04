"""Check the paired delivery, or explicitly download with --download.
Before download: support the arm, remove motor/servo power and close the old console.
"""
import argparse,hashlib,json,subprocess,zipfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def verify():
    signoff=json.loads((ROOT/'reports/gripper_signoff.json').read_text(encoding='utf-8'))
    if signoff.get('status')!='PASS_OFFLINE_ARM_GRIPPER':raise ValueError('Build has not passed final checks')
    for item in signoff['paired_files']:
        path=ROOT/item['path']
        if hashlib.sha256(path.read_bytes()).hexdigest()!=item['sha256']:raise ValueError('Pairing mismatch: '+str(path))
    symbols=json.loads((ROOT/'software/reports/workflow_symbols.json').read_text())
    if hashlib.sha256((ROOT/'software/build/arm_workflow.elf').read_bytes()).hexdigest()!=symbols['ELF_sha256']:raise ValueError('ELF/symbol pairing mismatch')
    with zipfile.ZipFile(ROOT/'bitstream/roboarm_arm_workflow.xsa') as z:
        names=[n for n in z.namelist() if n.endswith('.bit')]
        if len(names)!=1 or z.read(names[0])!=(ROOT/'bitstream/roboarm_arm_workflow.bit').read_bytes():raise ValueError('BIT/XSA pairing mismatch')
    return symbols['_start']['address']

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--download',action='store_true',help='Explicitly reset and download BIT/PS; all actuator power must be off')
    p.add_argument('--xsct',default='D:/Xilinx/Vitis/2023.1/bin/xsct.bat')
    args=p.parse_args();entry=verify();print('BIT/XSA/ELF/PS-init/console pairing PASS',flush=True)
    if not args.download:print('Offline check only. No hardware connection.');return
    print('Downloading; mechanical support and actuator power-off are required. No automatic motion.',flush=True)
    subprocess.run(['cmd.exe','/d','/c',args.xsct,str(ROOT/'software/tools/download_gripper.tcl'),str(ROOT),entry],check=True)

if __name__=='__main__':main()
