"""Render stable IDs and the same filtered 3D points published to telemetry."""
import cv2
import numpy as np


def draw_tools(canvas,detections,intrinsic,distortion):
    for d in detections:
        x1,y1,x2,y2=map(int,d['box_xyxy'])
        color=(40,220,40) if d.get('coordinate_usable') else (0,180,255)
        cv2.rectangle(canvas,(x1,y1),(x2,y2),color,1)
        point=d.get('surface_point_camera_m');pixel=(x1,y1)
        if point is not None and intrinsic:
            k=intrinsic;matrix=np.array([[k['fx'],0,k['cx']],[0,k['fy'],k['cy']],[0,0,1]],float)
            uv,_=cv2.projectPoints(np.array([point],float),np.zeros(3),np.zeros(3),matrix,np.array(distortion,float))
            pixel=tuple(map(int,uv.reshape(2)));cv2.drawMarker(canvas,pixel,color,cv2.MARKER_CROSS,12,1)
        # The detailed XYZ values are in the table; compact IDs avoid overlapping
        # labels on the three adjacent tweezers.
        anchor=(max(0,min(canvas.shape[1]-35,pixel[0]+5)),max(14,min(canvas.shape[0]-4,pixel[1]-10-12*(d['track_id']%3))))
        label=f"#{d['track_id']}"
        cv2.putText(canvas,label,anchor,cv2.FONT_HERSHEY_SIMPLEX,.45,(0,0,0),3)
        cv2.putText(canvas,label,anchor,cv2.FONT_HERSHEY_SIMPLEX,.45,color,1)
