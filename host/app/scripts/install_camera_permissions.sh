#!/usr/bin/env bash
# Run interactively using sudo; grants only active local users access to Gemini 2.
set -euo pipefail
if [[ "$EUID" != 0 ]]; then
    echo 'Run: sudo ./scripts/install_camera_permissions.sh' >&2
    exit 1
fi
rule=/etc/udev/rules.d/70-roboarm-gemini2.rules
if [[ -e "$rule" ]]; then
    cp -a "$rule" "$rule.backup.$(date +%Y%m%d%H%M%S)"
fi
cat > "$rule" <<'EOF'
SUBSYSTEM=="usb", ATTR{idVendor}=="2bc5", ATTR{idProduct}=="0670", MODE="0660", TAG+="uaccess"
EOF
udevadm control --reload-rules
udevadm trigger --subsystem-match=usb --attr-match=idVendor=2bc5 --attr-match=idProduct=0670
echo 'Gemini 2 rule installed. Reconnect the camera if necessary.'
