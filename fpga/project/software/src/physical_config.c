#include "physical_config.h"
const uint32_t g_joint_motor_ids[6]={1,2,3,4,5,6};
/* User: no end tool installed. Control Link6 origin for the present stage. */
const arm_tool_t g_current_control_point={
    .link6_from_tcp={.rotation={{1,0,0},{0,1,0},{0,0,1}},.position={0,0,0}},
    .tool_id=6,.revision=1,.calibration=ARM_TOOL_LINK6_REFERENCE
};
const uint32_t g_motor_calibration_confirmed=0;
