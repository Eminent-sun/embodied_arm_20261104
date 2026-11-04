#!/usr/bin/env bash
# Install into the DELIVERY COPY only. Does not install drivers or change system Python.
set -euo pipefail
deploy_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
app_dir="$deploy_dir/../app"
mode="${1:-gpu}"
cd "$app_dir"
if ! command -v uv >/dev/null; then
  echo 'Install uv first: python3 -m venv .bootstrap && .bootstrap/bin/pip install uv; export PATH="$PWD/.bootstrap/bin:$PATH"' >&2
  exit 1
fi
mkdir -p .tools runtime/ultralytics/Ultralytics
ln -sfn "$(command -v uv)" .tools/uv
if [[ -f /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf ]]; then
  ln -sfn /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf runtime/ultralytics/Ultralytics/Arial.ttf
fi
# CPU environment is used for the dashboard/tests and camera utilities.
uv venv --python 3.12 .venv-vision
uv pip install --python .venv-vision/bin/python --system-certs --index-strategy unsafe-best-match \
  --extra-index-url https://download.pytorch.org/whl/cpu -r "$deploy_dir/cpu_requirements.txt"
if [[ "$mode" == gpu ]]; then
  uv venv --python 3.12 .venv-rocm
  uv pip install --python .venv-rocm/bin/python --system-certs --index-strategy unsafe-best-match \
    --extra-index-url https://stable.repo.amd.com/rocm/whl-next/ -r "$deploy_dir/rocm_requirements.txt"
  YOLO_CONFIG_DIR="$PWD/runtime/ultralytics" .venv-rocm/bin/python scripts/verify_acceleration.py
elif [[ "$mode" != cpu ]]; then
  echo 'Usage: setup.sh gpu|cpu' >&2; exit 2
fi
printf '%s\n' 'Installed. Camera and detector have NOT been started.'
