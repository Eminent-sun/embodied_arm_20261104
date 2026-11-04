import json
import math
import socket
import struct
import zlib

MAGIC = b'ARM1'
VERSION = 1
HEADER = struct.Struct('!4sIII')  # magic, protocol version, byte length, CRC32
MAX_PACKET = 1024*1024
JOINTS = [f'joint{i}' for i in range(1,7)]
LIMITS = [(-3.14,3.14),(.39571,3.223736),(-3.027351,.074481),(-3.14,3.14),(-1.545172,1.57),(-3.14,3.14)]
HOME = [0.0,1.57,0.0,0.0,1.57,0.0]


class ProtocolError(ValueError):
    pass


def read_exact(sock, size):
    data = bytearray()
    while len(data) < size:
        chunk = sock.recv(size-len(data))
        if not chunk:
            raise ConnectionError('Peer disconnected')
        data.extend(chunk)
    return bytes(data)


def send_packet(sock, payload):
    body = json.dumps(payload,separators=(',',':'),allow_nan=False).encode('utf-8')
    if len(body) > MAX_PACKET:
        raise ProtocolError('Packet too large')
    sock.sendall(HEADER.pack(MAGIC,VERSION,len(body),zlib.crc32(body))+body)


def recv_packet(sock):
    magic,version,length,checksum = HEADER.unpack(read_exact(sock,HEADER.size))
    if magic != MAGIC or version != VERSION or not 0 < length <= MAX_PACKET:
        raise ProtocolError('Invalid header/version/length')
    body = read_exact(sock,length)
    if zlib.crc32(body) != checksum:
        raise ProtocolError('CRC mismatch')
    try:
        payload = json.loads(body,parse_constant=lambda _: (_ for _ in ()).throw(ProtocolError('Non-finite JSON')))
    except (UnicodeError,json.JSONDecodeError) as exc:
        raise ProtocolError('Invalid JSON') from exc
    if not isinstance(payload,dict):
        raise ProtocolError('Expected JSON object')
    return payload


def validate_trajectory(trajectory, max_velocity=0.5):
    if trajectory.get('joint_names') != JOINTS:
        raise ProtocolError('Joint order must be joint1..joint6')
    points = trajectory.get('points')
    if not isinstance(points,list) or not 2 <= len(points) <= 1000:
        raise ProtocolError('Expected 2..1000 trajectory points')
    previous_t, previous_q = None, None
    for index,point in enumerate(points):
        t,q = point.get('time_s'),point.get('positions_rad')
        if isinstance(t,bool) or not isinstance(t,(int,float)) or not math.isfinite(t) or not 0 <= t <= 120:
            raise ProtocolError('Invalid trajectory time')
        if index == 0 and t != 0:
            raise ProtocolError('First trajectory point must have time_s=0')
        if not isinstance(q,list) or len(q) != 6:
            raise ProtocolError('Expected six positions')
        for value,(lower,upper) in zip(q,LIMITS):
            if isinstance(value,bool) or not isinstance(value,(int,float)) or not math.isfinite(value) or not lower <= value <= upper:
                raise ProtocolError('Joint position outside finite bounds')
        if previous_t is not None:
            if t <= previous_t:
                raise ProtocolError('Non-increasing trajectory time')
            if max(abs(a-b)/(t-previous_t) for a,b in zip(q,previous_q)) > max_velocity+1e-6:
                raise ProtocolError('Segment velocity exceeds configured limit')
        previous_t,previous_q = t,q
    return trajectory


class Client:
    def __init__(self,host='127.0.0.1',port=7010,timeout=2.0):
        self.sock = socket.create_connection((host,port),timeout=timeout)
        self.sock.settimeout(timeout)
        self.sequence = 0

    def request(self,command,**fields):
        self.sequence += 1
        send_packet(self.sock,{'seq':self.sequence,'command':command,**fields})
        reply = recv_packet(self.sock)
        if reply.get('seq') != self.sequence:
            raise ProtocolError('Response sequence mismatch')
        if not reply.get('ok'):
            raise ProtocolError(reply.get('error','Request rejected'))
        return reply

    def close(self):
        self.sock.close()
