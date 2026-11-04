"""System-Python ROS process. Calls planning services only, never execution actions."""
import copy
import math
import hashlib
import time
import numpy as np
import rclpy
from rclpy.node import Node
from geometry_msgs.msg import Pose
from sensor_msgs.msg import JointState
from moveit_msgs.msg import (RobotState,Constraints,JointConstraint,PlanningScene,CollisionObject,
    AttachedCollisionObject,AllowedCollisionEntry,PlanningSceneComponents,DisplayTrajectory)
from moveit_msgs.srv import (GetPositionFK,GetPositionIK,GetMotionPlan,GetCartesianPath,
    GetStateValidity,ApplyPlanningScene,GetPlanningScene)
from shape_msgs.msg import SolidPrimitive
from rcl_interfaces.srv import GetParameters
from robotarm_link.protocol import JOINTS
from .core import PlanningError,pose_matrix,matrix_pose,bounded_trajectory,validate_request


def ros_pose(data):
    msg=Pose()
    for key,value in zip('xyz',data['position_m']):setattr(msg.position,key,float(value))
    for key,value in zip('xyzw',data['quaternion_xyzw']):setattr(msg.orientation,key,float(value))
    return msg


def pose_data(msg):
    return {'position_m':[getattr(msg.position,k) for k in 'xyz'],
            'quaternion_xyzw':[getattr(msg.orientation,k) for k in 'xyzw']}


class MoveItPlanner(Node):
    def __init__(self):
        super().__init__('aipc_plan_only')
        self.latest={};self.received=0.;self._service_clients={};self.cancelled=False
        self.sub=self.create_subscription(JointState,'/joint_states',self.receive,10)
        self.display=self.create_publisher(DisplayTrajectory,'/display_planned_path',10)

    def receive(self,msg):
        if len(msg.name)!=len(msg.position):return
        values=dict(zip(msg.name,msg.position))
        if not all(n in values and math.isfinite(values[n]) for n in JOINTS):return
        stamp=msg.header.stamp.sec+msg.header.stamp.nanosec/1e9
        if stamp and abs(self.get_clock().now().nanoseconds/1e9-stamp)>.5:return
        self.latest={n:values[n] for n in JOINTS};self.received=time.monotonic()

    def call(self,kind,name,req,timeout=15.):
        client=self._service_clients.get(name)
        if client is None:
            client=self.create_client(kind,name);self._service_clients[name]=client
            if not client.wait_for_service(timeout_sec=8):raise PlanningError(f'MoveIt service unavailable: {name}')
        future=client.call_async(req)
        rclpy.spin_until_future_complete(self,future,timeout_sec=timeout)
        if not future.done():future.cancel();raise PlanningError(f'MoveIt timeout: {name}')
        if future.exception():raise PlanningError(str(future.exception()))
        return future.result()

    def current(self):
        deadline=time.monotonic()+4
        while time.monotonic()<deadline:
            rclpy.spin_once(self,timeout_sec=.05)
            if self.latest and time.monotonic()-self.received<.5:return [self.latest[n] for n in JOINTS]
        raise PlanningError('No fresh complete six-joint feedback')

    @staticmethod
    def state(q):
        state=RobotState();state.is_diff=True;state.joint_state.name=JOINTS;state.joint_state.position=list(map(float,q));return state

    def fk(self,q):
        req=GetPositionFK.Request();req.header.frame_id='base_link';req.fk_link_names=['Link6'];req.robot_state=self.state(q)
        res=self.call(GetPositionFK,'/compute_fk',req)
        if res.error_code.val!=1:raise PlanningError(f'FK failed: {res.error_code.val}')
        return pose_data(res.pose_stamped[0].pose)

    def valid(self,q):
        req=GetStateValidity.Request();req.group_name='arm';req.robot_state=self.state(q)
        res=self.call(GetStateValidity,'/check_state_validity',req)
        if not res.valid:
            contacts=[(c.contact_body_1,c.contact_body_2) for c in res.contacts]
            raise PlanningError(f'Collision or invalid joint state: {contacts}')

    def scene(self):
        req=GetPlanningScene.Request();req.components.components=(PlanningSceneComponents.WORLD_OBJECT_GEOMETRY|
            PlanningSceneComponents.ROBOT_STATE_ATTACHED_OBJECTS|PlanningSceneComponents.ALLOWED_COLLISION_MATRIX)
        return self.call(GetPlanningScene,'/get_planning_scene',req).scene

    def apply(self,scene):
        scene.is_diff=True;scene.robot_state.is_diff=True
        res=self.call(ApplyPlanningScene,'/apply_planning_scene',ApplyPlanningScene.Request(scene=scene))
        if not res.success:raise PlanningError('MoveIt rejected collision scene')

    @staticmethod
    def box(name,data,frame='base_link'):
        obj=CollisionObject();obj.id=name;obj.header.frame_id=frame;obj.operation=CollisionObject.ADD
        primitive=SolidPrimitive();primitive.type=SolidPrimitive.BOX;primitive.dimensions=list(map(float,data['size_m']))
        obj.primitives=[primitive];obj.primitive_poses=[ros_pose(data['pose'])];return obj

    def configure_scene(self,req):
        previous=self.scene();scene=PlanningScene()
        for obj in previous.world.collision_objects:
            if obj.id.startswith('aipc_'):
                remove=CollisionObject();remove.id=obj.id;remove.operation=CollisionObject.REMOVE;scene.world.collision_objects.append(remove)
        for attached in previous.robot_state.attached_collision_objects:
            if attached.object.id.startswith('aipc_'):
                remove=AttachedCollisionObject();remove.object.id=attached.object.id;remove.object.operation=CollisionObject.REMOVE
                scene.robot_state.attached_collision_objects.append(remove)
        self.apply(scene)
        scene=PlanningScene();self.acm=copy.deepcopy(previous.allowed_collision_matrix)
        # Preserve SRDF/user exclusions; allow only target contact with the end link/gripper envelope.
        names=['aipc_target','Link6']+[f'aipc_gripper_{i}' for i in range(len(req['config']['gripper']['collision_boxes']))]
        collision_names=names+(['aipc_hand']+self.robot_links if req.get('task_kind')=='tool_handover' else [])
        for name in collision_names:
            if name not in self.acm.entry_names:
                self.acm.entry_names.append(name)
                for entry in self.acm.entry_values:entry.enabled.append(False)
                self.acm.entry_values.append(AllowedCollisionEntry(enabled=[False]*len(self.acm.entry_names)))
        if req.get('task_kind')=='tool_handover':
            if 'aipc_hand' not in self.acm.default_entry_names:
                self.acm.default_entry_names.append('aipc_hand');self.acm.default_entry_values.append(False)
            else:self.acm.default_entry_values[self.acm.default_entry_names.index('aipc_hand')]=False
            hi=self.acm.entry_names.index('aipc_hand')
            for i in range(len(self.acm.entry_names)):
                self.acm.entry_values[hi].enabled[i]=False;self.acm.entry_values[i].enabled[hi]=False
        ti=self.acm.entry_names.index('aipc_target')
        for name in names[1:]:
            i=self.acm.entry_names.index(name);self.acm.entry_values[ti].enabled[i]=True;self.acm.entry_values[i].enabled[ti]=True
        # Contact allowance starts only for the grasp descent, not the approach.
        self.contact_acm=copy.deepcopy(self.acm)
        for name in names[1:]:
            i=self.acm.entry_names.index(name);self.acm.entry_values[ti].enabled[i]=False;self.acm.entry_values[i].enabled[ti]=False
        scene.allowed_collision_matrix=self.acm
        for i,box in enumerate(req['config']['scene_boxes']):scene.world.collision_objects.append(self.box(f'aipc_scene_{i}',box))
        scene.world.collision_objects.append(self.box('aipc_target',req['object']))
        if req.get('task_kind')=='tool_handover':
            scene.world.collision_objects.append(self.box('aipc_hand',req['handover']['hand_collision_box']))
        for i,box in enumerate(req['config']['gripper']['collision_boxes']):
            attached=AttachedCollisionObject();attached.link_name='Link6';attached.touch_links=['Link6']
            attached.object=self.box(f'aipc_gripper_{i}',box,'Link6');scene.robot_state.attached_collision_objects.append(attached)
        self.apply(scene)
        # Replacing world/attached objects may remove their ACM entries while
        # MoveIt applies the diff. Set exclusions AFTER the geometry mutations.
        constraints=PlanningScene();constraints.allowed_collision_matrix=self.acm;self.apply(constraints)

    def contact(self,enabled):
        scene=PlanningScene();scene.allowed_collision_matrix=self.contact_acm if enabled else self.acm;self.apply(scene)

    def attach(self,world_object,link_pose):
        relative=matrix_pose(np.linalg.inv(pose_matrix(link_pose))@pose_matrix(world_object['pose']))
        # MoveIt removes the matching world object when attaching it. A second
        # REMOVE in the same diff would fail after that implicit removal.
        scene=PlanningScene()
        obj=AttachedCollisionObject();obj.link_name='Link6';obj.touch_links=['Link6']
        obj.object=self.box('aipc_target',{'size_m':world_object['size_m'],'pose':relative},'Link6')
        scene.robot_state.attached_collision_objects=[obj];self.apply(scene)
        return relative

    def detach(self,size,relative,link_pose):
        scene=PlanningScene();remove=AttachedCollisionObject();remove.object.id='aipc_target';remove.object.operation=CollisionObject.REMOVE
        scene.robot_state.attached_collision_objects=[remove]
        world=matrix_pose(pose_matrix(link_pose)@pose_matrix(relative));scene.world.collision_objects=[self.box('aipc_target',{'size_m':size,'pose':world})]
        self.apply(scene)

    def ik(self,pose,start):
        req=GetPositionIK.Request();r=req.ik_request;r.group_name='arm';r.ik_link_name='Link6'
        r.robot_state=self.state(start);r.pose_stamped.header.frame_id='base_link';r.pose_stamped.pose=ros_pose(pose)
        r.avoid_collisions=True;r.timeout.sec=2
        res=self.call(GetPositionIK,'/compute_ik',req)
        if res.error_code.val!=1:raise PlanningError(f'Collision-aware IK failed: {res.error_code.val}')
        values=dict(zip(res.solution.joint_state.name,res.solution.joint_state.position));return [values[n] for n in JOINTS]

    def segment(self,stage,start,cfg):
        if stage['method']=='ompl':
            goal=self.ik(stage['link_pose_base'],start)
            req=GetMotionPlan.Request();r=req.motion_plan_request
            r.start_state=self.state(start);r.group_name='arm';r.pipeline_id='ompl';r.planner_id='RRTConnect'
            r.num_planning_attempts=3;r.allowed_planning_time=5.
            r.max_velocity_scaling_factor=.02;r.max_acceleration_scaling_factor=.02
            r.workspace_parameters.header.frame_id='base_link'
            for key,lo,hi in zip('xyz',cfg['workspace_min_m'],cfg['workspace_max_m']):
                setattr(r.workspace_parameters.min_corner,key,float(lo));setattr(r.workspace_parameters.max_corner,key,float(hi))
            constraints=Constraints()
            constraints.joint_constraints=[JointConstraint(joint_name=n,position=float(v),tolerance_above=.0005,tolerance_below=.0005,weight=1.) for n,v in zip(JOINTS,goal)]
            r.goal_constraints=[constraints]
            # Replan boundedly when response validation rejects a sampled path.
            # Keep every collision check enabled; never export a partial failure.
            for attempt in range(3):
                res=self.call(GetMotionPlan,'/plan_kinematic_path',req).motion_plan_response
                if res.error_code.val==1:break
            if res.error_code.val!=1:raise PlanningError(f'OMPL failed: {res.error_code.val}')
            trajectory=res.trajectory;fraction=1.
        else:
            req=GetCartesianPath.Request();req.header.frame_id='base_link';req.start_state=self.state(start)
            req.group_name='arm';req.link_name='Link6';req.waypoints=[ros_pose(stage['link_pose_base'])]
            req.max_step=.005;req.jump_threshold=2.;req.revolute_jump_threshold=.25;req.avoid_collisions=True
            req.max_velocity_scaling_factor=.02;req.max_acceleration_scaling_factor=.02
            res=self.call(GetCartesianPath,'/compute_cartesian_path',req)
            if res.error_code.val!=1 or res.fraction<.999999:raise PlanningError(f'Cartesian path incomplete: code={res.error_code.val}, fraction={res.fraction}')
            trajectory=res.solution;fraction=res.fraction
        jt=trajectory.joint_trajectory
        points=[{'positions':list(p.positions),'time_s':p.time_from_start.sec+p.time_from_start.nanosec/1e9} for p in jt.points]
        wire=bounded_trajectory(list(jt.joint_names),points,cfg['max_joint_velocity_rad_s'],cfg['max_joint_acceleration_rad_s2'])
        q0=wire['points'][0]['positions_rad']
        if max(abs(a-b) for a,b in zip(start,q0))>.005:raise PlanningError('Trajectory start is discontinuous')
        # Dense joint interpolation checks also cover the position-only PS interpolation.
        samples=0
        for a,b in zip(wire['points'],wire['points'][1:]):
            qa=np.array(a['positions_rad']);qb=np.array(b['positions_rad']);n=max(1,int(np.ceil(np.max(np.abs(qb-qa))/.02)))
            for i in range(n):self.valid((qa+(qb-qa)*i/n).tolist());samples+=1
            if samples>3000:raise PlanningError('Collision-check budget exceeded')
        end=wire['points'][-1]['positions_rad'];self.valid(end)
        actual=self.fk(end);expected=stage['link_pose_base'];distance=math.dist(actual['position_m'],expected['position_m'])
        dot=abs(float(np.dot(actual['quaternion_xyzw'],expected['quaternion_xyzw'])));angle=2*math.acos(min(1.,dot))
        if distance>.002 or angle>.02:raise PlanningError(f'Final FK residual too high: {distance}m {angle}rad')
        # Publish the retimed path rather than the original faster service trajectory.
        order=[JOINTS.index(n) for n in jt.joint_names]
        for point,export in zip(jt.points,wire['points']):
            t=export['time_s'];point.time_from_start.sec=int(t);point.time_from_start.nanosec=int(round((t-int(t))*1e9))
            if point.time_from_start.nanosec>=1000000000:point.time_from_start.sec+=1;point.time_from_start.nanosec=0
            point.velocities=[];point.accelerations=[]
        tcp_path=[]
        for index in sorted(set(list(range(0,len(wire['points']),max(1,len(wire['points'])//30)))+[len(wire['points'])-1])):
            link=self.fk(wire['points'][index]['positions_rad'])
            tcp_path.append((pose_matrix(link)@pose_matrix(cfg['gripper']['link_to_tcp']))[:3,3].tolist())
        return {**stage,'trajectory':wire,'tcp_path_base_m':tcp_path,'cartesian_fraction':fraction,'collision_samples_checked':samples+1,
                'endpoint_error_m':distance,'endpoint_error_rad':angle},trajectory,end

    def plan(self,request,progress=None):
        validate_request(request);cfg=request['config'];start=self.current();stages=[];messages=[]
        parameters=self.call(GetParameters,'/move_group/get_parameters',GetParameters.Request(names=['robot_description']))
        if len(parameters.values)!=1 or not parameters.values[0].string_value:raise PlanningError('Active robot model unavailable')
        model_hash=hashlib.sha256(parameters.values[0].string_value.encode()).hexdigest()
        import xml.etree.ElementTree as ET
        self.robot_links=[link.attrib['name'] for link in ET.fromstring(parameters.values[0].string_value).findall('link')]
        if request['mode']=='measured' and (not cfg.get('robot_model_reviewed') or cfg.get('robot_description_sha256')!=model_hash):raise PlanningError('Active MoveIt model differs from the reviewed physical model')
        self.configure_scene(request);initial=self.scene();relative=None
        try:
            self.valid(start);q=start
            for stage in request['stages']:
                if progress:progress(stage['name'])
                if stage['name']=='grasp':self.contact(True)
                planned,message,q=self.segment(stage,q,cfg);stages.append(planned);messages.append(message)
                if stage['name']=='grasp':relative=self.attach(request['object'],self.fk(q))
                if stage['name']=='place':self.detach(request['object']['size_m'],relative,self.fk(q))
            display=DisplayTrajectory();display.trajectory_start=self.state(start);display.trajectory=messages;self.display.publish(display)
            from .handover import handover_events
            is_handover=request.get('task_kind')=='tool_handover'
            is_pickup=request.get('task_kind')=='tabletop_pickup'
            pickup_events=[{'before':'approach','gripper':'open','requires':['operator_task_confirmation']},
                           {'after':'grasp','gripper':'close','requires':['grasp_reached']},
                           {'before':'lift','barrier':'verify_grip','requires':['gripper_ack','grip_feedback']},
                           {'after':'lift','barrier':'hold_tool','automatic_release':False}]
            return {'schema_version':1,'status':'planned_for_review','mode':request['mode'],'frame_id':'base_link','units':'m',
                    'task_kind':request.get('task_kind','pick_place'),'handover':request.get('handover'),
                    'terminal_state':'await_handover' if is_handover else 'hold_tool' if is_pickup else 'placed',
                    'automatic_release':False,
                    'execution_enabled':False,'controller_commands_sent':False,'start_joints_rad':start,
                    'robot_description_sha256':model_hash,
                    'start_state_source':'ROS joint_states; physical encoder commissioning not verified',
                    'point_base_m':request.get('point_base_m'),'target_lock':request.get('target_lock'),
                    'calibration_id':request.get('calibration_id'),'config_sha256':request['config_sha256'],
                    'segments':stages,'events':handover_events() if is_handover else pickup_events if is_pickup else [{'before':'approach','gripper':'open'},{'after':'grasp','gripper':'close'},{'after':'place','gripper':'open'}],
                    'handover_region':cfg.get('handover_regions',{}).get(request.get('handover',{}).get('region_name')) if is_handover else None,
                    'hand_collision_checked':is_handover,
                    'scene_boxes':cfg['scene_boxes'],'carried_object_envelope_checked':True,
                    'duration_s':sum(s['trajectory']['points'][-1]['time_s'] for s in stages),
                    'review_required':['current target and hands','fresh encoder start state','scene unchanged','physical TCP and limits','explicit execution confirmation']}
        finally:
            # No physical motion occurred: restore the initial hypothetical scene,
            # including the source object, rather than leaving it at the planned destination.
            self.configure_scene(request)
