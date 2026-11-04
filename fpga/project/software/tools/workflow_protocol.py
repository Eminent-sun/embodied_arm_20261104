"""DDR request/file format; no hardware dependencies or side effects."""
import hashlib,json,math,struct,zlib
from pathlib import Path
GO=0x57464c31
OPS={'BEGIN':1,'CAL':2,'SAVEINITIAL':3,'PICK':4,'DELIVER':5,'RETURN':6,'STOP':7,'READ':8,'CONFIG':100,'RESTORE':101,'PREVIEW':105,'CHECKPOSE':106,'MOVETO':107,'GOHOME':108,'RECOVER':109,'RESUME':110}
CONFIG_INTS=['calibration','stop_policy','sample_ms','command_timeout_ms','arrival_timeout_ms','max_job_ms']
CONFIG_FLOATS=['start_joint_tolerance_rad','max_cartesian_error_mm']
AXIS_INTS=['motor_id','expected_zero_state','expected_offset_bits']
AXIS_FLOATS=['gain','motor_zero_rad','safe_min_rad','safe_max_rad','speed_rad_s','accel_rad_s2','velocity_trip_rad_s','following_error_rad','arrival_position_rad','arrival_velocity_rad_s']
def number(value,integer=False):
    if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value):raise ValueError('Required measured configuration is missing or invalid')
    if integer and (value!=int(value) or not 0<=value<=0xffffffff):raise ValueError('Invalid unsigned integer')
    return int(value) if integer else float(value)

def cartesian_payload(values):
    if len(values)!=6:raise ValueError('Use X Y Z Roll Pitch Yaw: millimeters and degrees in the URDF base frame')
    v=[number(float(x)) for x in values]
    if any(abs(x)>1000000 for x in v[:3]) or any(abs(x)>360 for x in v[3:]):raise ValueError('XYZ must be finite within +/-1000000 mm; RPY within +/-360 degrees')
    return struct.pack('<4I6f',0x43504f31,1,1,1,*v).ljust(468,b'\0')

def cartesian_report(data):
    if len(data)!=144:raise ValueError('Wrong Cartesian report length')
    h=struct.unpack_from('<10I',data)
    if h[:2]!=(0x43505231,1):raise ValueError('Running PS does not support this Cartesian console')
    v=struct.unpack_from('<26f',data,40)
    return {'sequence':h[2],'result':h[3],'model_only':bool(h[4]),'plan_valid':bool(h[5]),
            'frames':h[6],'duration_ms':h[7],'solver':{0:'none',1:'Pieper spherical wrist',2:'original DLS fallback'}.get(h[8],h[8]),'analytic_solutions':h[9],'xyz_mm':v[:3],'rpy_deg':v[3:6],
            'seed_joint_rad':v[6:12],'target_joint_rad':v[12:18],
            'target_motor_rad':None if h[4] else v[18:24],
            'position_error_mm':v[24],'orientation_error_rad':v[25]}
def pack_config(config):
    data=struct.pack('<6I2f',*[number(config[k],True) for k in CONFIG_INTS],*[number(config[k]) for k in CONFIG_FLOATS])
    if len(config['axis'])!=6:raise ValueError('Exactly six axes required')
    for a,axis in enumerate(config['axis']):
        if axis['motor_id']!=a+1:raise ValueError('J1..J6 must map to Motor ID1..6')
        data+=struct.pack('<3I10f',*[number(axis[k],True) for k in AXIS_INTS],*[number(axis[k]) for k in AXIS_FLOATS])
    assert len(data)==344
    return data
def make_request(sequence,operation,axis=0,reference=0,config=None,record=None):
    if not 0<sequence<0xffffffff:raise ValueError('Use a new monotonically increasing request sequence; reconnect on exhaustion')
    body=struct.pack('<4If',sequence,GO,operation,axis,number(reference))+(pack_config(config) if config is not None else bytes(344))+(record if record is not None else bytes(468))
    if len(body)!=832:raise ValueError('Incorrect record size')
    return body+struct.pack('<I',zlib.crc32(body))
def record_info(data,complete=False):
    if len(data)!=468:raise ValueError('Incorrect calibration size')
    magic,version,generation,mask,initial_valid,reserved=struct.unpack_from('<6I',data)
    if magic!=0x43414c32 or version!=1 or reserved or zlib.crc32(data[:-4])!=struct.unpack_from('<I',data,464)[0]:raise ValueError('Calibration CRC/header mismatch')
    if complete and (mask!=63 or initial_valid!=1):raise ValueError('All axes and one initial pose must be saved before restore')
    return {'generation':generation,'calibrated_mask':mask,'initial_valid':bool(initial_valid),
            'reference_joint_rad':list(struct.unpack_from('<6f',data,368)),
            'captured_motor_rad':list(struct.unpack_from('<6f',data,392)),
            'initial_joint_rad':list(struct.unpack_from('<6f',data,416)),
            'initial_motor_rad':list(struct.unpack_from('<6f',data,440))}
def save_record(path,data):
    info=record_info(data);path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    envelope={'format':'ZYNQ_ARM_CAL_V1','storage':'PC file, not PS flash/SD','record_hex':data.hex(),
              'sha256':hashlib.sha256(data).hexdigest(),'summary':info}
    # A new generation file is kept by the console before latest is replaced.
    temporary=path.with_name(path.name+'.tmp');temporary.write_text(json.dumps(envelope,indent=2)+'\n',encoding='utf-8');temporary.replace(path)
def load_record(path):
    envelope=json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if envelope.get('format')!='ZYNQ_ARM_CAL_V1':raise ValueError('Wrong calibration format')
    data=bytes.fromhex(envelope['record_hex'])
    if hashlib.sha256(data).hexdigest()!=envelope['sha256']:raise ValueError('Calibration SHA mismatch')
    record_info(data,complete=True);return data

def pose_info(data):
    if len(data)!=116:raise ValueError('Incorrect initial-reference record size')
    magic,version,generation,mask=struct.unpack_from('<4I',data)
    if magic!=0x504f5331 or version!=1 or not generation or mask!=63 or zlib.crc32(data[:-4])!=struct.unpack_from('<I',data,112)[0]:raise ValueError('Initial-reference CRC/header mismatch')
    zero=struct.unpack_from('<6I',data,16);offset=struct.unpack_from('<6I',data,40)
    position=struct.unpack_from('<6f',data,64);velocity=struct.unpack_from('<6f',data,88)
    if any(z>1 for z in zero) or any(not math.isfinite(p) or abs(p)>=15.9 for p in position) or any(not math.isfinite(v) or abs(v)>.020001 for v in velocity):raise ValueError('Invalid initial-reference values')
    return {'generation':generation,'motor_ids':[1,2,3,4,5,6],'position_rad':list(position),'velocity_rad_s':list(velocity),'zero_state':list(zero),'offset_bits':list(offset),'URDF_model_calibrated':False}
def pose_from_readback(data,generation):
    """PC reference from one successful fresh WF_READ, never from STATUS cache."""
    if len(data)!=144:raise ValueError('Incorrect six-axis readback size')
    generation=number(generation,True)
    if not generation:raise ValueError('Fresh read sequence is required')
    rows=[struct.unpack_from('<4I2f',data,a*24) for a in range(6)]
    velocity_limit=struct.unpack('<f',struct.pack('<f',.02))[0]
    position_limit=struct.unpack('<f',struct.pack('<f',15.9))[0]
    for a,r in enumerate(rows):
        if r[0]!=a+1 or r[1]>1:raise ValueError('Unexpected Motor ID or run mode in fresh HOME read')
        if not math.isfinite(r[4]) or abs(r[4])>=position_limit:raise ValueError('Invalid motor position in fresh HOME read')
        if not math.isfinite(r[5]) or abs(r[5])>velocity_limit:raise ValueError('Motor is not stationary enough to capture HOME')
    body=struct.pack('<4I6I6I6f6f',0x504f5331,1,generation,63,
                     *[r[2] for r in rows],*[r[3] for r in rows],
                     *[r[4] for r in rows],*[r[5] for r in rows])
    record=body+struct.pack('<I',zlib.crc32(body))
    pose_info(record)
    return record

def save_pose(path,data):
    info=pose_info(data);path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    envelope={'format':'ZYNQ_ARM_INITIAL_POSE_V1','storage':'PC file; raw motor reference, not URDF calibration',
              'record_hex':data.hex(),'sha256':hashlib.sha256(data).hexdigest(),'summary':info}
    temporary=path.with_name(path.name+'.tmp');temporary.write_text(json.dumps(envelope,indent=2)+'\n',encoding='utf-8');temporary.replace(path)
def load_pose(path):
    envelope=json.loads(Path(path).read_text(encoding='utf-8-sig'))
    if envelope.get('format')!='ZYNQ_ARM_INITIAL_POSE_V1':raise ValueError('Wrong initial-reference file format')
    data=bytes.fromhex(envelope['record_hex'])
    if hashlib.sha256(data).hexdigest()!=envelope['sha256']:raise ValueError('Initial-reference SHA mismatch')
    pose_info(data);return data
