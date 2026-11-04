.syntax unified
.cpu cortex-a9
.arm
.section .text.start,"ax"
.global _start
_start:
    cpsid if
    cps #0x13
    mrc p15,0,r0,c1,c0,0
.global startup_check
startup_check:
    tst r0,#5
    bne startup_rejected
    ldr sp,=__stack_top
    ldr r1,=__bss_start
    ldr r2,=__bss_end
    mov r3,#0
1:  cmp r1,r2
    strlo r3,[r1],#4
    blo 1b
    dsb sy
    isb sy
    bl compute_main
.global compute_idle
compute_idle:
    bl workflow_runtime_poll
    b compute_idle
.global startup_rejected
startup_rejected:
    wfe
    b startup_rejected
