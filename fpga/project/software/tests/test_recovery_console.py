"""Console recovery journaling and explicit enable separation; no hardware."""
from pathlib import Path
import json,struct,sys,tempfile,unittest
from unittest.mock import patch
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
from workflow_protocol import OPS

class RecoveryConsoleTests(unittest.TestCase):
    def exercise(self,commands,state=226,fail_archive=False):
        operations=[]
        class Worker:
            def __init__(self,*args):
                self.thread=type('Thread',(),{'join':lambda self,**kw:None})()
            def read(self,name,count):
                if name=='g_arm_report':return struct.pack('<12I18f',0x57465231,1,state,11,63,63,1,42,121,0,0,9,*([0.]*18))
                return bytes(count*4)
            def stop(self):operations.append('STOP')
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp);(root/'build').mkdir();(root/'reports').mkdir()
            for rel in ('build/arm_workflow.elf','reports/workflow_symbols.json'):
                (root/rel).write_bytes((ROOT/rel).read_bytes())
            def submit(worker,seq,op,*args,**kwargs):
                if op==109:
                    journal=list((root/'operator_logs').glob('*/before_recovery.jsonl'))
                    self.assertEqual(len(journal),1)
                    self.assertEqual(bytes.fromhex(json.loads(journal[0].read_text().splitlines()[-1])['report_hex'])[8:12],struct.pack('<I',226))
                operations.append(op);return (seq,0,op,0)
            original_open=Path.open
            def opened(path,*args,**kwargs):
                if fail_archive and path.name=='before_recovery.jsonl':raise OSError('fixture disk full')
                return original_open(path,*args,**kwargs)
            with patch.object(console,'ROOT',root),patch.object(console,'Worker',Worker),patch.object(console,'submit_request',submit),patch.object(Path,'open',opened),patch('builtins.input',side_effect=commands),patch.object(sys,'argv',['console','--connect']),patch('builtins.print'):
                if fail_archive:
                    with self.assertRaises(OSError):console.main()
                else:console.main()
        return operations
    def test_recover_archives_first_no_implicit_resume(self):
        self.assertEqual(self.exercise(['RECOVER','QUIT']),[109,'STOP','STOP'])
    def test_archive_failure_prevents_recovery(self):
        self.assertEqual(self.exercise(['RECOVER'],fail_archive=True),['STOP'])
    def test_recover_rejected_outside_fault(self):
        self.assertEqual(self.exercise(['RECOVER','QUIT'],state=3),['STOP','STOP'])
    def test_extra_arguments_do_not_issue_commands(self):
        self.assertEqual(self.exercise(['RECOVER yes','RESUME yes','QUIT']),['STOP','STOP'])
    def test_resume_is_separate_explicit_operation(self):
        self.assertEqual(OPS['RESUME'],110)
        self.assertEqual(self.exercise(['RESUME','QUIT']),[110,'STOP','STOP'])

if __name__=='__main__':unittest.main()
