#!/usr/bin/env bash
set -euo pipefail
app_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../app" && pwd)"
exec "$app_dir/scripts/start_dashboard.sh" "$@"
