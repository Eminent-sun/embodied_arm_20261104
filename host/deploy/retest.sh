#!/usr/bin/env bash
set -euo pipefail
package_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
app_dir="$package_dir/host/app"
result_dir="${1:-$package_dir/retest_$(date +%Y%m%d_%H%M%S)}"
mkdir -p "$result_dir" "$app_dir/runtime/ultralytics/Ultralytics"
export PYTHONDONTWRITEBYTECODE=1
export YOLO_CONFIG_DIR="$app_dir/runtime/ultralytics"
ln -sfn /usr/share/fonts/truetype/dejavu/DejaVuSans.ttf "$YOLO_CONFIG_DIR/Ultralytics/Arial.ttf"
"$app_dir/.venv-rocm/bin/python" "$package_dir/metrics/scripts/benchmark_aipc.py" --output "$result_dir"
"$app_dir/.venv-vision/bin/python" "$package_dir/metrics/scripts/benchmark_cpu_fallback.py" --output "$result_dir"
"$app_dir/.venv-vision/bin/python" "$package_dir/metrics/scripts/benchmark_host_link.py" --output "$result_dir"
"$app_dir/.venv-vision/bin/python" "$package_dir/metrics/scripts/run_unit_tests.py" --output "$result_dir"
