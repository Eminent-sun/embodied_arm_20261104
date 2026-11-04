#include "motion_mailbox.h"

static volatile uint32_t *reg_at(unsigned offset) {
    return (volatile uint32_t *)((uintptr_t)MOTION_MAILBOX_BASEADDR + offset);
}
static void barrier(void) {
#if defined(__arm__) || defined(__aarch64__)
    __asm__ volatile ("dsb sy" ::: "memory");
#elif defined(__GNUC__) || defined(__clang__)
    __asm__ volatile ("" ::: "memory");
#endif
}
uint32_t motion_mailbox_read(unsigned offset) {
    uint32_t value=*reg_at(offset);
    barrier();
    return value;
}
static void write_reg(unsigned offset,uint32_t value) {
    *reg_at(offset)=value;barrier();
}
int motion_mailbox_probe(uint32_t *health) {
    if(motion_mailbox_read(MB_ID)!=0x43414e36u) return MB_NOT_READY;
    uint32_t h=motion_mailbox_read(MB_HEALTH);
    if(health) *health=h;
    return (h&0x1fu)==0x0bu ? MB_OK : MB_NOT_READY;
}
int motion_mailbox_select_feedback(unsigned axis,unsigned page) {
    if(axis>=6 || page>=32) return MB_BAD_INPUT;
    write_reg(MB_QUERY_SELECT,(page<<8)|axis);
    return MB_OK;
}
int motion_mailbox_submit_raw(uint32_t word,uint32_t bits,
                              unsigned polls,motion_mailbox_result *out) {
    if((word&0xe0000000u)!=0 || polls==0) return MB_BAD_INPUT;
    if(motion_mailbox_probe(0)!=MB_OK) return MB_NOT_READY;
    if(motion_mailbox_read(MB_COMMAND_STATUS)&0x11u) return MB_BUSY;
    uint32_t rejected=motion_mailbox_read(MB_REJECTED_COUNT);
    uint32_t completed=motion_mailbox_read(MB_COMPLETED_COUNT);
    write_reg(MB_STAGE_WORD,word);
    write_reg(MB_STAGE_LO,bits);
    write_reg(MB_STAGE_HI,0);
    write_reg(MB_CONTROL,1);
    while(polls--) {
        if(motion_mailbox_read(MB_REJECTED_COUNT)!=rejected) return MB_REJECTED;
        if(motion_mailbox_read(MB_COMPLETED_COUNT)!=completed) {
            uint32_t s=motion_mailbox_read(MB_COMMAND_STATUS);
            uint32_t v=motion_mailbox_read(MB_RESULT);
            if(out) {out->status=s;out->value=v;}
            return (s&0x1cu)==4u ? MB_OK : MB_COMMAND_FAILED;
        }
    }
    /* No replay on a timeout. Caller must inspect state and request stop if
     * actuation may have begun; a timeout is never proof of non-submission. */
    return MB_WAIT_TIMEOUT;
}
void motion_mailbox_request_stop(void) {
    /* Independent A5 stop pulse. This is also accepted while busy/locked.
     * It does not certify the motors stopped; inspect the resulting state. */
    write_reg(MB_CONTROL,2);
}
