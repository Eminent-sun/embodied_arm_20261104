import socket
import struct
import threading
import time
import unittest

from robotarm_link.protocol import Client, HOME, JOINTS, MAGIC, HEADER, ProtocolError, recv_packet, send_packet, validate_trajectory
from robotarm_link.ps_simulator import serve


def trajectory():
    end=HOME.copy();end[0]=0.1
    return {'joint_names':JOINTS,'points':[{'time_s':0.,'positions_rad':HOME.copy()},{'time_s':0.5,'positions_rad':end}]}


class FramingTest(unittest.TestCase):
    def test_fragmented_message(self):
        a,b=socket.socketpair()
        import json,zlib
        body=json.dumps({'seq':1,'command':'hello'}).encode()
        packet=HEADER.pack(MAGIC,1,len(body),zlib.crc32(body))+body
        def fragmented():
            with a:
                for value in packet:a.sendall(bytes([value]))
        t=threading.Thread(target=fragmented);t.start()
        with b:self.assertEqual(recv_packet(b)['command'],'hello')
        t.join()

    def test_crc_and_size_rejected(self):
        for header,body in [(HEADER.pack(MAGIC,1,2,0),b'{}'),(HEADER.pack(MAGIC,1,2000000,0),b'')]:
            a,b=socket.socketpair()
            with a,b:
                a.sendall(header+body)
                with self.assertRaises(ProtocolError):recv_packet(b)

    def test_invalid_trajectories(self):
        for field,value in [('time_s',-1),('time_s',float('nan')),('positions_rad',[100.]*6),('positions_rad',[0.]*5)]:
            t=trajectory();t['points'][1][field]=value
            with self.assertRaises(ProtocolError):validate_trajectory(t)
        t=trajectory();t['points'][1]['time_s']=0.01
        with self.assertRaises(ProtocolError):validate_trajectory(t)


class SessionTest(unittest.TestCase):
    def setUp(self):
        self.stop=threading.Event();ready=threading.Event();self.port=None
        def callback(port):self.port=port;ready.set()
        self.thread=threading.Thread(target=serve,kwargs={'port':0,'ready':callback,'stop_event':self.stop},daemon=True)
        self.thread.start();self.assertTrue(ready.wait(3))
        self.client=Client(port=self.port)

    def tearDown(self):
        self.client.close();self.stop.set();self.thread.join(3)

    def test_confirmation_execution_gripper(self):
        self.assertEqual(self.client.request('hello')['mode'],'simulation')
        token=self.client.request('upload',trajectory=trajectory())['trajectory_id']
        with self.assertRaises(ProtocolError):self.client.request('execute',trajectory_id=token,confirmed=False)
        self.client.request('execute',trajectory_id=token,confirmed=True)
        deadline=time.monotonic()+2
        while time.monotonic()<deadline:
            result=self.client.request('status')
            if result['state']=='succeeded':break
            time.sleep(.05)
        self.assertEqual(result['state'],'succeeded')
        self.assertAlmostEqual(result['positions_rad'][0],.1)
        self.assertEqual(self.client.request('gripper',action='close',confirmed=True)['gripper'],'close')

    def test_disconnect_stops_and_invalidates_plan(self):
        t=trajectory();t['points'][1]['time_s']=4
        token=self.client.request('upload',trajectory=t)['trajectory_id']
        self.client.request('execute',trajectory_id=token,confirmed=True)
        self.client.close();time.sleep(.15)
        self.client=Client(port=self.port)
        state=self.client.request('status')
        self.assertEqual(state['state'],'stopped')
        self.assertIsNone(state['trajectory_id'])
        self.assertLess(state['positions_rad'][0],.1)

    def test_watchdog_stops(self):
        t=trajectory();t['points'][1]['time_s']=4
        token=self.client.request('upload',trajectory=t)['trajectory_id']
        self.client.request('execute',trajectory_id=token,confirmed=True)
        time.sleep(1.2)
        self.client.close();self.client=Client(port=self.port)
        state=self.client.request('status')
        self.assertEqual(state['state'],'stopped')
        self.assertLess(state['positions_rad'][0],.1)


if __name__=='__main__':unittest.main()
