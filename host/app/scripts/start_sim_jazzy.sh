#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/env_jazzy.bash"
exec ros2 launch robotarm_moveit_config sim_to_real.launch.py "$@" \
    send_to_motors:=false use_motor_feedback:=false \
    publish_planned_joint_states:=true honor_trajectory_timing:=true \
    use_joint_state_gui:=false
