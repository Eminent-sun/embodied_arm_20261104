"""Relay fresh atomic vision JSON to PS without loading ROS, camera or PyTorch."""
import argparse
import json
from pathlib import Path
import time
import os
from .protocol import Client,ProtocolError
from .vision_protocol import observation_payload


def save_status(path,data):
    if path is None:return
    path=Path(path);path.parent.mkdir(parents=True,exist_ok=True)
    temp=path.with_suffix('.tmp');temp.write_text(json.dumps(data,allow_nan=False));os.replace(temp,path)


def relay_once(client,path,previous=None,source_session_id=None,status_path=None):
    obs=json.loads(Path(path).read_text())
    if source_session_id and obs.get('source_session_id')!=source_session_id:raise ProtocolError('Different perception session')
    payload=observation_payload(obs);key=(payload['source_session_id'],payload['frame_id'])
    if key==previous:return previous,None
    sent=time.time();reply=client.request('observe',observation=payload)
    save_status(status_path,{'state':'acknowledged' if reply.get('accepted') else 'rejected',
                            'sent_at_unix_s':sent,'ack_at_unix_s':time.time(),
                            'expires_at_unix_s':sent+payload['ttl_ms']/1000,
                            'payload':payload,'reply':reply})
    return key,reply


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--host',default='127.0.0.1');parser.add_argument('--port',type=int,default=7011)
    parser.add_argument('--input',type=Path,default=Path(__file__).resolve().parents[2]/'runtime/vision/latest.json')
    parser.add_argument('--hz',type=float,default=10.);parser.add_argument('--once',action='store_true')
    parser.add_argument('--source-session-id')
    parser.add_argument('--status-output',type=Path,default=Path(__file__).resolve().parents[2]/'runtime/vision/link_status.json')
    args=parser.parse_args()
    if not 0<args.hz<=30:parser.error('--hz must be in (0, 30]')
    client=None;previous=None;cleared=False;last_ping=0.
    try:
        while True:
            try:
                if client is None:
                    client=Client(args.host,args.port,timeout=.75);hello=client.request('hello')
                    if hello.get('channel')!='vision' or 'observe' not in hello.get('capabilities',[]):
                        raise ProtocolError('Endpoint does not advertise vision observations')
                    previous=None;cleared=False
                try:
                    previous,reply=relay_once(client,args.input,previous,args.source_session_id,args.status_output);cleared=False
                    if reply:print(json.dumps(reply),flush=True)
                    if args.once:return
                except (OSError,ValueError,KeyError,TypeError) as exc:
                    if args.once:raise
                    if not cleared:
                        print(f'Vision observations unavailable: {exc}',flush=True)
                        client.request('clear');cleared=True
                        save_status(args.status_output,{'state':'cleared','reason':str(exc),'updated_at_unix_s':time.time()})
                if time.monotonic()-last_ping>.3:client.request('vision_status');last_ping=time.monotonic()
            except (OSError,ConnectionError,ValueError,KeyError,TypeError) as exc:
                if args.once:raise
                print(f'Vision link: {exc}',flush=True)
                if client:client.close()
                save_status(args.status_output,{'state':'disconnected','reason':str(exc),'updated_at_unix_s':time.time()})
                client=None;time.sleep(.5)
            time.sleep(1/args.hz)
    except KeyboardInterrupt:pass
    finally:
        save_status(args.status_output,{'state':'stopped','updated_at_unix_s':time.time()})
        if client:
            try:client.request('clear')
            except (OSError,ValueError):pass
            client.close()

if __name__=='__main__':main()
