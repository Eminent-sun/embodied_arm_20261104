"""AI PC planning-only MoveIt services, isolated from all execution controllers."""
from pathlib import Path
import yaml
from ament_index_python.packages import get_package_share_directory
from launch import LaunchDescription
from launch.actions import DeclareLaunchArgument
from launch.conditions import IfCondition
from launch.substitutions import LaunchConfiguration
from launch_ros.actions import Node
from moveit_configs_utils import MoveItConfigsBuilder


def generate_launch_description():
    cfg=(MoveItConfigsBuilder('robotarm',package_name='robotarm_moveit_config')
         .robot_description(file_path='config/robotarm.urdf')
         .robot_description_semantic(file_path='config/robotarm.srdf')
         .robot_description_kinematics(file_path='config/kinematics.yaml')
         .joint_limits(file_path='config/joint_limits.yaml')
         .planning_pipelines(default_planning_pipeline='ompl',pipelines=['ompl']).to_moveit_configs())
    share=Path(get_package_share_directory('robotarm_moveit_config'))
    ompl=yaml.safe_load((share/'config/jazzy/ompl_planning.yaml').read_text())
    ompl['arm']['longest_valid_segment_fraction']=.0005
    ompl['planner_configs']['RRTConnect']['range']=.05
    ompl['totg']={'path_tolerance':.001,'resample_dt':.05,'min_angle_change':.001}
    cfg.planning_pipelines['ompl']=ompl
    joints={f'zeros.joint{i}':v for i,v in enumerate([0.,1.57,0.,0.,1.57,0.],1)}
    return LaunchDescription([
        DeclareLaunchArgument('use_rviz',default_value='false'),
        DeclareLaunchArgument('publish_simulated_joints',default_value='true'),
        Node(package='robot_state_publisher',executable='robot_state_publisher',parameters=[cfg.robot_description]),
        Node(package='joint_state_publisher',executable='joint_state_publisher',
             condition=IfCondition(LaunchConfiguration('publish_simulated_joints')),parameters=[cfg.robot_description,joints]),
        Node(package='tf2_ros',executable='static_transform_publisher',arguments=['--frame-id','world','--child-frame-id','base_link']),
        Node(package='moveit_ros_move_group',executable='move_group',output='screen',
             parameters=[cfg.to_dict(),{'allow_trajectory_execution':False,'ompl.lock_tool_orientation_enabled':False,
                                       'publish_planning_scene':True,'publish_geometry_updates':True,'publish_state_updates':True}]),
        Node(package='rviz2',executable='rviz2',condition=IfCondition(LaunchConfiguration('use_rviz')),
             arguments=['-d',str(share/'rviz/moveit.rviz')],parameters=[cfg.robot_description,cfg.robot_description_semantic,cfg.robot_description_kinematics,cfg.planning_pipelines])])
