# Called inside build_nodebug.tcl after opening the existing six-axis BD.
set servo_rtl [file join $root candidate rtl pl_servo_axi.v]
set servo_xdc [file join $root candidate constraints ax7010_servo.xdc]
if {![llength [get_files -quiet $servo_rtl]]} {add_files -norecurse $servo_rtl}
if {![llength [get_files -quiet $servo_xdc]]} {add_files -fileset constrs_1 -norecurse $servo_xdc}
update_compile_order -fileset sources_1
if {![llength [get_bd_cells -quiet pl_servo_axi]]} {
    set_property CONFIG.NUM_MI 3 [get_bd_cells axi_periph]
    create_bd_cell -type module -reference pl_servo_axi pl_servo_axi
    connect_bd_intf_net [get_bd_intf_pins axi_periph/M02_AXI] [get_bd_intf_pins pl_servo_axi/S_AXI]
    connect_bd_net [get_bd_pins clk_pl/clk_out1] [get_bd_pins axi_periph/M02_ACLK] [get_bd_pins pl_servo_axi/clk]
    connect_bd_net [get_bd_pins pl_reset_ctrl/axi_aresetn] [get_bd_pins axi_periph/M02_ARESETN] [get_bd_pins pl_servo_axi/rst_n]
    create_bd_port -dir O servo_pwm
    connect_bd_net [get_bd_pins pl_servo_axi/servo_pwm] [get_bd_ports servo_pwm]
    assign_bd_address -offset 0x40001000 -range 0x1000 -target_address_space [get_bd_addr_spaces processing_system7_0/Data] [get_bd_addr_segs pl_servo_axi/S_AXI/reg0]
    # PL CAN reader never controls the gripper; only PS has this segment.
    exclude_bd_addr_seg -target_address_space [get_bd_addr_spaces pl_can_reader/M_AXI] [get_bd_addr_segs pl_servo_axi/S_AXI/reg0]
} else {
    update_module_reference [get_ips can_test_pl_servo_axi_0]
}
set servo_seg [get_bd_addr_segs processing_system7_0/Data/SEG_pl_servo_axi_reg0]
if {[llength $servo_seg]!=1 || [get_property OFFSET $servo_seg] ne {0x40001000}} {error "Servo address mismatch"}
puts "SERVO_BASE=0x40001000 RANGE=4K PWM=W19 50Hz"
