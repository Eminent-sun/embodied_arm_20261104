# Read-only fault diagnosis: APU memory target; no halt, writes, CAN or reset.
connect
puts "READONLY_TARGETS_BEGIN"
puts [targets]
puts "READONLY_TARGETS_END"
targets -set -filter {name == "APU"}
puts "ARM_REPORT_BEGIN"
puts [mrd -value 0x112824 30]
puts "ARM_REPORT_END"
puts "MAILBOX_REGISTERS_BEGIN"
puts [mrd -value 0x40000000 21]
puts "MAILBOX_REGISTERS_END"
puts "MAILBOX_HEALTH_REPEAT_BEGIN"
puts [mrd -value 0x40000020 12]
puts "MAILBOX_HEALTH_REPEAT_END"
disconnect
exit
