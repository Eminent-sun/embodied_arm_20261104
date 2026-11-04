# Read only explicitly defined readable mailbox registers.
connect
targets -set -filter {name == "APU"}
foreach {name address} {
 ID 0x40000000 VERSION 0x40000004 COMMAND_STATUS 0x40000020 RESULT 0x40000024
 HEALTH 0x40000028 RX_ERRORS 0x40000030 RX_COUNT 0x40000034 TX_STATUS 0x40000038
 ACCEPTED_COUNT 0x4000003c COMPLETED_COUNT 0x40000040 REJECTED_COUNT 0x40000044
 RX_ISR 0x40000048 RX_OVERFLOW 0x4000004c
} {
 if {[catch {set value [mrd -value $address 1]} message]} {
  puts "READ_FAIL $name $address $message"
 } else {puts "REGISTER $name $address $value"}
}
puts "DDR_REPORT_FINAL"
puts [mrd -value 0x00112824 12]
disconnect
exit
