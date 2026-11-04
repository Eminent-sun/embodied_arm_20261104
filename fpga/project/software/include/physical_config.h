#ifndef PHYSICAL_CONFIG_H
#define PHYSICAL_CONFIG_H
#include "arm_tool.h"
extern const uint32_t g_joint_motor_ids[6];
extern const arm_tool_t g_current_control_point;
/* Axis ID order confirmed by user. Direction, zero, soft limits and loaded
 * stop/hold policy are NOT thereby calibrated. This keeps motor start locked. */
extern const uint32_t g_motor_calibration_confirmed;
#endif
