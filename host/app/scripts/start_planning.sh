#!/usr/bin/env bash
# Planning services only: no motor driver, no trajectory execution action.
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/env_jazzy.bash"
exec ros2 launch "$project_root/planning/planning.launch.py" "$@"
