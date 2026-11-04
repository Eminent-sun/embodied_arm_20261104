/* Offline planning feasibility only; no hardware transport or real calibration. */
#include "arm_workflow.h"
#include <math.h>
#include <stdio.h>
#include <string.h>

static pick_candidate_report_t geometry;
static path_plan_t plan;
int main(void) {
    pick_candidate_preview(&geometry);
    if (!geometry.math_passed) return 1;
    const float home[6]={0,1.57f,0,0,1.57f,0};
    const float gain[6]={-1,-1,-1,-1,-1,1};
    const float low[6]={-1.7453293f,-1.5707963f,0,-2.0943951f,0,-3.14f};
    const float high[6]={1.7453293f,1.17429f,2.0943951f,2.0943951f,1.7453293f,3.14f};
    const float rates[][2]={{.1f,.1f},{.2f,.2f},{.3f,.3f},{.5f,.5f},{.5f,1.f},{.75f,1.f},{1.f,2.f}};
    for(unsigned r=0;r<sizeof(rates)/sizeof(rates[0]);++r) {
        path_config_t c={0};c.calibration=PATH_CAL_CONFIRMED;c.stop_policy=PATH_STOP_POLICY_CONFIRMED;
        c.sample_ms=50;c.command_timeout_ms=50;c.arrival_timeout_ms=1000;c.max_job_ms=55000;
        c.start_joint_tolerance_rad=.01f;c.max_cartesian_error_mm=.5f;
        float initial[6]={0},current[6]={0};
        for(unsigned a=0;a<6;++a) {
            path_axis_config_t *x=&c.axis[a];x->motor_id=a+1;x->expected_zero_state=a==3?0:1;
            x->gain=gain[a];x->motor_zero_rad=-gain[a]*home[a];x->safe_min_rad=low[a];x->safe_max_rad=high[a];
            x->speed_rad_s=rates[r][0];x->accel_rad_s2=rates[r][1];x->velocity_trip_rad_s=3.2f;
            x->following_error_rad=.099f;x->arrival_position_rad=.01f;x->arrival_velocity_rad_s=.02f;
        }
        if(!path_config_valid(&c))return 2;
        printf("speed=%.2f accel=%.2f",rates[r][0],rates[r][1]);
        for(unsigned op=WF_PICK;op<=WF_RETURN;++op) {
            int rc=workflow_plan_build(&c,&geometry,op,current,initial,&plan,0,0);
            printf(" %s=%d/%u_ms",op==WF_PICK?"PICK":op==WF_DELIVER?"DELIVER":"RETURN",rc,rc?0:plan.duration_ms);
            if(rc)break;
            for(unsigned a=0;a<6;++a)current[a]=plan.frames[plan.count-1].motor_rad[a];
        }
        putchar('\n');
    }
    return 0;
}
