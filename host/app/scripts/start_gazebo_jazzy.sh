#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/env_jazzy.bash"
export ROS_DOMAIN_ID="${ROBOARM_GAZEBO_DOMAIN_ID:-74}"
export GZ_PARTITION="${ROBOARM_GZ_PARTITION:-roboarm_jazzy_${USER}}"
exec ros2 launch urdf_visual_check gazebo.launch.py "$@"
