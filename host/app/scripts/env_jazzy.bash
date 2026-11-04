# Source this file from bash. Project dependencies live outside /opt/ros.
_roboarm_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -n "${ROS_DISTRO:-}" && "$ROS_DISTRO" != jazzy ]]; then
    echo "Open a clean terminal: ROS_DISTRO=$ROS_DISTRO conflicts with Jazzy." >&2
    return 1
fi
source /opt/ros/jazzy/setup.bash
_roboarm_deps="$_roboarm_root/.jazzy/dependencies/opt/ros/jazzy"
if [[ -d "$_roboarm_deps" ]]; then
    export AMENT_PREFIX_PATH="$_roboarm_deps${AMENT_PREFIX_PATH:+:$AMENT_PREFIX_PATH}"
    export PYTHONPATH="$_roboarm_deps/lib/python3.12/site-packages${PYTHONPATH:+:$PYTHONPATH}"
fi
if [[ -f "$_roboarm_root/.jazzy/install/local_setup.bash" ]]; then
    source "$_roboarm_root/.jazzy/install/local_setup.bash"
fi
# Keep this desktop simulation separate from the original robot (domain 42).
export ROS_DOMAIN_ID="${ROBOARM_ROS_DOMAIN_ID:-73}"
export ROS_AUTOMATIC_DISCOVERY_RANGE="${ROBOARM_DISCOVERY_RANGE:-LOCALHOST}"
unset _roboarm_root _roboarm_deps
