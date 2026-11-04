"""MoveIt FollowJointTrajectory adapter for the versioned PS TCP interface.

Simulation endpoint only in this revision. Real PS/PL control must implement
feedback freshness, physical limits, watchdog and emergency-stop integration.
"""
import argparse
import threading
import time

import rclpy
from control_msgs.action import FollowJointTrajectory
from rclpy.action import ActionServer, CancelResponse, GoalResponse
from rclpy.callback_groups import ReentrantCallbackGroup
from rclpy.executors import MultiThreadedExecutor
from rclpy.node import Node
from sensor_msgs.msg import JointState

from .protocol import Client, JOINTS, ProtocolError, validate_trajectory


class Bridge(Node):
    def __init__(self,host,port):
        super().__init__('ax7010_trajectory_bridge')
        self.client=Client(host,port)
        hello=self.client.request('hello')
        if hello.get('mode')!='simulation':
            self.client.close()
            raise RuntimeError('This bridge revision permits PS simulator only; hardware integration is not commissioned')
        self.lock=threading.RLock()
        self.busy=False
        self.connected=True
        self.positions=None
        self.publisher=self.create_publisher(JointState,'/joint_states',10)
        self.group=ReentrantCallbackGroup()
        self.timer=self.create_timer(.05,self.poll,callback_group=self.group)
        self.server=ActionServer(self,FollowJointTrajectory,'/arm_controller/follow_joint_trajectory',
            execute_callback=self.execute,goal_callback=self.goal,cancel_callback=lambda _:CancelResponse.ACCEPT,
            callback_group=self.group)
        self.get_logger().info(f'Connected to AX7010 protocol simulator {host}:{port}; no motor driver')

    def request(self,command,**fields):
        with self.lock:return self.client.request(command,**fields)

    def poll(self):
        if not self.connected:return
        try:
            with self.lock:
                state=self.client.request('status')
                self.positions=state['positions_rad']
            msg=JointState()
            msg.header.stamp=self.get_clock().now().to_msg()
            msg.name=JOINTS;msg.position=list(self.positions)
            self.publisher.publish(msg)
        except Exception as exc:
            self.connected=False
            self.get_logger().error(f'PS feedback lost; joint states stopped: {exc}')

    @staticmethod
    def convert(trajectory):
        if sorted(trajectory.joint_names)!=sorted(JOINTS):
            raise ProtocolError('Expected exactly six arm joints')
        order=[trajectory.joint_names.index(n) for n in JOINTS]
        result={'joint_names':JOINTS,'points':[]}
        for point in trajectory.points:
            if len(point.positions)!=6:raise ProtocolError('Malformed trajectory point')
            result['points'].append({'time_s':point.time_from_start.sec+point.time_from_start.nanosec/1e9,
                                    'positions_rad':[point.positions[i] for i in order]})
        return validate_trajectory(result)

    def goal(self,request):
        with self.lock:
            if self.busy or not self.connected:return GoalResponse.REJECT
            try:self.convert(request.trajectory)
            except (ValueError,IndexError,TypeError):return GoalResponse.REJECT
            self.busy=True
        return GoalResponse.ACCEPT

    def execute(self,handle):
        result=FollowJointTrajectory.Result()
        try:
            trajectory=self.convert(handle.request.trajectory)
            token=self.request('upload',trajectory=trajectory)['trajectory_id']
            # Receipt of a MoveIt Execute action is the execution trigger.
            # Perception never invokes this action; the operator must select Execute.
            self.request('execute',trajectory_id=token,confirmed=True)
            deadline=time.monotonic()+trajectory['points'][-1]['time_s']+3
            while time.monotonic()<deadline:
                if handle.is_cancel_requested:
                    self.request('stop');handle.canceled();return result
                state=self.request('status')
                feedback=FollowJointTrajectory.Feedback()
                feedback.header.stamp=self.get_clock().now().to_msg()
                feedback.joint_names=JOINTS
                feedback.actual.positions=state['positions_rad']
                handle.publish_feedback(feedback)
                if state['state']=='succeeded':
                    if max(abs(a-b) for a,b in zip(state['positions_rad'],trajectory['points'][-1]['positions_rad']))>.01:
                        raise RuntimeError('Final position tolerance exceeded')
                    result.error_code=result.SUCCESSFUL;handle.succeed();return result
                if state['state']!='executing':raise RuntimeError(f'PS stopped: {state}')
                time.sleep(.05)
            raise TimeoutError('Execution deadline exceeded')
        except Exception as exc:
            try:self.request('stop')
            except Exception:pass
            result.error_code=result.PATH_TOLERANCE_VIOLATED
            result.error_string=str(exc)
            handle.abort();return result
        finally:
            with self.lock:self.busy=False


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--host',default='127.0.0.1')
    parser.add_argument('--port',type=int,default=7010)
    args=parser.parse_args()
    rclpy.init()
    node=None
    executor=MultiThreadedExecutor(num_threads=4)
    try:
        node=Bridge(args.host,args.port);executor.add_node(node);executor.spin()
    except KeyboardInterrupt:pass
    finally:
        if node:
            try:node.request('stop')
            except Exception:pass
            node.client.close()
        executor.shutdown(timeout_sec=3)
        if node:node.destroy_node()
        if rclpy.ok():rclpy.shutdown()


if __name__=='__main__':main()
