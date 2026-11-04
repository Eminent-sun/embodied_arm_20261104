#include "gripper.h"
#include "motion_mailbox.h"
#include <string.h>
gripper_report_t g_gripper_report;
static uint32_t last_service;
static int discovered;
#ifdef GRIPPER_TEST
extern uint32_t gripper_test_read(uint32_t offset);
extern void gripper_test_write(uint32_t offset,uint32_t value);
#define rd gripper_test_read
#define wr gripper_test_write
#else
static uint32_t rd(uint32_t offset){return *(volatile uint32_t *)(GRIPPER_BASE+offset);}
static void wr(uint32_t offset,uint32_t value){
    *(volatile uint32_t *)(GRIPPER_BASE+offset)=value;
    __asm__ volatile("dsb sy":::"memory");
}
#endif
void gripper_init(void){
    memset(&g_gripper_report,0,sizeof(g_gripper_report));
    g_gripper_report.magic=GRIPPER_MAGIC;g_gripper_report.version=1;
    discovered=0;last_service=0;
}
static void refresh(void){
    uint32_t status=rd(0x18);
    g_gripper_report.enabled=status&1U;g_gripper_report.ramping=(status>>1)&1U;
    g_gripper_report.lease_expired=(status>>3)&1U;
    g_gripper_report.active_us=rd(0x1c);g_gripper_report.target_us=rd(0x20);
    g_gripper_report.slew_us=rd(0x10);g_gripper_report.step_frames=rd(0x14);
    g_gripper_report.frame_count=rd(0x24);
}
static int request_valid(const gripper_request_t *r){
    if(!r||r->magic!=GRIPPER_REQUEST_MAGIC||r->version!=1||r->action>GRIP_SET)return 0;
    if(r->action!=GRIP_SET)return !(r->pulse_us||r->slew_us||r->step_frames);
    return r->pulse_us>=1110&&r->pulse_us<=1490&&r->slew_us>=1&&r->slew_us<=10&&
           r->step_frames>=1&&r->step_frames<=50;
}
int gripper_command(const gripper_request_t *r,uint32_t time,int permit){
    int rc=GRIP_OK;
    if(!request_valid(r))rc=GRIP_BAD_INPUT;
    else if(r->action==GRIP_SET&&!permit)rc=GRIP_STOPPED;
    else if(motion_mailbox_read(MB_ID)!=0x43414e36U || motion_mailbox_read(MB_VERSION)!=0x00020009U ||
            rd(0)!=GRIPPER_MAGIC||rd(4)!=0x10000U){
        discovered=0;g_gripper_report.present=0;rc=GRIP_WRONG_PL;
    }else{
        discovered=1;g_gripper_report.present=1;
        if(r->action==GRIP_OFF)wr(8,0);
        else if(r->action==GRIP_SET){
            wr(0xc,r->pulse_us);wr(0x10,r->slew_us);wr(0x14,r->step_frames);
            if(rd(0xc)!=r->pulse_us||rd(0x10)!=r->slew_us||rd(0x14)!=r->step_frames)rc=GRIP_VERIFY_FAILED;
            else wr(8,1);
        }
        refresh();
        if(!rc&&r->action==GRIP_SET&&(!g_gripper_report.enabled||g_gripper_report.target_us!=r->pulse_us))rc=GRIP_VERIFY_FAILED;
        if(!rc&&r->action==GRIP_OFF&&g_gripper_report.enabled)rc=GRIP_VERIFY_FAILED;
        if(rc==GRIP_VERIFY_FAILED){wr(8,0);refresh();}
        if(r->action!=GRIP_STATUS)last_service=time;
    }
    g_gripper_report.error=(uint32_t)rc;return rc;
}
void gripper_service(uint32_t time,int permit){
    if(!discovered)return;
    if(!permit&&g_gripper_report.enabled){
        wr(8,0);refresh();g_gripper_report.error=GRIP_STOPPED;
    }else if(time-last_service>=100U){
        // Lease refresh never enables an expired peripheral.
        if(permit&&g_gripper_report.enabled)wr(0x28,0x4b49434bU);
        refresh();last_service=time;
    }
}
