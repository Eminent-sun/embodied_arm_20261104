# Offline implemented-design inspection only.
set root [file normalize [file join [file dirname [info script]] ..]]
open_project [file join $root vivado2023_project roboarm_ila_rx_debug.xpr]
open_run impl_1
foreach {port pin} {servo_pwm W19 CAN_TX F17 CAN_RX F16} {
    if {[get_property PACKAGE_PIN [get_ports $port]] ne $pin} {error "Pin mismatch: $port"}
}
if {[get_property IOSTANDARD [get_ports servo_pwm]] ne {LVCMOS33}} {error "Servo voltage standard mismatch"}
report_io -file [file join $root reports implemented_io.rpt]
puts "GRIPPER_IMPLEMENTED_IO_PASS servo_pwm=W19 CAN_TX=F17 CAN_RX=F16"
close_project
exit 0
