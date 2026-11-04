#!/usr/bin/env bash
# Start after start_ps_simulator.sh and start_ax7010_bridge.sh; no local motor driver.
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/env_jazzy.bash"
exec ros2 launch robotarm_moveit_config demo.launch.py "$@" \
    joint_state_publisher_mode:=off allow_trajectory_execution:=true
