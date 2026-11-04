#ifndef GRIPPER_H
#define GRIPPER_H
#include <stdint.h>
#define GRIPPER_BASE 0x40001000U
#define GRIPPER_MAGIC 0x53525631U
#define GRIPPER_REQUEST_MAGIC 0x47525031U
#define GRIPPER_OPEN_US 1220U
#define GRIPPER_CLOSE_US 1360U
#define GRIPPER_INITIAL_US 1400U
enum {GRIP_STATUS=0,GRIP_OFF=1,GRIP_SET=2};
enum {GRIP_OK=0,GRIP_BAD_INPUT=40,GRIP_WRONG_PL=41,GRIP_STOPPED=42,GRIP_VERIFY_FAILED=43};
typedef struct {uint32_t magic,version,action,pulse_us,slew_us,step_frames;} gripper_request_t;
typedef struct {
    uint32_t magic,version,sequence,error,present,enabled,ramping,lease_expired;
    uint32_t active_us,target_us,slew_us,step_frames,frame_count;
} gripper_report_t;
extern gripper_report_t g_gripper_report;
/* Software-only initialization. No MMIO, no CAN and no enable. */
void gripper_init(void);
/* GRIP_SET explicitly enables. Startup from OFF sends the requested pulse;
 * slew applies to later commands while already enabled. No mechanical feedback. */
int gripper_command(const gripper_request_t *request,uint32_t now_ms,int permit_enable);
void gripper_service(uint32_t now_ms,int permit_enable);
#endif
