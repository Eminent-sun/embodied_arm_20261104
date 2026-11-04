# Resume only after unchanged synthesis has completed successfully.
set root [file normalize [file join [file dirname [info script]] ..]]
set out [file join $root reports]
set bitdir [file join $root bitstream]
open_project [file join $root vivado2023_project roboarm_ila_rx_debug.xpr]
if {[get_property PROGRESS [get_runs synth_1]] ne {100%} || [get_property NEEDS_REFRESH [get_runs synth_1]]} {error "Fresh completed synthesis required"}
set_property strategy Performance_ExplorePostRoutePhysOpt [get_runs impl_1]
reset_run impl_1
set f [open [file join $root build build_nodebug.tcl] r]
set script [read $f]
close $f
set start [string first {launch_runs impl_1 -to_step write_bitstream} $script]
if {$start<0} {error "Implementation flow missing"}
eval [string range $script $start end]
