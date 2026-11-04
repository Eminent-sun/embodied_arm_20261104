#ifndef PICK_CANDIDATE_H
#define PICK_CANDIDATE_H
#include <stdint.h>
#define PICK_PREVIEW_MAX_SAMPLES 320U
typedef struct {
    uint32_t stage_index,segment_step,segment_steps,status;
    float xyz_mm[3],joint_rad[6],position_error_mm,orientation_error_rad;
} pick_preview_sample_t;
typedef struct {
    uint32_t magic,version,complete,count,math_passed,failed_stage,applied_to_original,execution_allowed;
    float proposed_rpy_deg[3],spatial_step_mm,max_joint_step_rad,max_position_error_mm,max_orientation_error_rad;
    pick_preview_sample_t samples[PICK_PREVIEW_MAX_SAMPLES];
} pick_candidate_report_t;
/* User accepted this geometry for PS-PL development on 2026-11-03. Keep
 * legacy XYZ/order and user-approved RPY=(0,-45,0) in URDF base/Link6 coordinates. No actual motor
 * seed, start transition, wait durations, joint-to-motor map or dynamics plan.
 * The geometry alone never authorizes motion; runtime separately requires
 * verified calibration/stop policy and explicit GO. Legacy report is preserved.
 */
void pick_candidate_preview(pick_candidate_report_t *report);
void pick_candidate_preview_rpy(const float proposed_rpy_deg[3],pick_candidate_report_t *report);
#endif
