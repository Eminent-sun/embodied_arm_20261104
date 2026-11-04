ENTRY(_start)
MEMORY { DDR (rwx) : ORIGIN = 0x00100000, LENGTH = 0x00100000 }
SECTIONS {
 .text : { KEEP(*(.text.start)) *(.text*) *(.rodata*) } > DDR
 .ARM.exidx : { *(.ARM.exidx*) } > DDR
 .data : { *(.data*) } > DDR
 .bss (NOLOAD) : { . = ALIGN(8); __bss_start = .; *(.bss*) *(COMMON); . = ALIGN(8); __bss_end = .; } > DDR
 __stack_top = ORIGIN(DDR)+LENGTH(DDR);
 ASSERT(__bss_end < __stack_top-0x10000,"Application overlaps 64KB stack reserve")
}
