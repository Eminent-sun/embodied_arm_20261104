"""Bounded observation-only payload for the independent PS vision channel."""
import math
import time
import copy
from .protocol import ProtocolError

CLASSES={'screwdriver':0,'pliers':1,'scissors':2,'tweezers':3}
MAX_AGE_MS=500


def age_coordinates(payload,elapsed_ms):
    """Expire points separately from frame TTL, without mutating the sent payload."""
    data=copy.deepcopy(payload)
    for d in data.get('detections',[]):
        if 'tracking_status' not in d or d.get('coordinate_age_ms') is None:continue
        d['coordinate_age_ms']+=elapsed_ms
        if d['coordinate_age_ms']>150:d['coordinate_usable']=False
        if d['coordinate_age_ms']>350:
            d.update(surface_point_camera_m=None,surface_point_base_m=None,coordinate_age_ms=None,
                     coordinate_fresh=False,coordinate_usable=False,tracking_status='expired',stable=False,
                     depth_quality={'valid':False,'valid_fraction':0.,'mad_m':None,'spread_m':None})
    for hand in data.get('hands',[]):
        for k in hand['keypoints']:
            if k.get('coordinate_age_ms') is None:continue
            k['coordinate_age_ms']+=elapsed_ms
            if k['coordinate_age_ms']>200:k.update(camera_m=None,base_m=None,coordinate_fresh=False,coordinate_age_ms=None)
    return data


def number(value,low,high):
    return type(value) in (int,float) and math.isfinite(value) and low<=value<=high


def text_id(value):
    return isinstance(value,str) and 1<=len(value)<=128 and all(c.isalnum() or c in '_-.' for c in value)


def vector(value,size):
    return isinstance(value,list) and len(value)==size and all(number(v,-10,10) for v in value)


def validate_observation(data):
    if not isinstance(data,dict) or type(data.get('schema_version')) is not int or data['schema_version']!=1:raise ProtocolError('Unsupported observation schema')
    if data.get('units')!='m' or data.get('camera_frame')!='camera_color_optical_frame' or data.get('base_frame')!='base_link':
        raise ProtocolError('Invalid units or coordinate frames')
    if data.get('mounting')!='eye_to_hand' or data.get('execution_enabled') is not False:raise ProtocolError('Observation cannot enable execution')
    if data.get('source_kind') not in ['live_camera','offline_replay','synthetic_test']:raise ProtocolError('Missing source kind')
    if not text_id(data.get('source_session_id')) or not text_id(data.get('camera_serial')):raise ProtocolError('Missing source/camera identity')
    if type(data.get('frame_id')) is not int or not 0<=data['frame_id']<2**63:raise ProtocolError('Invalid frame id')
    if not number(data.get('sender_age_ms'),0,MAX_AGE_MS) or not number(data.get('ttl_ms'),1,MAX_AGE_MS):raise ProtocolError('Expired or invalid age/TTL')
    if data['sender_age_ms']+data['ttl_ms']>MAX_AGE_MS+1:raise ProtocolError('TTL exceeds frame age budget')
    if type(data.get('hand_present')) is not bool or type(data.get('base_calibration_valid')) is not bool:raise ProtocolError('Missing quality flags')
    size=data.get('image_size')
    if not isinstance(size,list) or len(size)!=2 or any(type(v) is not int or not 1<=v<=8192 for v in size):raise ProtocolError('Invalid image size')
    calibrated=data['base_calibration_valid']
    if calibrated and not all(text_id(data.get(k)) for k in ['station_setup_id','calibration_id','camera_model_signature']):raise ProtocolError('Base coordinates require calibration provenance')
    detections=data.get('detections')
    if not isinstance(detections,list) or len(detections)>128:raise ProtocolError('Too many detections')
    tracks=set()
    for d in detections:
        if not isinstance(d,dict):raise ProtocolError('Invalid detection')
        if d.get('class_name') not in CLASSES or type(d.get('class_id')) is not int or d['class_id']!=CLASSES[d['class_name']]:raise ProtocolError('Unknown/mismatched class')
        if not number(d.get('confidence'),0,1):raise ProtocolError('Invalid confidence')
        tid=d.get('track_id')
        if type(tid) is not int or tid<=0 or tid in tracks:raise ProtocolError('Invalid or duplicate track id')
        tracks.add(tid)
        b=d.get('box_xyxy')
        if not isinstance(b,list) or len(b)!=4 or not all(number(v,0,max(size)) for v in b):raise ProtocolError('Invalid pixel box')
        if not (0<=b[0]<b[2]<=size[0] and 0<=b[1]<b[3]<=size[1]):raise ProtocolError('Box outside image')
        if type(d.get('consecutive_hits')) is not int or d['consecutive_hits']<1 or type(d.get('stable')) is not bool:raise ProtocolError('Invalid stability metadata')
        if d['stable'] and d['consecutive_hits']<3:raise ProtocolError('Stable target requires >=3 consecutive frames')
        q=d.get('depth_quality')
        if not isinstance(q,dict) or type(q.get('valid')) is not bool:raise ProtocolError('Missing depth quality')
        if not number(q.get('valid_fraction'),0,1):raise ProtocolError('Invalid depth coverage')
        pc,pb=d.get('surface_point_camera_m'),d.get('surface_point_base_m')
        if q['valid']:
            if not vector(pc,3) or not .15<pc[2]<3:raise ProtocolError('Invalid metric camera sample')
            if not number(q.get('mad_m'),0,.005) or not number(q.get('spread_m'),0,.025) or q['valid_fraction']<.6:raise ProtocolError('Depth quality failed')
        elif pc is not None or pb is not None:raise ProtocolError('Invalid depth cannot carry coordinates')
        if pb is not None and (not calibrated or not vector(pb,3)):raise ProtocolError('Uncalibrated or invalid base sample')
        if calibrated and q['valid'] and pb is None:raise ProtocolError('Calibrated depth sample missing base coordinates')
        if d.get('point_kind')!='bbox_center_surface_sample' or d.get('grasp_pose') is not None:raise ProtocolError('A detection sample is not a grasp pose')
        if 'tracking_status' in d:
            if d['tracking_status'] not in ['tentative','tracked','held','jump_rejected','missing_depth','reacquiring','expired']:raise ProtocolError('Invalid tracking state')
            for flag in ['coordinate_fresh','coordinate_usable','observed_this_frame']:
                if type(d.get(flag)) is not bool:raise ProtocolError('Missing coordinate state')
            if pc is not None and not number(d.get('coordinate_age_ms'),0,350):raise ProtocolError('Expired coordinate')
            if pc is None and d.get('coordinate_age_ms') is not None:raise ProtocolError('Age without a coordinate')
            if d['coordinate_usable'] and (not d['stable'] or not d['coordinate_fresh'] or not d['observed_this_frame'] or pc is None or d['coordinate_age_ms']>150):raise ProtocolError('Held or unstable coordinate cannot be usable')
            if d['tracking_status'] in ['held','jump_rejected','missing_depth','expired'] and (d['coordinate_fresh'] or d['coordinate_usable']):raise ProtocolError('Historical point marked fresh')
    hands=data.get('hands',[])
    if not isinstance(hands,list) or len(hands)>4:raise ProtocolError('Too many hand tracks')
    hand_ids=set()
    for hand in hands:
        if not isinstance(hand,dict) or type(hand.get('track_id')) is not int or hand['track_id']<=0 or hand['track_id'] in hand_ids:raise ProtocolError('Invalid hand track')
        hand_ids.add(hand['track_id'])
        if type(hand.get('observed_this_frame')) is not bool:raise ProtocolError('Invalid hand freshness')
        points=hand.get('keypoints')
        if not isinstance(points,list) or len(points)!=21:raise ProtocolError('Expected 21 hand points')
        for index,k in enumerate(points):
            if not isinstance(k,dict) or type(k.get('id')) is not int or k['id']!=index:raise ProtocolError('Invalid hand point ID')
            if type(k.get('coordinate_fresh')) is not bool:raise ProtocolError('Invalid keypoint freshness')
            pc,pb=k.get('camera_m'),k.get('base_m')
            if pc is not None and (not vector(pc,3) or not .15<pc[2]<3 or not number(k.get('coordinate_age_ms'),0,200)):raise ProtocolError('Invalid hand depth')
            if pc is None and (pb is not None or k.get('coordinate_age_ms') is not None or k['coordinate_fresh']):raise ProtocolError('Missing hand depth')
            if pb is not None and (not calibrated or not vector(pb,3)):raise ProtocolError('Invalid hand base point')
            if pc is not None and calibrated and pb is None:raise ProtocolError('Missing hand base point')
            if k['coordinate_fresh'] and not hand['observed_this_frame']:raise ProtocolError('Held hand point marked fresh')
    return data


def observation_payload(observation,now=None):
    now=time.time() if now is None else now
    if observation.get('schema_version')!=2:raise ProtocolError('Publisher requires perception schema 2')
    captured=observation.get('captured_at_unix_s')
    if not number(captured,0,now):raise ProtocolError('Missing/future capture time')
    age=(now-captured)*1000
    if not 0<=age<MAX_AGE_MS-1:raise ProtocolError('Stale perception frame')
    fields=['source_kind','source_session_id','frame_id','camera_serial','mounting','image_size','camera_frame','base_frame','units',
            'station_setup_id','calibration_id','camera_model_signature','base_calibration_valid','hand_present']
    data={k:observation.get(k) for k in fields}
    data.update(schema_version=1,sender_age_ms=age,ttl_ms=MAX_AGE_MS-age,execution_enabled=False,detections=[])
    for d in observation.get('detections',[]):
        if d.get('class_name') not in CLASSES:continue
        fields=['class_name','confidence','box_xyxy','track_id','consecutive_hits','stable','surface_point_camera_m',
                'surface_point_base_m','depth_quality','point_kind','grasp_pose']
        item={k:d.get(k) for k in fields};item['class_id']=CLASSES[d['class_name']];data['detections'].append(item)
        if 'tracking_status' in d:
            for k in ['tracking_status','coordinate_fresh','coordinate_usable','coordinate_age_ms','observed_this_frame','filter_kind']:item[k]=d.get(k)
    data['hands']=[]
    data['hand_status']=observation.get('hand_status','unspecified')
    for hand in observation.get('hands',[]):
        wire={'track_id':hand['track_id'],'handedness':hand['handedness'],
              'observed_this_frame':hand['observed_this_frame'],'keypoints':[]}
        for k in hand['keypoints']:
            point={field:k.get(field) for field in ['id','camera_m','base_m','coordinate_fresh','coordinate_age_ms']}
            wire['keypoints'].append(point)
        data['hands'].append(wire)
    return validate_observation(age_coordinates(data,age))
