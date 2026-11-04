#include "path_mailbox.h"
#include "motion_mailbox.h"
static void barrier(void){__asm__ volatile("dsb sy":::"memory");}
static void wr(unsigned off,uint32_t v){*(volatile uint32_t *)(uintptr_t)(MOTION_MAILBOX_BASEADDR+off)=v;barrier();}
static volatile uint32_t *timer(unsigned off){return (volatile uint32_t *)(uintptr_t)(0xf8f00200U+off);}
static uint32_t time_ms(void *context){
    (void)context;uint32_t hi,lo,again;
    do{hi=*timer(4);lo=*timer(0);again=*timer(4);}while(hi!=again);
    return (uint32_t)((((uint64_t)hi<<32)|lo)/333333U);
}
void path_mailbox_initialize_timer(void){*timer(8)=0;*timer(0)=0;*timer(4)=0;*timer(8)=1;barrier();}
static int healthy(void *context){
    (void)context;uint32_t h=motion_mailbox_read(MB_HEALTH),abi=motion_mailbox_read(MB_VERSION);
    return motion_mailbox_read(MB_ID)==0x43414e36U && (abi==0x00020008U || abi==0x00020009U) &&
        (h&0x3f3f001fU)==0xb && motion_mailbox_read(MB_RX_ERRORS)==0 && motion_mailbox_read(MB_RX_OVERFLOW)==0;
}
static uint32_t page(void *context,unsigned axis,unsigned p){(void)context;(void)motion_mailbox_select_feedback(axis,p);return motion_mailbox_read(MB_FEEDBACK);}
static void emergency(void *context){(void)context;motion_mailbox_request_stop();}
static int transaction(void *context,uint32_t word,uint32_t value,uint32_t *out){
    path_mailbox_context_t *c=context;
    if(!healthy(context)||(motion_mailbox_read(MB_COMMAND_STATUS)&0x11U))return -1;
    uint32_t accepted=motion_mailbox_read(MB_ACCEPTED_COUNT),completed=motion_mailbox_read(MB_COMPLETED_COUNT),rejected=motion_mailbox_read(MB_REJECTED_COUNT);
    uint32_t start=time_ms(context);wr(MB_STAGE_WORD,word);wr(MB_STAGE_LO,value);wr(MB_STAGE_HI,0);wr(MB_CONTROL,1);
    for(;;){
        if(motion_mailbox_read(MB_REJECTED_COUNT)!=rejected)return -1;
        if(motion_mailbox_read(MB_COMPLETED_COUNT)!=completed){
            uint32_t status=motion_mailbox_read(MB_COMMAND_STATUS);
            if(out)*out=motion_mailbox_read(MB_RESULT);
            return (status&0x1dU)==4 && motion_mailbox_read(MB_ACCEPTED_COUNT)==accepted+1?0:-1;
        }
        if(time_ms(context)-start>=c->command_timeout_ms)return -1;
    }
}
path_io_t path_mailbox_io(path_mailbox_context_t *context){path_io_t io={context,time_ms,healthy,transaction,page,emergency};return io;}
int path_mailbox_recover(void *context){
    uint32_t s=motion_mailbox_read(MB_COMMAND_STATUS),code=(s>>16)&255U;
    if(!healthy(context)||(s&0x11U)!=0x10U||((s>>8)&15U)!=9||
       (code!=0xe0U&&code!=0xe1U)||motion_mailbox_read(MB_TX_STATUS)!=0)return -1;
    uint32_t accepted=motion_mailbox_read(MB_ACCEPTED_COUNT),done=motion_mailbox_read(MB_COMPLETED_COUNT);
    uint32_t start=time_ms(context);
    wr(MB_RECOVER,0x52454331U);
    do{
        if(motion_mailbox_read(MB_COMPLETED_COUNT)!=done){
            s=motion_mailbox_read(MB_COMMAND_STATUS);
            return healthy(context)&&(s&0x1dU)==4&&
                motion_mailbox_read(MB_ACCEPTED_COUNT)==accepted+1?0:-1;
        }
    }while(time_ms(context)-start<1000);
    return -1; /* No retry; the caller requests A5 stop on any failure. */
}
