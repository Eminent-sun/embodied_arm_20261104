# Explicitly launched by workflow_console --connect. No reset/download/enable.
connect
# The mailbox is physical DDR and the shipped PS runs with MMU/data cache off.
# Use the system-memory target; core targets expose virtual memory and may
# involve CPU/debugger synchronization. No fallback to a core target.
targets -set -filter {name == "APU"}
proc range_ok {address count} {
    if {![string is integer -strict $address] || ![string is integer -strict $count] ||
        $count<1 || $count>32 || $address<0x00100000 || $address%4 || $address+4*$count>0x00200000} {
        error "Only bounded application DDR accesses permitted"
    }
}
puts "BRIDGE_READY";flush stdout
while {[gets stdin line]>=0} {
    if {[catch {
        set fields [split [string trim $line]]
        set op [lindex $fields 0]
        if {$op eq "GET" && [llength $fields]==3} {
            set address [lindex $fields 1];set count [lindex $fields 2];range_ok $address $count
            set values [mrd -value $address $count]
            if {[llength $values]!=$count} {error "Unexpected memory read length"}
            set words {}
            foreach value $values {
                if {![string is wideinteger -strict $value]} {error "Non-numeric memory value"}
                lappend words [format %08X [expr {wide($value)&0xffffffff}]]
            }
            puts "DATA_HEX [join $words { }]"
        } elseif {$op eq "PUT" && [llength $fields]>=3} {
            set address [lindex $fields 1];set count [expr {[llength $fields]-2}];range_ok $address $count
            foreach value [lrange $fields 2 end] {
                if {![string is wideinteger -strict $value]} {error "Invalid word"}
                mwr $address $value;incr address 4
            }
            puts "OK"
        } elseif {$op eq "QUIT" && [llength $fields]==1} {break
        } else {error "Invalid bridge operation"}
    } message]} {puts "BRIDGE_ERROR $message"}
    puts "BRIDGE_DONE";flush stdout
}
disconnect
exit
