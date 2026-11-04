# Official ALINX AX7010 manual, J11 pin allocation and connector schematic:
# https://ax7010-20231-v101.readthedocs.io/zh-cn/latest/AX7010UserManual_CN/AX7010UserManual.html#j11
# J11 pin 3: EX_IO2_1N, IO_L6N_T0_35, FPGA F17.
# J11 pin 4: EX_IO2_1P, IO_L6P_T0_35, FPGA F16.
# Bank35 is 3.3 V by default. TX/RX are separate single-ended logic signals.
# Connect CAN_TX to transceiver TXD and CAN_RX to transceiver RXD.
set_property PACKAGE_PIN F17 [get_ports CAN_TX]
set_property IOSTANDARD LVCMOS33 [get_ports CAN_TX]
set_property PACKAGE_PIN F16 [get_ports CAN_RX]
set_property IOSTANDARD LVCMOS33 [get_ports CAN_RX]

# Stage 2D clock/reset pins are in ax7010_pl_clock_reset.xdc.
# Clocking Wizard supplies the PL primary/generated clock constraints.
