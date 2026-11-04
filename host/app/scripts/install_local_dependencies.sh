#!/usr/bin/env bash
# Install the two missing, relocatable ROS Python packages into this project.
# The host must already have ROS 2 Jazzy, MoveIt, python_qt_binding and PyQt5.
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$project_root/.jazzy/debs" "$project_root/.jazzy/dependencies"
cd "$project_root/.jazzy/debs"
apt-get download ros-jazzy-joint-state-publisher ros-jazzy-joint-state-publisher-gui
for package in ros-jazzy-joint-state-publisher ros-jazzy-joint-state-publisher-gui; do
    version="$(apt-cache policy "$package" | awk '/Candidate:/ {print $2}')"
    arch="$(dpkg --print-architecture)"
    dpkg-deb -x "${package}_${version}_${arch}.deb" "$project_root/.jazzy/dependencies"
done
echo "Dependencies installed locally; source scripts/env_jazzy.bash to use them."
