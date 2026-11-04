"""Offline bridge/console boundary tests. Tcl connect/targets/memory are stubs.
No hardware connection, CPU halt, CAN access or motor commands.
"""
from pathlib import Path
import json,struct,sys,threading,unittest,zlib
from unittest.mock import patch
import tkinter
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
import workflow_console as console
LAYOUT=json.loads((ROOT/'reports/workflow_symbols.json').read_text())
TCL=(ROOT/'tools/workflow_bridge.tcl').read_text(encoding='utf-8')

def stubbed_tcl_get(line,words,signed=False):
    interp=tkinter.Tcl()
    interp.setvar('fixture_words',tuple(words))
    interp.setvar('fixture_signed',int(signed))
    interp.setvar('fixture_input',(line,'QUIT'))
    interp.eval('''
set captured {};set writes {};set connect_count 0
proc connect {} {incr ::connect_count}
proc targets {args} {}
proc disconnect {} {}
proc exit {} {}
rename puts real_puts
proc puts {args} {lappend ::captured [lindex $args end]}
rename gets real_gets
proc gets {channel variable} {
    upvar 1 $variable value
    if {![llength $::fixture_input]} {return -1}
    set value [lindex $::fixture_input 0]
    set ::fixture_input [lrange $::fixture_input 1 end]
    return [string length $value]
}
proc mrd {args} {
    # Same binary-scan operation as the installed Vitis2023.1 mrd -value.
    set data [binary format i* $::fixture_words]
    if {$::fixture_signed} {binary scan $data i* values} else {binary scan $data iu* values}
    return $values
}
proc mwr {args} {lappend ::writes $args}
''')
    interp.eval(TCL)
    assert not interp.eval('set writes')
    return list(interp.splitlist(interp.eval('set captured')))

class MemoryBridge(console.Bridge):
    def __init__(self,magic=0x57465231,stop=0,state=0,active=0):
        self.memory={};self.writes=[];self.closed=threading.Event()
        self.set_words('g_arm_report',[magic,1,state,0,active,0,0,0,0,0,0,0])
        self.set_words('g_approved_path_geometry',[0x50494331,1,1,232,1])
        self.set_words('g_arm_cartesian',[0x43505231,1])
        self.set_words('g_gripper_report',[0x53525631,1])
        self.set_words('g_arm_stop',[stop]);self.set_words('g_arm_request',[0,0])
    def set_words(self,name,values):
        address=int(LAYOUT[name]['address'],0)
        for index,value in enumerate(values):self.memory[address+4*index]=value
    def transfer(self,line):
        fields=line.split();address=int(fields[1],0)
        if fields[0]=='GET':return ['DATA_HEX '+' '.join(f'{self.memory.get(address+4*i,0):08X}' for i in range(int(fields[2]))),'BRIDGE_DONE']
        if fields[0]=='PUT':
            values=[int(value,0) for value in fields[2:]];self.writes.append((address,values))
            for index,value in enumerate(values):self.memory[address+4*index]=value
            return ['OK','BRIDGE_DONE']
        raise AssertionError(line)
    def close(self):self.closed.set()

class BridgeTests(unittest.TestCase):
    def test_old_arm_only_elf_rejected_without_writes_or_long_wait(self):
        bridge=MemoryBridge();bridge.set_words('g_gripper_report',[0,0])
        with self.assertRaisesRegex(RuntimeError,'paired ELF'):
            console.wait_for_application(bridge,LAYOUT)
        self.assertEqual(bridge.writes,[])

    def test_real_tcl_numeric_conversion(self):
        words=[0,1,0x57465231,0x43414e36,0xffffffff,0x80000000,0xbe995451]
        bridge=console.Bridge.__new__(console.Bridge)
        bridge.transfer=lambda line:stubbed_tcl_get(line,words)
        self.assertEqual(bridge.read(0x100000,len(words)),struct.pack('<7I',*words))
    def test_signed_32_bit_words(self):
        words=[0xffffffff,0x80000000,0xbe995451]
        bridge=console.Bridge.__new__(console.Bridge)
        bridge.transfer=lambda line:stubbed_tcl_get(line,words,True)
        self.assertEqual(bridge.read(0x100000,len(words)),struct.pack('<3I',*words))
    def test_decimal_versus_hex_regression(self):
        value=0x57465231
        self.assertNotEqual(int(str(value),16),value)
        lines=stubbed_tcl_get('GET 1048576 1',[value])
        self.assertIn('DATA_HEX 57465231',lines)
    def test_legacy_ambiguous_wire_rejected(self):
        bridge=console.Bridge.__new__(console.Bridge);bridge.transfer=lambda _:['DATA 1464226353']
        with self.assertRaisesRegex(RuntimeError,'DATA_HEX'):bridge.read(0x100000,1)
    def test_chunked_read(self):
        bridge=MemoryBridge();base=0x100000;words=[(i*100000003)&0xffffffff for i in range(61)]
        for i,value in enumerate(words):bridge.memory[base+i*4]=value
        self.assertEqual(bridge.read(base,61),struct.pack('<61I',*words))
    def test_diagnosis_only_reads(self):
        bridge=MemoryBridge(stop=1);snapshot=console.application_snapshot(bridge,LAYOUT)
        self.assertTrue(snapshot['application_matched']);self.assertEqual(snapshot['stop_flag'],1);self.assertEqual(bridge.writes,[])
    def test_paused_hold_application_recognized_without_writes(self):
        bridge=MemoryBridge(state=13,active=63)
        snapshot=console.application_snapshot(bridge,LAYOUT)
        self.assertTrue(snapshot['application_matched'])
        self.assertEqual(snapshot['state'],'PAUSED_HOLD')
        self.assertEqual(snapshot['active_mask'],63)
        self.assertEqual(bridge.writes,[])
    def test_fault_saved_targets_and_velocity_readonly(self):
        bridge=MemoryBridge(state=226,active=63)
        record=bytearray((ROOT/'reports/arm_test_calibration.bin').read_bytes())
        for a in range(6):
            struct.pack_into('<2f',record,56+a*52+36,.75,.099)
        struct.pack_into('<I',record,464,zlib.crc32(record[:464]))
        bridge.set_words('g_arm_calibration',struct.unpack('<117I',record))
        position=[0,2,0,3,1,.18];velocity=[0,0,0,.8,0,.3];target=[0,2,0,3,1,.29]
        data=struct.pack('<12I18f',0x57465231,1,226,11,63,63,1,42,121,11,0,9,*position,*velocity,*target)
        bridge.set_words('g_arm_report',struct.unpack('<30I',data))
        result=console.fault_details(bridge,LAYOUT)
        self.assertEqual(result['frames_completed'],42)
        self.assertAlmostEqual(result['saved_position_minus_target_rad'][5],-.11,places=6)
        self.assertEqual([(x['motor_id'],x['violations_in_saved_values']) for x in result['violations_in_saved_values']],[(4,['velocity_above_trip']),(6,['following_error_above_limit'])])
        self.assertEqual(bridge.writes,[])
    def test_mismatch_no_cleanup_write(self):
        bridge=MemoryBridge(magic=0xdeadbeef)
        with patch.object(console,'Bridge',return_value=bridge):
            with self.assertRaisesRegex(RuntimeError,'0xDEADBEEF'):console.Worker('unused',LAYOUT)
        self.assertTrue(bridge.closed.wait(1));self.assertEqual(bridge.writes,[])
    def test_existing_stop_flag_no_auto_clear_or_stop_write(self):
        bridge=MemoryBridge(stop=1)
        with patch.object(console,'Bridge',return_value=bridge):
            with self.assertRaisesRegex(RuntimeError,'stop flag'):console.Worker('unused',LAYOUT)
        self.assertTrue(bridge.closed.wait(1));self.assertEqual(bridge.writes,[])
    def test_fault_reconnect_leaves_stop_set_until_explicit_RECOVER(self):
        bridge=MemoryBridge(stop=1,state=226,active=63)
        with patch.object(console,'Bridge',return_value=bridge):
            worker=console.Worker('unused',LAYOUT)
            worker.read('g_arm_stop',1)
            worker.stopping=True;worker.thread.join(timeout=1)
        self.assertEqual(bridge.memory[int(LAYOUT['g_arm_stop']['address'],0)],1)
        self.assertTrue(all(a==int(LAYOUT['g_arm_heartbeat']['address'],0) for a,_ in bridge.writes))
    def test_uninitialized_message_contains_actual_state(self):
        bridge=MemoryBridge(magic=0)
        with self.assertRaisesRegex(RuntimeError,'0x00000000'):console.wait_for_application(bridge,LAYOUT,timeout=0)
        self.assertEqual(bridge.writes,[])
    def test_slow_geometry_startup_is_waited_readonly(self):
        bridge=MemoryBridge(magic=0);clock=[0.0];messages=[]
        def advance(seconds):
            clock[0]+=seconds
            count=10 if clock[0]<12 else 77 if clock[0]<25 else 232
            bridge.set_words('g_approved_path_geometry',[0x50494331,1,int(count==232),count,int(count==232)])
            if count==232:bridge.set_words('g_arm_report',[0x57465231,1,0,0,0,0,0,0,0,0,0,0])
        advance(0)
        with patch.object(console.time,'monotonic',side_effect=lambda:clock[0]),patch.object(console.time,'sleep',side_effect=advance):
            snapshot=console.wait_for_application(bridge,LAYOUT,timeout=60,progress=messages.append)
        self.assertTrue(snapshot['application_matched']);self.assertGreater(clock[0],10)
        self.assertTrue(any('77' in message for message in messages));self.assertIn('232',messages[-1])
        self.assertEqual(bridge.writes,[])
    def test_startup_stall_times_out_without_writes(self):
        bridge=MemoryBridge(magic=0);clock=[0.0]
        def advance(seconds):clock[0]+=seconds
        with patch.object(console.time,'monotonic',side_effect=lambda:clock[0]),patch.object(console.time,'sleep',side_effect=advance):
            with self.assertRaisesRegex(RuntimeError,'initialization wait timed out'):
                console.wait_for_application(bridge,LAYOUT,timeout=2,progress=None)
        self.assertEqual(bridge.writes,[])
    def test_explicit_idle_cleanup_one_word_only(self):
        bridge=MemoryBridge(stop=1);console.clear_idle_stop(bridge,LAYOUT,console.application_snapshot(bridge,LAYOUT))
        self.assertEqual(bridge.writes,[(int(LAYOUT['g_arm_stop']['address'],0),[0])])
    def test_fault_or_active_cleanup_rejected(self):
        for state,active in [(226,0),(3,63),(0,1)]:
            bridge=MemoryBridge(stop=1,state=state,active=active)
            with self.assertRaisesRegex(RuntimeError,'requires matched OFF'):console.clear_idle_stop(bridge,LAYOUT,console.application_snapshot(bridge,LAYOUT))
            self.assertEqual(bridge.writes,[])
    def test_valid_attach_heartbeat_without_GO_or_enable(self):
        bridge=MemoryBridge()
        with patch.object(console,'Bridge',return_value=bridge):
            worker=console.Worker('unused',LAYOUT)
            self.assertEqual(struct.unpack('<I',worker.read('g_arm_report',1))[0],0x57465231)
            worker.stopping=True;worker.thread.join(timeout=1)
        self.assertTrue(bridge.closed.is_set())
        self.assertTrue(all(address==int(LAYOUT['g_arm_heartbeat']['address'],0) for address,_ in bridge.writes))

if __name__=='__main__':
    result=unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(BridgeTests))
    report={'status':'PASS_OFFLINE_STUBS_ONLY' if result.wasSuccessful() else 'FAIL','tests':result.testsRun,
            'hardware_access':False,'vendor_source':'installed Vitis2023.1 xsdb.tcl mrd: binary scan iu* / return val_list',
            'BIT_ELF_changed':False}
    (ROOT/'reports/workflow_bridge_tests.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    raise SystemExit(0 if result.wasSuccessful() else 1)
