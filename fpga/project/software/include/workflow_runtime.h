#ifndef WORKFLOW_RUNTIME_H
#define WORKFLOW_RUNTIME_H
#include "arm_workflow.h"
enum {WF_CONFIGURE=100,WF_RESTORE=101,WF_CAPTURE_POSE=102,WF_HOLD_POSE=103,WF_RESTORE_POSE=104,WF_PREVIEW=105,WF_GRIPPER=111};
typedef struct {
    uint32_t sequence,go,operation,axis;
    float reference_joint_rad;
    path_config_t config;
    workflow_record_t record;
    uint32_t crc32;
} workflow_request_t;
typedef struct {uint32_t completed_sequence,error,operation,busy;} workflow_reply_t;
extern volatile workflow_request_t g_arm_request;
extern volatile uint32_t g_arm_heartbeat,g_arm_stop;
extern workflow_reply_t g_arm_reply;
extern workflow_record_t g_arm_calibration;
extern workflow_report_t g_arm_report;
extern workflow_readback_t g_arm_readback[6];
extern workflow_pose_record_t g_initial_pose;
void workflow_runtime_poll(void);
#endif
