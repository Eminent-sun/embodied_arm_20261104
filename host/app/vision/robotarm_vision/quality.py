"""Camera model binding, depth quality and current-frame detection stability."""
import hashlib
import json
import math
import cv2
import numpy as np


def camera_signature(intrinsic, distortion):
    keys = ('width','height','fx','fy','cx','cy')
    model = {k:round(float(intrinsic[k]),6) for k in keys}
    values = list(model.values()) + list(distortion)
    if not all(math.isfinite(float(v)) for v in values):
        raise ValueError('Non-finite camera model')
    if min(model['width'],model['height'],model['fx'],model['fy']) <= 0:
        raise ValueError('Invalid camera dimensions/focal lengths')
    if len(distortion) not in (4,5,8,12,14):
        raise ValueError('Unsupported distortion model')
    model['distortion'] = [round(float(v),6) for v in distortion]
    return hashlib.sha256(json.dumps(model,sort_keys=True).encode()).hexdigest()


def sample_depth(depth, pixel, intrinsic, distortion=None, radius=3,
                 min_valid_fraction=.6, max_mad_m=.005, max_spread_m=.025):
    result = {'valid':False,'point_camera_m':None,'sample_kind':'pixel_patch_surface',
              'reason':'depth_unavailable','valid_fraction':0.,'mad_m':None,'spread_m':None}
    if depth is None or intrinsic is None:return result
    if not np.isfinite(pixel).all():result['reason']='invalid_pixel';return result
    u,v=map(lambda x:int(round(x)),pixel);h,w=depth.shape
    if not (0<=u<w and 0<=v<h):result['reason']='pixel_outside_image';return result
    patch=depth[max(0,v-radius):min(h,v+radius+1),max(0,u-radius):min(w,u+radius+1)]
    values=patch[np.isfinite(patch)&(patch>.15)&(patch<3)]
    result['valid_fraction']=float(len(values)/patch.size)
    if len(values)<5 or result['valid_fraction']<min_valid_fraction:
        result['reason']='insufficient_valid_depth';return result
    z=float(np.median(values));mad=float(np.median(np.abs(values-z)))
    spread=float(np.percentile(values,90)-np.percentile(values,10))
    result.update(mad_m=mad,spread_m=spread)
    if mad>max_mad_m or spread>max_spread_m:
        result['reason']='depth_discontinuity';return result
    if not np.isfinite(depth[v,u]) or not .15<float(depth[v,u])<3 or abs(float(depth[v,u])-z)>max_spread_m:
        result['reason']='invalid_or_discontinuous_center';return result
    k=np.array([[intrinsic['fx'],0,intrinsic['cx']],[0,intrinsic['fy'],intrinsic['cy']],[0,0,1]],float)
    ray=cv2.undistortPoints(np.array([[[u,v]]],float),k,np.asarray(distortion if distortion is not None else [0]*8,float))[0,0]
    result.update(valid=True,reason=None,point_camera_m=[float(ray[0]*z),float(ray[1]*z),z])
    return result


def box_iou(a,b):
    intersection=max(0,min(a[2],b[2])-max(a[0],b[0]))*max(0,min(a[3],b[3])-max(a[1],b[1]))
    union=(a[2]-a[0])*(a[3]-a[1])+(b[2]-b[0])*(b[3]-b[1])-intersection
    return intersection/max(union,1e-9)


class DetectionStability:
    """No stale-box replay: annotate only detections present in this frame."""
    def __init__(self,min_hits=3,iou_threshold=.4,max_gap_s=.25):
        if type(min_hits) is not int or not 3<=min_hits<=30 or not 0<iou_threshold<=1 or not 0<max_gap_s<=2:
            raise ValueError('Invalid temporal stability configuration')
        self.min_hits=min_hits;self.iou_threshold=iou_threshold;self.max_gap_s=max_gap_s
        self.tracks={};self.next_id=1;self.frame=0;self.last_stamp=None

    def update(self,detections,stamp):
        if self.last_stamp is not None and stamp<=self.last_stamp:
            self.tracks.clear()
        self.last_stamp=stamp;self.frame+=1
        self.tracks={k:t for k,t in self.tracks.items() if 0<=stamp-t['stamp']<=self.max_gap_s}
        candidates=[]
        for i,d in enumerate(detections):
            for key,t in self.tracks.items():
                score=box_iou(d['box_xyxy'],t['box'])
                if d['class_name']==t['class_name'] and score>=self.iou_threshold:
                    candidates.append((score,i,key))
        assigned={};used=set()
        for _,i,key in sorted(candidates,reverse=True):
            if i not in assigned and key not in used:assigned[i]=key;used.add(key)
        for i,d in enumerate(detections):
            key=assigned.get(i)
            if key is None:key=self.next_id;self.next_id+=1
            old=self.tracks.get(key)
            consecutive=old['hits']+1 if old and old['frame']==self.frame-1 else 1
            self.tracks[key]={'box':d['box_xyxy'],'class_name':d['class_name'],'stamp':stamp,'hits':consecutive,'frame':self.frame}
            d.update(track_id=key,consecutive_hits=consecutive,stable=consecutive>=self.min_hits)
        return detections


def predict_region(model,image,roi=None,**kwargs):
    """Zoom a fixed station ROI for small tools, returning full-image pixels."""
    if roi is None:return model.predict(image,**kwargs)[0]
    if len(roi)!=4 or any(type(v) is not int for v in roi):raise ValueError('ROI must contain four integer pixels')
    x1,y1,x2,y2=roi;h,w=image.shape[:2]
    if not (0<=x1<x2<=w and 0<=y1<y2<=h):raise ValueError('ROI outside camera image')
    result=model.predict(image[y1:y2,x1:x2],**kwargs)[0]
    boxes=result.boxes.data.clone();boxes[:,[0,2]]+=x1;boxes[:,[1,3]]+=y1
    return type(result)(orig_img=image,path=result.path,names=result.names,boxes=boxes)
