set root [file normalize [file join [file dirname [info script]] ..]]
open_project $root/vivado2023_project/roboarm_ila_rx_debug.xpr
set outside 0
set missing 0
foreach f [get_files -all] {
    set p [file normalize $f]
    if {![file exists $p]} {incr missing;puts "MISSING=$p"}
    if {![string match -nocase "$root/*" $p]} {incr outside;puts "OUTSIDE=$p"}
}
puts "INPUT_MISSING=$missing INPUT_OUTSIDE=$outside"
if {$missing || $outside} {error "Project is not independent"}
open_run impl_1
set recovery_cells [get_cells -hier -quiet -filter {NAME =~ *recover_pulse_reg*}]
if {![llength $recovery_cells]} {error "Recovery pulse register missing from routed implementation"}
puts "RECOVERY_PULSE_CELLS=[llength $recovery_cells]"
if {[llength [get_debug_cores -quiet]]} {error "Debug cores found"}
foreach pattern {*pl_el05_single_tx* *pl_motion_mailbox* *pl_robstride_feedback*} {
    set cells [get_cells -hier -quiet -filter "NAME =~ $pattern"]
    if {![llength $cells]} {error "Functional hierarchy removed: $pattern"}
    puts "PRESERVED=$pattern CELLS=[llength $cells]"
}
puts "NODEBUG_REOPEN_CORE_COUNT=0"
report_bus_skew -file $root/reports/bus_skew.rpt
close_project
exit
