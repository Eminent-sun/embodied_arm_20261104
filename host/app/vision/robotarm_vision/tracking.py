"""Bounded temporal filtering. Held data is explicit, never a fresh measurement."""
from copy import deepcopy
from collections import deque
import math
import numpy as np
from .quality import box_iou


class PointFilter:
    def __init__(self,tau=.10,deadband=.0015,jump=.03):
        self.tau=tau;self.deadband=deadband;self.jump=jump
        self.samples=deque(maxlen=3);self.value=None;self.stamp=None
        self.pending=None;self.pending_hits=0;self.hits=0

    def update(self,point,stamp):
        p=np.asarray(point,float) if point is not None else None
        if p is None or p.shape!=(3,) or not np.isfinite(p).all():return False,'missing_depth'
        reset=False
        if self.value is not None and np.linalg.norm(p-self.value)>self.jump:
            if self.pending is not None and np.linalg.norm(p-self.pending)<self.jump/3:self.pending_hits+=1
            else:self.pending_hits=1
            self.pending=p.copy()
            if self.pending_hits<3:return False,'jump_rejected'
            # A sustained moved object must requalify, rather than creeping across a jump.
            self.samples.clear();self.value=None;self.hits=0;reset=True
        self.pending=None;self.pending_hits=0
        self.samples.append(p);median=np.median(self.samples,axis=0)
        if self.value is None:self.value=median
        else:
            alpha=1-math.exp(-max(0,stamp-self.stamp)/self.tau)
            delta=median-self.value
            if np.linalg.norm(delta)>self.deadband:self.value=self.value+alpha*delta
        self.stamp=stamp;self.hits+=1
        return True,'reacquiring' if reset else 'tracked'


class TemporalTracker:
    """Same-class assignment, ambiguity rejection, bounded holds and metric filters.

    IDs are scoped to the producing session. No velocity extrapolation or robotic
    setpoint output. Geometry is filtered in camera space; base projection follows.
    """
    def __init__(self,min_hits=3,hold_s=.35,tau_s=.10,jump_m=.03,deadband_m=.0015,
                 start_confidence=.35,iou_threshold=.15):
        if not 3<=min_hits<=30 or not 0<hold_s<=.5 or not 0<tau_s<=1 or not 0<jump_m<=.2 or not 0<=deadband_m<jump_m:
            raise ValueError('Invalid temporal filter configuration')
        self.min_hits=min_hits;self.hold_s=hold_s;self.tau_s=tau_s;self.jump_m=jump_m;self.deadband_m=deadband_m
        self.start_confidence=start_confidence;self.iou_threshold=iou_threshold
        self.tracks={};self.next_id=1;self.last_stamp=None
        self.previous_stamp=None

    def update(self,detections,stamp):
        if not math.isfinite(stamp):raise ValueError('Invalid timestamp')
        if self.last_stamp is not None and (stamp<=self.last_stamp or stamp-self.last_stamp>self.hold_s):self.tracks.clear()
        self.last_stamp=stamp
        self.tracks={k:t for k,t in self.tracks.items() if stamp-t['seen']<=self.hold_s}
        candidates=[];ambiguous=set()
        for i,d in enumerate(detections):
            options=[]
            for key,t in self.tracks.items():
                if d['class_name']!=t['data']['class_name']:continue
                score=box_iou(d['box_xyxy'],t['box'])
                if score>=self.iou_threshold:options.append((score,i,key))
            options.sort(reverse=True)
            if len(options)>1 and options[0][0]-options[1][0]<.08:
                ambiguous.add(i)
            else:candidates.extend(options)
        assigned={};used=set()
        for score,i,key in sorted(candidates,reverse=True):
            if i not in assigned and key not in used:assigned[i]=key;used.add(key)
        output=[];seen=set()
        for i,raw in enumerate(detections):
            if i in ambiguous:continue
            key=assigned.get(i)
            if key is None:
                if raw['confidence']<self.start_confidence:continue
                key=self.next_id;self.next_id+=1
                self.tracks[key]={'box':np.array(raw['box_xyxy'],float),'seen':stamp,'hits':0,'data':{},
                    'filter':PointFilter(self.tau_s,self.deadband_m,self.jump_m),'quality':None,'last_frame':None}
            t=self.tracks[key];seen.add(key);d=deepcopy(raw)
            dt=max(.001,stamp-t['seen']);alpha=1-math.exp(-dt/.06)
            t['box']=t['box']+alpha*(np.array(raw['box_xyxy'])-t['box'])
            t['hits']=t['hits']+1 if t['last_frame']==self.previous_stamp else 1
            t['seen']=stamp;t['last_frame']=stamp
            d['raw_box_xyxy']=raw['box_xyxy'];d['box_xyxy']=t['box'].tolist()
            d['raw_surface_point_camera_m']=raw.get('surface_point_camera_m')
            q=raw.get('depth_quality',{})
            accepted,state=t['filter'].update(raw.get('surface_point_camera_m') if q.get('valid') else None,stamp)
            if accepted:t['quality']=deepcopy(q)
            self._coordinates(d,t,stamp,accepted,state)
            if raw['confidence']<self.start_confidence:d['coordinate_usable']=False
            d.update(track_id=key,consecutive_hits=t['hits'],observed_this_frame=True)
            t['data']=deepcopy(d);output.append(d)
        for key,t in self.tracks.items():
            if key in seen:continue
            d=deepcopy(t['data']);self._coordinates(d,t,stamp,False,'held')
            d.update(observed_this_frame=False,stable=False,coordinate_usable=False)
            output.append(d)
        self.previous_stamp=stamp
        return sorted(output,key=lambda d:d['track_id'])

    def _coordinates(self,d,t,stamp,accepted,state):
        f=t['filter'];age=stamp-f.stamp if f.stamp is not None else None
        available=age is not None and 0<=age<=self.hold_s
        d['surface_point_camera_m']=f.value.tolist() if available else None
        # Project AFTER filtering, never carry a base point from an old transform.
        d['surface_point_base_m']=None
        if available:d['depth_quality']=deepcopy(t['quality'])
        else:d['depth_quality']={'valid':False,'valid_fraction':0.,'mad_m':None,'spread_m':None,'reason':'coordinate_expired'}
        stable=accepted and t['hits']>=self.min_hits and f.hits>=self.min_hits
        d.update(stable=stable,coordinate_usable=stable,coordinate_fresh=bool(accepted),
                 coordinate_age_ms=age*1000 if available else None,tracking_status=state,
                 filter_kind='median3_ema_deadband',point_kind='bbox_center_surface_sample',grasp_pose=None)
        if state=='tracked' and not stable:d['tracking_status']='tentative'


class HandTracker:
    """Identity by image proximity; handedness alone cannot identify two hands."""
    def __init__(self):
        self.tracker=TemporalTracker(hold_s=.20,tau_s=.06,jump_m=.10,deadband_m=.001,start_confidence=0)
        self.filters={};self.last_presence=None;self.palm_history={}

    def update(self,hands,stamp):
        detections=[]
        for hand in hands:
            pixels=np.array([k['pixel'] for k in hand['keypoints']],float)
            low=pixels.min(0);high=pixels.max(0)
            wrist=hand['keypoints'][0]
            detections.append({**hand,'class_name':'hand','box_xyxy':[*low,*high],
                'surface_point_camera_m':wrist.get('camera_m'),'depth_quality':wrist.get('depth_quality',{})})
        tracks=self.tracker.update(detections,stamp)
        # At most two current hands plus two recent held tracks on the wire.
        tracks=sorted(tracks,key=lambda d:(not d['observed_this_frame'],d.get('coordinate_age_ms') or 0))[:4]
        out=[]
        if hands:self.last_presence=stamp
        for d in tracks:
            key=d['track_id'];filters=self.filters.setdefault(key,[PointFilter(.06,.001,.10) for _ in range(21)])
            for index,k in enumerate(d['keypoints']):
                f=filters[index]
                fresh=False
                if d['observed_this_frame']:
                    raw=k.get('camera_m');k['raw_camera_m']=raw
                    fresh,_=f.update(raw if k.get('depth_quality',{}).get('valid') else None,stamp)
                age=stamp-f.stamp if f.stamp is not None else None
                k['camera_m']=f.value.tolist() if age is not None and 0<=age<=.20 else None
                k['base_m']=None;k['coordinate_fresh']=fresh;k['coordinate_age_ms']=age*1000 if k['camera_m'] is not None else None
                # Separate 2D smoothing for preview; this is never metric depth.
                if d['observed_this_frame']:
                    pixel=np.array(k['pixel'],float);old=getattr(f,'pixel',pixel)
                    f.pixel=.55*old+.45*pixel
                if hasattr(f,'pixel'):k['pixel']=f.pixel.tolist()
            # Stability uses unfiltered metric depth, so EMA lag cannot make a
            # moving hand look stationary. Never accumulate held measurements.
            palm_points=[d['keypoints'][i] for i in [0,5,9,13,17]]
            history=self.palm_history.setdefault(key,deque(maxlen=64))
            fresh=d['observed_this_frame'] and all(k['coordinate_fresh'] for k in palm_points)
            d.update(palm_camera_m=None,palm_base_m=None,palm_stable=False,palm_stability_span_s=0.)
            if fresh:
                raw=np.mean([k['raw_camera_m'] for k in palm_points],axis=0)
                if history and (not 0<stamp-history[-1][0]<=.15 or np.linalg.norm(raw-history[-1][1])>.015):history.clear()
                history.append((stamp,raw))
                while history and stamp-history[0][0]>.5:history.popleft()
                span=stamp-history[0][0]
                spread=float(np.linalg.norm(np.ptp([p for _,p in history],axis=0)))
                speeds=[np.linalg.norm(b-a)/(tb-ta) for (ta,a),(tb,b) in zip(history,list(history)[1:])]
                d.update(palm_camera_m=np.mean([k['camera_m'] for k in palm_points],axis=0).tolist(),
                         palm_stability_span_s=span,palm_spread_m=spread,
                         palm_stable=bool(len(history)>=6 and span>=.35 and spread<=.012 and max(speeds,default=0)<=.08))
            else:history.clear()
            d['keypoints']=deepcopy(d['keypoints']);out.append(d)
        active={d['track_id'] for d in tracks};self.filters={k:v for k,v in self.filters.items() if k in active}
        self.palm_history={k:v for k,v in self.palm_history.items() if k in active}
        present=self.last_presence is not None and 0<=stamp-self.last_presence<=.5
        return out,present,('detected' if hands else 'recently_seen' if present else 'not_detected')
