#!/usr/bin/env bash
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
if [[ ! -x .tools/uv ]]; then
    echo 'Install uv from https://docs.astral.sh/uv/getting-started/installation/ into .tools/uv first.' >&2
    exit 1
fi
if [[ ! -x .venv-vision/bin/python ]]; then
    .tools/uv venv .venv-vision
fi
.tools/uv pip install --python .venv-vision/bin/python \
    -r vision/requirements.lock.txt --extra-index-url https://download.pytorch.org/whl/cpu \
    --index-strategy unsafe-best-match --native-tls
.venv-vision/bin/python scripts/download_vision_models.py
