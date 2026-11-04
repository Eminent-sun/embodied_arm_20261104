"""PS protocol reference simulator. Never drives hardware or claims PL timing."""
import argparse
import hashlib
import json
import socket
import threading
import time

from .protocol import Client, HOME, ProtocolError, recv_packet, send_packet, validate_trajectory
from .cartesian import fingerprint, validate_contract, validate_target


class Simulator:
    def __init__(self,watchdog_s=1.0,cartesian_contract=None):
        self.cartesian_contract = cartesian_contract
        self.cartesian_target = None
        self.positions = HOME.copy()
        self.state = 'idle'
        self.fault = None
        self.trajectory = None
        self.trajectory_id = None
        self.gripper = 'unknown'
        self.watchdog_s = watchdog_s
        self.last_request = time.monotonic()
        self.start_time = 0

    def stop(self,reason):
        self.tick(check_watchdog=False)
        self.state,self.fault = 'stopped',reason
        self.trajectory = None
        self.trajectory_id = None

    def tick(self,check_watchdog=True):
        now = time.monotonic()
        if self.state != 'executing':return
        if check_watchdog and now-self.last_request > self.watchdog_s:
            self.stop('watchdog_timeout');return
        t = now-self.start_time
        points = self.trajectory['points']
        if t >= points[-1]['time_s']:
            self.positions = points[-1]['positions_rad'].copy()
            self.state = 'succeeded';return
        for a,b in zip(points,points[1:]):
            if a['time_s'] <= t <= b['time_s']:
                alpha = (t-a['time_s'])/(b['time_s']-a['time_s'])
                self.positions = [x+alpha*(y-x) for x,y in zip(a['positions_rad'],b['positions_rad'])]
                return

    def handle(self,request):
        self.tick()
        self.last_request = time.monotonic()
        command = request.get('command')
        if command == 'hello':
            contract_id = None
            try:
                validate_contract(self.cartesian_contract or {})
                contract_id = fingerprint(self.cartesian_contract)
            except ProtocolError:pass
            return {'mode':'simulation','board':'ALINX AX7010','protocol':1,
                    'capabilities':['trajectory','gripper','stop','status','cartesian_target'],
                    'cartesian_contract_id':contract_id,
                    'watchdog_s':self.watchdog_s,'max_velocity_rad_s':0.5}
        if command == 'set_cartesian_target':
            if request.get('confirmed') is not True or self.state in ('prepared','executing'):
                raise ProtocolError('Confirm a target while no trajectory is prepared/executing')
            target = validate_target(request.get('target'), self.cartesian_contract or {})
            self.cartesian_target = json.loads(json.dumps(target))
            return {'accepted':True,'state':'target_received','target':self.cartesian_target,
                    'execution_started':False,'ik_verified':False}
        if command == 'cartesian_status':
            return {'target':self.cartesian_target,'execution_started':False,'ik_verified':False}
        if command == 'clear_cartesian_target':
            self.cartesian_target = None
            return {'target':None,'execution_started':False}
        if command == 'upload':
            if self.state == 'executing':raise ProtocolError('Busy')
            trajectory = validate_trajectory(request['trajectory'])
            if max(abs(a-b) for a,b in zip(trajectory['points'][0]['positions_rad'],self.positions)) > 0.03:
                raise ProtocolError('Trajectory start differs from current feedback')
            self.trajectory = trajectory
            self.trajectory_id = hashlib.sha256(json.dumps(trajectory,sort_keys=True,allow_nan=False).encode()).hexdigest()
            self.state,self.fault = 'prepared',None
            return {'trajectory_id':self.trajectory_id}
        if command == 'execute':
            if self.state != 'prepared' or request.get('trajectory_id') != self.trajectory_id or request.get('confirmed') is not True:
                raise ProtocolError('Execution requires matching prepared trajectory and explicit confirmation')
            self.state,self.start_time = 'executing',time.monotonic()
        elif command == 'gripper':
            if request.get('confirmed') is not True or request.get('action') not in ['open','close']:
                raise ProtocolError('Gripper requires explicit confirmation and open/close')
            if self.state in ['executing','stopped']:
                raise ProtocolError('Gripper unavailable while moving or stopped')
            self.gripper = request['action']
        elif command == 'stop':self.stop('requested_stop')
        elif command not in ['status','heartbeat','execute']:raise ProtocolError('Unknown command')
        return {'mode':'simulation','state':self.state,'positions_rad':self.positions.copy(),
                'gripper':self.gripper,'fault':self.fault,'trajectory_id':self.trajectory_id}


def serve(host='127.0.0.1',port=7010,ready=None,stop_event=None,cartesian_contract=None):
    stop_event = stop_event or threading.Event()
    simulator = Simulator(cartesian_contract=cartesian_contract)
    with socket.socket() as server:
        server.setsockopt(socket.SOL_SOCKET,socket.SO_REUSEADDR,1)
        server.bind((host,port));server.listen(1);server.settimeout(.1)
        if ready:ready(server.getsockname()[1])
        print(f'AX7010 PS SIMULATOR on {host}:{server.getsockname()[1]} (no hardware)',flush=True)
        while not stop_event.is_set():
            try:connection,address = server.accept()
            except socket.timeout:continue
            # Single controlling session. Partial-frame timeouts close the session;
            # never attempt to parse the remainder as a new message.
            with connection:
                connection.settimeout(simulator.watchdog_s)
                last_sequence = 0
                try:
                    while not stop_event.is_set():
                        request = recv_packet(connection)
                        seq = request.get('seq')
                        if type(seq) is not int or seq <= last_sequence:
                            raise ProtocolError('Sequence must strictly increase')
                        last_sequence = seq
                        try:
                            reply = simulator.handle(request)
                            send_packet(connection,{'seq':seq,'ok':True,**reply})
                        except (ProtocolError,KeyError,TypeError,ValueError) as exc:
                            send_packet(connection,{'seq':seq,'ok':False,'error':str(exc)})
                except (ConnectionError,OSError,ProtocolError) as exc:
                    simulator.stop('link_lost_or_invalid_packet')
                    print(f'Session stopped: {exc}',flush=True)
            if simulator.state == 'executing':simulator.stop('session_closed')


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=7010)
    parser.add_argument('--cartesian-config',help='AI PC config/pickup_tcp.json with a measured contract')
    args=parser.parse_args()
    contract = None
    if args.cartesian_config:
        with open(args.cartesian_config) as source:contract=json.load(source)['contract']
    try:serve(args.host,args.port,cartesian_contract=contract)
    except KeyboardInterrupt:pass


if __name__=='__main__':main()
