"""PS-side reference vision receiver; no motor/trajectory command handlers."""
import argparse
from collections import OrderedDict
import copy
import socket
import threading
import time
from .protocol import ProtocolError,recv_packet,send_packet
from .vision_protocol import validate_observation,age_coordinates


class ObservationStore:
    def __init__(self):
        self.latest=None;self.deadline=0.;self.received=0.;self.frames=OrderedDict();self.lock=threading.Lock()

    def accept(self,payload):
        validate_observation(payload)
        with self.lock:
            session=payload['source_session_id'];previous=self.frames.get(session,-1)
            if payload['frame_id']<=previous:
                return {'accepted':False,'reason':'duplicate_or_out_of_order','source_frame_id':payload['frame_id']}
            self.frames[session]=payload['frame_id'];self.frames.move_to_end(session)
            while len(self.frames)>32:self.frames.popitem(last=False)
            self.latest=copy.deepcopy(payload);self.received=time.monotonic();self.deadline=self.received+payload['ttl_ms']/1000
            return {'accepted':True,'source_frame_id':payload['frame_id'],'execution_enabled':False}

    def clear(self):
        with self.lock:self.latest=None;self.deadline=0.

    def status(self):
        with self.lock:
            now=time.monotonic();fresh=self.latest is not None and now<self.deadline
            return {'mode':'simulation','fresh':fresh,
                    'observation':age_coordinates(self.latest,(now-self.received)*1000) if fresh else None,
                    'received_payload':copy.deepcopy(self.latest) if fresh else None,
                    'execution_enabled':False,'freshness_basis':'receiver_monotonic_ttl_plus_sender_reported_age',
                    'transport_latency_verified':False}


def serve(host='127.0.0.1',port=7011,ready=None,stop_event=None,store=None):
    stop_event=stop_event or threading.Event();store=store or ObservationStore()
    with socket.socket() as server:
        server.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1);server.bind((host,port));server.listen(4);server.settimeout(.1)
        if ready:ready(server.getsockname()[1])
        print(f'PS VISION RECEIVER {host}:{server.getsockname()[1]} (observation only)',flush=True)
        while not stop_event.is_set():
            try:connection,_=server.accept()
            except socket.timeout:continue
            with connection:
                connection.settimeout(1.);sequence=0
                try:
                    while not stop_event.is_set():
                        req=recv_packet(connection);seq=req.get('seq')
                        if type(seq) is not int or seq<=sequence:raise ProtocolError('Sequence must increase')
                        sequence=seq
                        try:
                            cmd=req.get('command')
                            if cmd=='hello':reply={'mode':'simulation','channel':'vision','protocol':1,'capabilities':['observe','vision_status','clear'],'execution_enabled':False}
                            elif cmd=='observe':reply=store.accept(req.get('observation'))
                            elif cmd=='vision_status':reply=store.status()
                            elif cmd=='clear':store.clear();reply={'cleared':True}
                            else:raise ProtocolError('Vision channel rejects control commands')
                            send_packet(connection,{'seq':seq,'ok':True,**reply})
                        except (ValueError,TypeError,KeyError) as exc:
                            send_packet(connection,{'seq':seq,'ok':False,'error':str(exc)})
                except (OSError,ConnectionError,ProtocolError):store.clear()


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--host',default='127.0.0.1');parser.add_argument('--port',type=int,default=7011)
    args=parser.parse_args()
    try:serve(args.host,args.port)
    except KeyboardInterrupt:pass

if __name__=='__main__':main()
