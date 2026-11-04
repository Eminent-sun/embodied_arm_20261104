#ifndef FIXED_PATH_H
#define FIXED_PATH_H
#include <stdint.h>
#include "arm_kinematics_port.h"
#define FIXED_PATH_STAGE_COUNT 8U
enum { FIXED_POSE=0, FIXED_LEGACY_MOTOR_ZERO=1 };
enum { FIXED_BLOCK_FRAME_UNCONFIRMED=1, FIXED_BLOCK_IK=2, FIXED_BLOCK_ZERO_UNCONFIRMED=4 };
typedef struct {
    uint32_t kind;
    float legacy_matrix_mm[4][4];
    uint32_t original_gate_ms,hold_after_arrival_ms,original_arrival_timeout_ms;
} fixed_waypoint_t;
typedef struct {
    uint32_t stage_index;
    fixed_waypoint_t waypoint;
    arm_ik_solution_t model_solution;
} fixed_path_stage_result_t;
typedef struct {
    uint32_t magic,version,complete,count,valid_pose_mask,failed_pose_mask,blockers,execution_allowed;
    fixed_path_stage_result_t stages[FIXED_PATH_STAGE_COUNT];
} fixed_path_report_t;
/* Original RA6M5 nominal targets, skipping only vision/gripper per user request.
 * Return-zero remains a legacy MOTOR-space action, not a guessed URDF home.
 * Timing metadata records original gates/timeouts, not validated segment times.
 */
bool fixed_path_get_waypoint(unsigned index,fixed_waypoint_t *out);
/* Diagnostic only: provisional identity of legacy and URDF base/Link6 frames.
 * Full pass cannot authorize motion until frame/zero mapping is resolved.
 * No mailbox/CAN, enable, motion, homing or parameter writes exist in this API.
 */
bool fixed_path_preflight(const float model_seed_rad[6],fixed_path_report_t *out);
bool fixed_path_can_start(const fixed_path_report_t *report);
#endif
