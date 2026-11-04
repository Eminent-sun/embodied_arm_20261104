#!/usr/bin/env bash
set -eo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PYTHONPATH="$project_root/communication${PYTHONPATH:+:$PYTHONPATH}"
exec /usr/bin/python3 -m robotarm_link.vision_bridge "$@"
