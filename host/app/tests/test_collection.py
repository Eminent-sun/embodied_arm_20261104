import json
from pathlib import Path
import tempfile
import time
import unittest
from unittest.mock import patch
import cv2
import numpy as np
from robotarm_vision.camera import Capture
from robotarm_vision.collection import CollectionService


class FakeCamera:
    def __init__(self):self.index=0;self.closed=False
    def read(self):
        time.sleep(.02);self.index+=1
        pattern=((np.indices((120,160)).sum(axis=0)//8)%2*160+40).astype(np.uint8)
        image=np.repeat(pattern[:,:,None],3,axis=2);image[0,0,:]=self.index%100
        return Capture(image,np.full((120,160),.5+(self.index%100)*.001,np.float32),
            {'fx':100.,'fy':100.,'cx':80.,'cy':60.,'width':160,'height':120},[0.]*8,
            'synthetic_camera',time.time(),time.monotonic(),float(self.index*20))
    def close(self):self.closed=True


class CollectionTest(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.camera=FakeCamera()
        self.service=CollectionService(self.temp.name,camera_factory=lambda:self.camera,min_free_bytes=0)
        self.addCleanup(self.service.close)
        self.service.start_preview()
        deadline=time.monotonic()+2
        while not self.service.status()['fresh']:
            if time.monotonic()>deadline:self.fail('Synthetic camera did not start')
            time.sleep(.01)
        self.service.submit('new_session',{'scene':'合成测试','split':'test','expected_classes':['pliers']})

    def test_clean_png_and_paired_depth_metadata_and_session_split(self):
        sample=self.service.submit('snapshot',{'issue':'occluded'})
        folder=self.service.folder
        image=cv2.imread(str(folder/sample['image']))
        with np.load(folder/sample['depth']) as data:depth=data['depth_m']
        self.assertAlmostEqual(float(depth[0,0]),.5+int(image[0,0,0])*.001,places=5)
        self.assertEqual(sample['split'],'test');self.assertEqual(sample['annotation_status'],'unlabelled')
        self.assertEqual(sample['source'],'synthetic_test')
        self.assertEqual(sample['camera_serial'],'synthetic_camera')
        self.assertEqual(sample['issue'],'occluded')
        self.assertEqual(sample['depth_aligned_to'],'color')
        self.assertNotIn('labels',sample)
        self.assertEqual(json.loads((folder/'session.json').read_text())['group_id'],sample['group_id'])

    def test_recording_finalizes_and_video_timestamps_match_frame_count(self):
        self.service.submit('record_start');time.sleep(.3)
        with self.assertRaisesRegex(ValueError,'先停止'):self.service.submit('new_session',{'scene':'bad','split':'val'})
        record=self.service.submit('record_stop');self.assertEqual(record['status'],'complete')
        video=cv2.VideoCapture(str(self.service.folder/record['file']));count=0
        while True:
            ok,image=video.read()
            if not ok:break
            count+=1;self.assertEqual(image.shape,(120,160,3))
        video.release()
        timestamps=[json.loads(line) for line in (self.service.folder/record['timestamps']).read_text().splitlines()]
        self.assertGreater(count,4);self.assertEqual(count,record['frame_count']);self.assertEqual(count,len(timestamps))
        self.assertEqual([x['index'] for x in timestamps],list(range(count)))
        self.assertTrue(all(a['captured_at_unix_s']<b['captured_at_unix_s'] for a,b in zip(timestamps,timestamps[1:])))

    def test_stop_preview_closes_video_and_requires_new_session(self):
        self.service.submit('record_start');time.sleep(.15);self.service.close()
        session=json.loads((self.service.folder/'session.json').read_text())
        self.assertFalse(session['recording']);self.assertEqual(session['videos'][0]['status'],'complete')
        self.assertEqual(session['status'],'closed');self.assertTrue(self.camera.closed)
        with self.assertRaises(ValueError):self.service.submit('snapshot')

    def test_quality_similarity_and_stale_frames_are_not_training_candidates(self):
        self.service.submit('snapshot')
        with self.service.lock:
            self.assertIsNone(self.service._save_sample(automatic=True))
            self.service.frame.color=np.zeros_like(self.service.frame.color)
            with self.assertRaisesRegex(ValueError,'全黑'):self.service._save_sample()
            self.service.frame.received_monotonic=time.monotonic()-2
            with self.assertRaisesRegex(ValueError,'过期'):self.service._save_sample()

    def test_paths_and_disk_limits(self):
        self.service.submit('snapshot');sid=self.service.session['session_id']
        for session,name in [('../','session.json'),(sid,'../../config/planning.json'),(sid,'metadata/1.json')]:
            with self.assertRaises(ValueError):self.service.file_path(session,name)
        outside=Path(self.temp.name)/'secret';outside.write_text('not dataset')
        (self.service.folder/'images/999999.png').symlink_to(outside)
        with self.assertRaises(ValueError):self.service.file_path(sid,'images/999999.png')
        self.service.min_free_bytes=10**20
        with self.assertRaisesRegex(ValueError,'磁盘'):self.service.submit('snapshot')

    def test_session_split_cannot_change_during_recording(self):
        first=self.service.session['group_id'];self.service.submit('record_start');time.sleep(.1)
        self.service.submit('record_stop')
        self.service.submit('new_session',{'scene':'重新摆放','split':'val','expected_classes':[]})
        self.service.submit('snapshot')
        self.assertNotEqual(first,self.service.session['group_id'])
        self.assertEqual(self.service.session['split'],'val')
        old=json.loads((self.service.directory/first/'session.json').read_text())
        self.assertEqual(old['split'],'test');self.assertEqual(old['status'],'closed')


class CollectionHTTPTest(unittest.TestCase):
    def test_controls_require_token_and_preview_does_not_start_on_get(self):
        import threading
        import urllib.request
        import urllib.error
        from http.server import ThreadingHTTPServer
        from robotarm_vision import dashboard
        with tempfile.TemporaryDirectory() as directory:
            service=CollectionService(directory,camera_factory=FakeCamera,min_free_bytes=0)
            with patch.object(dashboard,'COLLECTION',service):
                server=ThreadingHTTPServer(('127.0.0.1',0),dashboard.Handler)
                thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
                base=f'http://127.0.0.1:{server.server_port}'
                try:
                    status=json.load(urllib.request.urlopen(base+'/api/collection/status'))
                    self.assertEqual(status['camera_state'],'stopped')
                    request=urllib.request.Request(base+'/api/collection/preview_start',data=b'{}',headers={'Content-Type':'application/json'})
                    with self.assertRaises(urllib.error.HTTPError) as error:urllib.request.urlopen(request)
                    self.assertEqual(error.exception.code,403);self.assertIsNone(service.thread)
                    request.add_header('X-Task-Token',dashboard.TOKEN)
                    self.assertEqual(urllib.request.urlopen(request).status,200)
                    with self.assertRaises(urllib.error.HTTPError):urllib.request.urlopen(base+'/api/collection/file?session=../../&path=session.json')
                finally:server.shutdown();server.server_close();thread.join();service.close()

if __name__=='__main__':unittest.main()
