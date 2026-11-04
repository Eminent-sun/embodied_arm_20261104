#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$project_root/vision${PYTHONPATH:+:$PYTHONPATH}"
export YOLO_CONFIG_DIR="$project_root/runtime/ultralytics"
cd "$project_root"
vision_python="$project_root/.venv-vision/bin/python"
if [[ -f "$project_root/.venv-rocm/verified" ]]; then vision_python="$project_root/.venv-rocm/bin/python"; fi
exec "${VISION_PYTHON:-$vision_python}" -m robotarm_vision.app "$@"
