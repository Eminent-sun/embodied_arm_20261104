#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
source scripts/env_jazzy.bash
colcon --log-base .jazzy/log build \
    --base-paths URDF/urdf_visual_check URDF/robotarm_moveit_config ros/robstride_ros_sample \
    --build-base .jazzy/build --install-base .jazzy/install \
    --symlink-install --parallel-workers 3 --cmake-args -DCMAKE_BUILD_TYPE=Release
