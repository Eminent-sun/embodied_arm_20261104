#include "pick_candidate.h"
#include "fixed_path.h"
#include "arm_tool.h"
#include "physical_config.h"
#include <math.h>
#include <string.h>
void pick_candidate_preview(pick_candidate_report_t *r) {
    const float orientation[3]={0,-45,0};pick_candidate_preview_rpy(orientation,r);
}
void pick_candidate_preview_rpy(const float orientation[3],pick_candidate_report_t *r) {
    if(!r) return;
    memset(r,0,sizeof(*r));r->magic=0x50494331U;r->version=1;
    if(!orientation || !isfinite(orientation[0]) || !isfinite(orientation[1]) || !isfinite(orientation[2])) {
        r->failed_stage=0;r->complete=1;return;
    }
    memcpy(r->proposed_rpy_deg,orientation,sizeof(r->proposed_rpy_deg));r->spatial_step_mm=5;r->failed_stage=0xffffffffU;
    float seed[6]={0,1.57f,0,0,1.57f,0},previous_xyz[3]={0};
    bool failed=false;
    for(unsigned stage=0;stage<7 && !failed;++stage) {
        fixed_waypoint_t point;(void)fixed_path_get_waypoint(stage,&point);
        float end[3];for(unsigned i=0;i<3;++i) end[i]=point.legacy_matrix_mm[i][3];
        unsigned steps=1;
        if(stage) {
            float d2=0;for(unsigned i=0;i<3;++i) {float d=end[i]-previous_xyz[i];d2+=d*d;}
            steps=(unsigned)ceilf(sqrtf(d2)/r->spatial_step_mm);if(!steps) steps=1;
        }
        for(unsigned step=1;step<=steps;++step) {
            if(r->count>=PICK_PREVIEW_MAX_SAMPLES) {failed=true;r->failed_stage=stage;break;}
            pick_preview_sample_t *s=&r->samples[r->count++];s->stage_index=stage;s->segment_step=step;s->segment_steps=steps;
            arm_cartesian_pose_mm_deg_t input={{0},{0}};
            memcpy(input.rpy_deg,orientation,sizeof(input.rpy_deg));
            float f=(float)step/(float)steps;
            for(unsigned i=0;i<3;++i) {input.xyz_mm[i]=stage?previous_xyz[i]+(end[i]-previous_xyz[i])*f:end[i];s->xyz_mm[i]=input.xyz_mm[i];}
            arm_ik_solution_t out;
            if(!arm_kinematics_solve_rpy_mm_deg(&input,seed,&out)) {s->status=out.status;failed=true;r->failed_stage=stage;break;}
            memcpy(s->joint_rad,out.joint_rad,sizeof(s->joint_rad));s->position_error_mm=out.position_error_mm;s->orientation_error_rad=out.orientation_error_rad;
            if(out.position_error_mm>r->max_position_error_mm) r->max_position_error_mm=out.position_error_mm;
            if(out.orientation_error_rad>r->max_orientation_error_rad) r->max_orientation_error_rad=out.orientation_error_rad;
            if(r->count>1) for(unsigned i=0;i<6;++i) {
                float d=fabsf(out.joint_rad[i]-seed[i]);if(d>r->max_joint_step_rad) r->max_joint_step_rad=d;
            }
            memcpy(seed,out.joint_rad,sizeof(seed));
        }
        memcpy(previous_xyz,end,sizeof(end));
    }
    r->math_passed=failed?0U:1U;r->applied_to_original=0;r->execution_allowed=0;r->complete=1;
}
