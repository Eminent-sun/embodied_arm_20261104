"""ROS-only process: never load PyTorch/ROCm into this interpreter."""
import argparse
import json
from pathlib import Path
import signal
import time

import rclpy
from std_msgs.msg import String


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--input',type=Path,required=True)
    parser.add_argument('--not-before',type=float,default=0)
    args=parser.parse_args()
    rclpy.init()
    node=rclpy.create_node('desktop_perception')
    publisher=node.create_publisher(String,'/perception/observations',1)
    previous=None
    print('ROS_PUBLISHER_READY',flush=True)
    try:
        while rclpy.ok():
            try:
                stamp=args.input.stat().st_mtime_ns
                if stamp!=previous:
                    payload=args.input.read_text();data=json.loads(payload)
                    captured=data['captured_at_unix_s']
                    if captured>=args.not_before and 0<=time.time()-captured<2:
                        publisher.publish(String(data=payload));previous=stamp
            except (OSError,ValueError,KeyError):pass
            rclpy.spin_once(node,timeout_sec=0.01)
    except (KeyboardInterrupt,rclpy.executors.ExternalShutdownException):pass
    finally:
        node.destroy_node()
        if rclpy.ok():rclpy.shutdown()


if __name__=='__main__':main()
