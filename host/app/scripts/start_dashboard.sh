#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$project_root/planning:$project_root/communication:$project_root/vision${PYTHONPATH:+:$PYTHONPATH}"
exec "$project_root/.venv-vision/bin/python" -m robotarm_vision.dashboard "$@"
