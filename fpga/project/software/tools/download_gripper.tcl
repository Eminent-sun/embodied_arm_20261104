# Invoked only by the user's explicit download command. Never enables an actuator.
if {[llength $argv]!=2} {error "Expected delivery root and ELF entry address"}
set gripperRoot [file normalize [lindex $argv 0]]
set gripperEntry [lindex $argv 1]
connect
targets -set -filter {name =~ "*Cortex-A9*#1"}
catch {stop}
targets -set -filter {name =~ "*Cortex-A9*#0"}
catch {stop}
rst -system
after 1000
targets -set -filter {name =~ "*Cortex-A9*#1"}
catch {stop}
targets -set -filter {name =~ "*Cortex-A9*#0"}
catch {stop}
fpga -file "$gripperRoot/bitstream/roboarm_arm_workflow.bit"
loadhw -hw "$gripperRoot/bitstream/roboarm_arm_workflow.xsa" -mem-ranges {{0x40000000 0x40001fff}}
# PS init must be sourced at Tcl global scope.
source "$gripperRoot/bitstream/ps_init/ps7_init.tcl"
ps7_init
ps7_post_config
dow -clear "$gripperRoot/software/build/arm_workflow.elf"
rwr cpsr 0x1d3
rwr pc $gripperEntry
con
puts "ARM_GRIPPER_DOWNLOAD_DONE: PS starts OFF; PWM disabled. No enable or motion command sent."
disconnect
exit
