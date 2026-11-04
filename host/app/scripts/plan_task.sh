#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$project_root/scripts/env_jazzy.bash"
export PYTHONPATH="$project_root/planning:$project_root/vision:$project_root/communication${PYTHONPATH:+:$PYTHONPATH}"
exec /usr/bin/python3 -m robotarm_planning.worker "$@"
