#!/usr/bin/env bash
# Grant the invoking user device access. No kernel/firmware changes.
set -euo pipefail
if [[ "$EUID" != 0 || -z "${SUDO_USER:-}" || "$SUDO_USER" == root ]]; then
    echo 'Run from your normal login: sudo bash scripts/enable_ai_devices.sh' >&2
    exit 1
fi
usermod -aG render,video "$SUDO_USER"
for device in /dev/kfd /dev/dri/renderD* /dev/accel/accel*; do
    [[ ! -e "$device" ]] || setfacl -m "u:$SUDO_USER:rw" "$device"
done
bash "$(dirname "$0")/install_camera_permissions.sh"
echo 'Current device ACLs enabled; render/video groups take effect on next login.'
