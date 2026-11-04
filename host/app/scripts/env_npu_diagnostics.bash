# Source only in a separate NPU diagnostic shell, not the ROCm/ROS process.
_npu_project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export XILINX_XRT="$_npu_project_root/.npu/root/opt/xilinx/xrt"
export LD_LIBRARY_PATH="$XILINX_XRT/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export PATH="$XILINX_XRT/bin/unwrapped:$PATH"
unset _npu_project_root
