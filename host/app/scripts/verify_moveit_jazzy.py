#!/usr/bin/env python3
"""Exercise FK, collision-aware IK, OMPL and dry-run execution on a running sim.

Run after sourcing scripts/env_jazzy.bash and starting start_sim_jazzy.sh.
Refuses to execute unless the bridge explicitly reports send_to_motors=False.
"""
import json
import math
from pathlib import Path
import time

import rclpy
from rclpy.action import ActionClient
from rcl_interfaces.srv import GetParameters
from sensor_msgs.msg import JointState
from moveit_msgs.action import ExecuteTrajectory
from moveit_msgs.msg import Constraints, JointConstraint, RobotState
from moveit_msgs.srv import GetMotionPlan, GetPositionFK, GetPositionIK, GetStateValidity


def main():
    rclpy.init()
    node = rclpy.create_node("roboarm_sim_verification")
    report = {}
    latest = {}
    joint_names = [f"joint{i}" for i in range(1, 7)]

    def receive(msg):
        latest.update(zip(msg.name, msg.position))

    subscription = node.create_subscription(JointState, "/joint_states", receive, 10)

    def finish(future, timeout=30.0):
        rclpy.spin_until_future_complete(node, future, timeout_sec=timeout)
        if not future.done():
            raise RuntimeError("ROS request timed out")
        return future.result()

    def service(kind, name):
        client = node.create_client(kind, name)
        if not client.wait_for_service(timeout_sec=20.0):
            raise RuntimeError(f"Service unavailable: {name}")
        return lambda req: finish(client.call_async(req))

    def state(values):
        result = RobotState()
        result.joint_state.name = joint_names
        result.joint_state.position = list(values)
        return result

    try:
        parameters = service(GetParameters, "/moveit_execute_motor_action_server/get_parameters")
        check = parameters(GetParameters.Request(names=["send_to_motors", "use_actual_feedback"]))
        if any(value.type != 1 or value.bool_value for value in check.values) or len(check.values) != 2:
            raise RuntimeError("Verification requires explicitly disabled motors and actual feedback")
        report["dry_run_confirmed"] = True
        deadline = time.monotonic() + 10
        while len(latest) < 6 and time.monotonic() < deadline:
            rclpy.spin_once(node, timeout_sec=0.1)
        if len(latest) < 6:
            raise RuntimeError("No six-joint state received")
        start = state([latest[name] for name in joint_names])
        validity = service(GetStateValidity, "/check_state_validity")
        valid = validity(GetStateValidity.Request(robot_state=start, group_name="arm"))
        report["start_valid"] = valid.valid
        if not valid.valid:
            raise RuntimeError(f"Start state collides: {valid.contacts}")
        fk = service(GetPositionFK, "/compute_fk")
        ik = service(GetPositionIK, "/compute_ik")
        samples = [
            [0.12, 1.70, -0.22, 0.10, 1.35, 0.08],
            [-0.12, 1.80, -0.30, -0.08, 1.25, -0.10],
            [0.08, 1.60, -0.12, 0.05, 1.45, 0.04],
        ]
        report["ik_samples"] = []
        solution = None
        for values in samples:
            target_state = state(values)
            valid = validity(GetStateValidity.Request(robot_state=target_state, group_name="arm"))
            if not valid.valid:
                raise RuntimeError(f"Test target collides: {values}")
            request = GetPositionFK.Request(robot_state=target_state, fk_link_names=["Link6"])
            request.header.frame_id = "base_link"
            target = fk(request)
            if target.error_code.val != 1:
                raise RuntimeError(f"FK failed: {target.error_code.val}")
            request_ik = GetPositionIK.Request()
            request_ik.ik_request.group_name = "arm"
            request_ik.ik_request.ik_link_name = "Link6"
            request_ik.ik_request.robot_state = start
            request_ik.ik_request.pose_stamped = target.pose_stamped[0]
            request_ik.ik_request.avoid_collisions = True
            request_ik.ik_request.timeout.sec = 2
            answer = ik(request_ik)
            if answer.error_code.val != 1:
                raise RuntimeError(f"IK failed: {answer.error_code.val}")
            request.robot_state = answer.solution
            actual = fk(request)
            a, b = target.pose_stamped[0].pose, actual.pose_stamped[0].pose
            distance = math.sqrt(sum((getattr(a.position, k) - getattr(b.position, k))**2 for k in "xyz"))
            dot = abs(sum(getattr(a.orientation, k) * getattr(b.orientation, k) for k in "xyzw"))
            angle = 2 * math.acos(min(1.0, dot))
            if distance > 1e-4 or angle > 1e-3:
                raise RuntimeError(f"IK residual too large: {distance} m, {angle} rad")
            report["ik_samples"].append({"target_joints": values, "position_error_m": distance, "orientation_error_rad": angle})
            solution = answer.solution
        request_ik.ik_request.pose_stamped.pose.position.x = 10.0
        request_ik.ik_request.timeout.sec = 0
        request_ik.ik_request.timeout.nanosec = 100000000
        unreachable = ik(request_ik)
        if unreachable.error_code.val == 1:
            raise RuntimeError("Unreachable target unexpectedly accepted")
        report["unreachable_target_error_code"] = unreachable.error_code.val
        planner = service(GetMotionPlan, "/plan_kinematic_path")
        request = GetMotionPlan.Request()
        plan = request.motion_plan_request
        plan.start_state = start
        plan.group_name = "arm"
        plan.pipeline_id = "ompl"
        plan.planner_id = "RRTConnect"
        plan.num_planning_attempts = 3
        plan.allowed_planning_time = 5.0
        plan.max_velocity_scaling_factor = 0.1
        plan.max_acceleration_scaling_factor = 0.1
        plan.workspace_parameters.header.frame_id = "base_link"
        plan.workspace_parameters.min_corner.x = -1.0
        plan.workspace_parameters.min_corner.y = -1.0
        plan.workspace_parameters.min_corner.z = -1.0
        plan.workspace_parameters.max_corner.x = 1.0
        plan.workspace_parameters.max_corner.y = 1.0
        plan.workspace_parameters.max_corner.z = 1.0
        goal = Constraints()
        for name, value in zip(solution.joint_state.name, solution.joint_state.position):
            if name in joint_names:
                goal.joint_constraints.append(JointConstraint(joint_name=name, position=value, tolerance_above=0.0001, tolerance_below=0.0001, weight=1.0))
        plan.goal_constraints = [goal]
        response = planner(request).motion_plan_response
        if response.error_code.val != 1:
            raise RuntimeError(f"Planning failed: {response.error_code.val}")
        trajectory = response.trajectory.joint_trajectory
        if len(trajectory.points) < 2:
            raise RuntimeError("Empty/degenerate trajectory")
        times = [p.time_from_start.sec + p.time_from_start.nanosec / 1e9 for p in trajectory.points]
        if any(b <= a for a, b in zip(times, times[1:])):
            raise RuntimeError("Trajectory timing is not increasing")
        for point in trajectory.points:
            sample = RobotState()
            sample.joint_state.name = trajectory.joint_names
            sample.joint_state.position = point.positions
            if not validity(GetStateValidity.Request(robot_state=sample, group_name="arm")).valid:
                raise RuntimeError("Planned trajectory contains invalid state")
        report["planning"] = {"error_code": response.error_code.val, "points": len(trajectory.points), "duration_s": times[-1], "planning_time_s": response.planning_time, "all_waypoints_valid": True}
        executor = ActionClient(node, ExecuteTrajectory, "/execute_trajectory")
        if not executor.wait_for_server(timeout_sec=10.0):
            raise RuntimeError("ExecuteTrajectory server missing")
        handle = finish(executor.send_goal_async(ExecuteTrajectory.Goal(trajectory=response.trajectory)))
        if not handle.accepted:
            raise RuntimeError("Execution rejected")
        result = finish(handle.get_result_async()).result
        if result.error_code.val != 1:
            raise RuntimeError(f"Execution failed: {result.error_code.val}")
        expected = dict(zip(trajectory.joint_names, trajectory.points[-1].positions))
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            rclpy.spin_once(node, timeout_sec=0.1)
            if max(abs(latest[n] - expected[n]) for n in joint_names) < 0.001:
                break
        error = max(abs(latest[n] - expected[n]) for n in joint_names)
        if error > 0.001:
            raise RuntimeError(f"Final joint error: {error}")
        report["execution"] = {"error_code": result.error_code.val, "max_joint_error_rad": error}
        report["passed"] = True
    except Exception as exc:
        report["passed"] = False
        report["error"] = str(exc)
        raise
    finally:
        output = Path(__file__).resolve().parents[1] / ".jazzy/verification.json"
        output.write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2), flush=True)
        node.destroy_subscription(subscription)
        node.destroy_node()
        rclpy.shutdown()


if __name__ == "__main__":
    main()
