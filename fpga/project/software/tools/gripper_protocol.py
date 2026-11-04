"""Basic gripper commands. Units are pulse microseconds, never assumed angles."""
import struct
PRESETS={'OPEN':1220,'CLOSE':1360,'INIT':1110}
STEP_COMMANDS={'OPENSTEP':-10,'CLOSESTEP':10}

def gripper_payload(parameters, state=None):
    if not parameters:raise ValueError('GRIP OPEN/CLOSE/INIT/OPENSTEP/CLOSESTEP/OFF/STATUS or GRIP US <1110..1490> [step_us interval_ms]')
    command=parameters[0].upper()
    if command in STEP_COMMANDS:
        if len(parameters)!=1:raise ValueError(command+' takes no parameters; one command = 10 us')
        if state is None:raise ValueError('Step command requires fresh GRIP STATUS')
        if state['result'] or not state['present'] or not state['pwm_enabled'] or state['lease_expired']:
            raise ValueError('PWM is not ready; use GRIP INIT before stepping')
        target=state['target_pulse_us']
        if not 1110<=target<=1490:raise ValueError('Invalid current gripper target')
        pulse=max(1110,min(1490,target+STEP_COMMANDS[command]))
        # Base each click on the accepted target, including while ramping.
        return gripper_payload(['US',str(pulse)])
    if command in ('OFF','STATUS'):
        if len(parameters)!=1:raise ValueError(command+' takes no parameters')
        values=(0 if command=='STATUS' else 1,0,0,0)
    else:
        if command=='US':
            if len(parameters)<2:raise ValueError('GRIP US requires pulse microseconds')
            pulse=int(parameters[1]);extra=parameters[2:]
        elif command in PRESETS:pulse=PRESETS[command];extra=parameters[1:]
        else:raise ValueError('Unknown GRIP action')
        if len(extra) not in (0,2):raise ValueError('Optional speed needs both step_us and interval_ms')
        step,interval=(10,100) if not extra else tuple(int(x) for x in extra)
        if not 1110<=pulse<=1490 or not 1<=step<=10 or not 20<=interval<=1000 or interval%20:
            raise ValueError('pulse=1110..1490 us; step=1..10 us; interval=20..1000 ms in multiples of 20')
        values=(2,pulse,step,interval//20)
    return struct.pack('<6I',0x47525031,1,*values).ljust(468,b'\0')

def gripper_report(data):
    v=struct.unpack('<13I',data)
    if v[:2]!=(0x53525631,1):raise ValueError('PS gripper interface mismatch; use paired ELF and BIT')
    return {'sequence':v[2],'result':v[3],'present':bool(v[4]),'pwm_enabled':bool(v[5]),
            'pulse_ramping':bool(v[6]),'lease_expired':bool(v[7]),'active_pulse_us':v[8],
            'target_pulse_us':v[9],'step_us':v[10],'step_interval_ms':20*v[11],
            'pwm_frames':v[12],'mechanical_position_feedback':False}
