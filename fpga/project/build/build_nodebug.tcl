# Independent streamed PP build. Never opens hardware or programs the board.
set root [file normalize [file join [file dirname [info script]] ..]]
set xpr [file join $root vivado2023_project roboarm_ila_rx_debug.xpr]
set bd [file join $root candidate roboarm.srcs sources_1 bd can_test can_test.bd]
set out [file join $root reports]
set bitdir [file join $root bitstream]
if {[version -short] ne {2023.1}} {error "Vivado 2023.1 required"}
open_project $xpr
foreach f [get_files -all] {
 set path [file normalize $f]
 if {![file exists $path] || ![string match -nocase "$root/*" $path]} {error "Missing/outside project input: $path"}
}
if {[get_property PART [current_project]] ne {xc7z010clg400-1}} {error "Wrong part"}
open_bd_design $bd
source [file join $root build integrate_servo.tcl]
# Module-reference IP names are stable in this copied BD.
update_module_reference [get_ips can_test_pl_el05_single_tx_1]
update_module_reference [get_ips can_test_pl_motion_mailbox_0]
set_property -dict [list CONFIG.ENABLE_PP_TEST 1 CONFIG.ENABLE_MULTI_PP 1 CONFIG.ENABLE_PATH_PP 1 CONFIG.ENABLE_HOLD_PP 1 CONFIG.PATH_MAX_STEP_Q16 6554 CONFIG.PATH_WINDOW_CYCLES 3000000000 CONFIG.PATH_LEASE_CYCLES 25000000 CONFIG.PATH_POSITION_AGE_CYCLES 25000000 CONFIG.PP_MAX_DELTA_Q16 824442 CONFIG.PP_MAX_SPEED_BITS 0x404CCCCD CONFIG.PP_MAX_ACCEL_BITS 0x404CCCCD CONFIG.PP_WINDOW_CYCLES 500000000 CONFIG.PP_POSITION_AGE_CYCLES 1500000000] [get_bd_cells pl_el05_single_tx]
set_property CONFIG.ABI_VERSION 0x00020009 [get_bd_cells pl_motion_mailbox]
puts "BUILD_GUARDS=[get_property CONFIG.PP_MAX_DELTA_Q16 [get_bd_cells pl_el05_single_tx]] / [get_property CONFIG.PP_WINDOW_CYCLES [get_bd_cells pl_el05_single_tx]] ABI=[get_property CONFIG.ABI_VERSION [get_bd_cells pl_motion_mailbox]]"
foreach c {ila_can_reader vio_can_send vio_feedback_debug vio_el05_single_tx line_scope} {if {[llength [get_bd_cells -quiet $c]]} {error "Unexpected debug core"}}
save_bd_design
validate_bd_design -force
generate_target all [get_files $bd]
# Regenerate the actual imported top wrapper to expose the new PWM pin.
set wrappers [make_wrapper -files [get_files $bd] -top]
file copy -force [lindex $wrappers 0] [file join $root candidate roboarm.srcs sources_1 imports hdl can_test_wrapper.v]
update_compile_order -fileset sources_1
set seg [get_bd_addr_segs processing_system7_0/Data/SEG_pl_motion_mailbox_reg0]
if {[llength $seg]!=1 || [get_property OFFSET $seg] ne {0x40000000}} {error "Mailbox address changed"}
set f [open [file join $out mailbox_address.txt] w];puts $f "BASE=0x40000000 RANGE=4K ABI=0x00020009 PATH=1";close $f
close_bd_design [get_bd_designs can_test]
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
reset_run impl_1
reset_run synth_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
puts "SYNTH_STATUS=[get_property STATUS [get_runs synth_1]]"
if {[get_property PROGRESS [get_runs synth_1]] ne {100%} ||
    [string match -nocase {*error*} [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis failed"
}
open_run synth_1
report_utilization -hierarchical -file [file join $out utilization_synth_hier.rpt]
puts "SYNTH_DEBUG_CORES=[get_debug_cores]"
close_design
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
puts "IMPL_STATUS=[get_property STATUS [get_runs impl_1]]"
if {[get_property PROGRESS [get_runs impl_1]] ne {100%} ||
    [string match -nocase {*error*} [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation failed"
}
open_run impl_1
report_utilization -file [file join $out utilization.rpt]
report_utilization -hierarchical -file [file join $out utilization_hier.rpt]
set util_fh [open [file join $out utilization.rpt] r]
set util_text [read $util_fh]
close $util_fh
if {![regexp -line {^\| Slice\s+\|\s+([0-9]+)} $util_text -> routed_slices]} {
    error "Could not parse routed Slice count"
}
puts "ROUTED_SLICE=$routed_slices"
if {$routed_slices > 4400} {error "Slice capacity exceeded"}
puts "SLICE_HEADROOM=[expr {4400-$routed_slices}] (commissioning build; full timing/DRC still required)"
report_timing_summary -report_unconstrained -file [file join $out timing_summary.rpt]
report_drc -file [file join $out drc.rpt]
report_methodology -file [file join $out methodology.rpt]
report_cdc -file [file join $out cdc.rpt]
report_clock_interaction -file [file join $out clock_interaction.rpt]
puts "ROUTED_DEBUG_CORES=[get_debug_cores]"
set setup_paths [get_timing_paths -setup -max_paths 1]
set hold_paths [get_timing_paths -hold -max_paths 1]
if {![llength $setup_paths] || ![llength $hold_paths]} {error "Timing paths missing"}
set wns [get_property SLACK [lindex $setup_paths 0]]
set whs [get_property SLACK [lindex $hold_paths 0]]
puts "ROUTED_WNS=$wns ROUTED_WHS=$whs"
if {$wns < 0 || $whs < 0} {error "Routed timing failed"}
if {[llength [get_debug_cores -quiet]]} {error "Debug cores remain in no-debug build"}
set drc_errors [get_drc_violations -quiet -filter {SEVERITY == Error}]
puts "DRC_ERROR_COUNT=[llength $drc_errors]"
if {[llength $drc_errors]} {error "Blocking DRC violations"}
set source_bit [file join $root vivado2023_project roboarm_ila_rx_debug.runs impl_1 can_test_wrapper.bit]
if {![file exists $source_bit]} {error "Bitstream missing"}
set out_bit [file join $bitdir roboarm_arm_workflow.bit]
file copy -force $source_bit $out_bit
if {[llength [get_debug_cores -quiet]]} {error "Debug core in delivered implementation"}
write_hw_platform -fixed -include_bit -force [file join $bitdir roboarm_arm_workflow.xsa]
puts "NODEBUG_BIT=$out_bit"
puts "NODEBUG_CORE_COUNT=0 NO_LTX_REQUIRED"
close_project
exit 0
