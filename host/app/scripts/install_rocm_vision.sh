#!/usr/bin/env bash
# User-space ROCm wheels, verified guide version; preserves system/CPU environments.
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if [[ ! -x .venv-rocm/bin/python ]]; then .tools/uv venv .venv-rocm; fi
export UV_HTTP_TIMEOUT=1800 UV_CONCURRENT_DOWNLOADS=3
.tools/uv pip install --python .venv-rocm/bin/python --system-certs \
  --index-url https://stable.repo.amd.com/rocm/whl-next/ \
  'torch[device-gfx1150]==2.13.0+rocm10.0.0' 'torchvision[device-gfx1150]==0.28.0+rocm10.0.0'
.tools/uv pip install --python .venv-rocm/bin/python --system-certs \
  -c vision/rocm-constraints.txt ultralytics==8.4.193 mediapipe==0.10.32 pyorbbecsdk2==2.1.3
.venv-rocm/bin/python scripts/verify_acceleration.py
