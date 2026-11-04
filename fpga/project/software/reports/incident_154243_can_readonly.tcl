# Read-only AXI CAN diagnostic registers (no RX FIFO read or ISR clear).
connect
targets -set -filter {name == "APU"}
foreach {name address} {CAN_ECR 0x43c00010 CAN_ESR 0x43c00014 CAN_SR 0x43c00018 CAN_ISR 0x43c0001c} {
 if {[catch {set value [mrd -value $address 1]} message]} {puts "READ_FAIL $name $message"} else {puts "REGISTER $name $address $value"}
}
puts "MAILBOX_RX_ERROR_FINAL"
puts [mrd -value 0x40000030 1]
disconnect
exit
