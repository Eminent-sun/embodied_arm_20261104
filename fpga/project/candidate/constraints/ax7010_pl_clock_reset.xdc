# ALINX AX7010 official manual, PL system clock and user key tables:
# https://ax7010-20231-v101.readthedocs.io/zh-cn/latest/AX7010UserManual_CN/AX7010UserManual.html
# U18: PL_GCLK, single-ended 50 MHz, 3.3 V. N15: KEY1, active low.
set_property PACKAGE_PIN U18 [get_ports sys_clk_50m]
set_property IOSTANDARD LVCMOS33 [get_ports sys_clk_50m]
# The Clocking Wizard's scoped can_test_clk_pl_0.xdc already creates the
# 20.000 ns primary clock at clk_in1 (connected exclusively to this port).
# Keep one owner of that constraint; do not create a duplicate primary clock.
set_property PACKAGE_PIN N15 [get_ports rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports rst_n]
# Clocking Wizard supplies generated-clock constraints and output BUFGs.
# No broad false paths or clock groups are added here.
