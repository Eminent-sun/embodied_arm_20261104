"""Request CRC and permanent PC file round-trip. No connection or devices."""
from pathlib import Path
import hashlib,json,struct,sys,tempfile,zlib
root=Path(__file__).resolve().parents[1];sys.path.insert(0,str(root/'tools'))
from workflow_protocol import make_request,pack_config,save_record,load_record,record_info
checks=0
request=make_request(1,4);assert len(request)==836 and zlib.crc32(request[:-4])==struct.unpack_from('<I',request,832)[0];checks+=1
for sequence in (0,0xffffffff):
    try:make_request(sequence,4);raise AssertionError('Bad sequence accepted')
    except ValueError:checks+=1
try:pack_config(json.loads((root/'config/machine_template.json').read_text()));raise AssertionError('Unknown mechanics accepted')
except ValueError:checks+=1
data=(root/'reports/arm_test_calibration.bin').read_bytes();info=record_info(data,complete=True);assert info['initial_valid'];checks+=1
with tempfile.TemporaryDirectory(prefix='workflow_file_test_') as folder:
    file=Path(folder)/'calibration.json';save_record(file,data);assert load_record(file)==data;checks+=1
    content=json.loads(file.read_text());content['record_hex']='00'+content['record_hex'][2:];file.write_text(json.dumps(content))
    try:load_record(file);raise AssertionError('Tampered file accepted')
    except ValueError:checks+=1
    partial=bytearray(data);struct.pack_into('<I',partial,12,31);struct.pack_into('<I',partial,464,zlib.crc32(partial[:-4]));save_record(file,partial)
    try:load_record(file);raise AssertionError('Partial calibration restored as complete')
    except ValueError:checks+=1
report={'status':'PASS_NO_HARDWARE','checks':checks,'test_record':'synthetic ARM model only','file_round_trip':'CRC32+SHA256'}
(root/'reports/workflow_protocol_tests.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8');print(json.dumps(report))
