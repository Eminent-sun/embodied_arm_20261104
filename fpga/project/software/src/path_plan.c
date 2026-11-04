#include "path_executor.h"
#include "arm_kinematics_port.h"
#include <math.h>
#include <string.h>
static const float lower[6]={-3.14f,.395710f,-3.027351f,-3.14f,-1.545172f,-3.14f};
static const float upper[6]={3.14f,3.223736f,.074481f,3.14f,1.57f,3.14f};
static const float physical_lower[6]={-1.7453293f,-.0007964f,-2.0943951f,-2.0943951f,-.1753293f,-3.14f};
static const float physical_upper[6]={1.7453293f,3.1407964f,0.f,2.0943951f,1.57f,3.14f};
int path_config_valid(const path_config_t *c) {
    if(!c || c->calibration!=PATH_CAL_CONFIRMED || c->stop_policy!=PATH_STOP_POLICY_CONFIRMED ||
       c->sample_ms<20 || c->sample_ms>200 || !c->command_timeout_ms || c->command_timeout_ms>100 ||
       c->arrival_timeout_ms<c->sample_ms || c->arrival_timeout_ms>3000 || !c->max_job_ms || c->max_job_ms>55000 ||
       !isfinite(c->start_joint_tolerance_rad)||c->start_joint_tolerance_rad<=0||c->start_joint_tolerance_rad>.05f ||
       !isfinite(c->max_cartesian_error_mm)||c->max_cartesian_error_mm<=0||c->max_cartesian_error_mm>.5f) return 0;
    for(unsigned a=0;a<6;++a) {
        const path_axis_config_t *p=&c->axis[a];
        if(p->motor_id!=a+1 || p->expected_zero_state>1 || !isfinite(p->gain) || fabsf(p->gain)<.0001f ||
           !isfinite(p->motor_zero_rad)||!isfinite(p->safe_min_rad)||!isfinite(p->safe_max_rad)||
           p->safe_min_rad>=p->safe_max_rad||p->safe_min_rad<=-15.9f||p->safe_max_rad>=15.9f||
           !isfinite(p->speed_rad_s)||p->speed_rad_s<.1f||p->speed_rad_s>3.2f||
           !isfinite(p->accel_rad_s2)||p->accel_rad_s2<.1f||p->accel_rad_s2>3.2f||
           !isfinite(p->velocity_trip_rad_s)||p->velocity_trip_rad_s<p->speed_rad_s||p->velocity_trip_rad_s>3.2f||
           !isfinite(p->following_error_rad)||p->following_error_rad<=0||p->following_error_rad>.1f||
           !isfinite(p->arrival_position_rad)||p->arrival_position_rad<=0||p->arrival_position_rad>.05f||
           !isfinite(p->arrival_velocity_rad_s)||p->arrival_velocity_rad_s<=0||p->arrival_velocity_rad_s>p->velocity_trip_rad_s) return 0;
    }
    return 1;
}
static float progress(float u) {return u*u*u*(10.0f+u*(-15.0f+6.0f*u));}
static int append(const path_config_t *c,path_plan_t *p,unsigned stage,unsigned last,const float q[6],
                  const float *desired_xyz) {
    if(p->count>=PATH_MAX_FRAMES) return PATH_INFEASIBLE;
    path_frame_t *f=&p->frames[p->count];f->time_ms=p->count? p->frames[p->count-1].time_ms+c->sample_ms:0;
    f->stage=stage;f->last_in_stage=last;
    float dt=(float)c->sample_ms*.001f;
    for(unsigned a=0;a<6;++a) {
        const path_axis_config_t *axis=&c->axis[a];
        if(!isfinite(q[a])||q[a]<lower[a]-1e-6f||q[a]>upper[a]+1e-6f||
           q[a]<physical_lower[a]-1e-6f||q[a]>physical_upper[a]+1e-6f) return PATH_BAD_GEOMETRY;
        f->model_joint_rad[a]=q[a];f->motor_rad[a]=axis->motor_zero_rad+axis->gain*q[a];
        if(!isfinite(f->motor_rad[a])||f->motor_rad[a]<axis->safe_min_rad||f->motor_rad[a]>axis->safe_max_rad) return PATH_BAD_GEOMETRY;
        if(p->count) {
            float delta=f->motor_rad[a]-p->frames[p->count-1].motor_rad[a];
            if(fabsf(delta)>.099f||fabsf(delta)/dt>axis->speed_rad_s*1.00001f) return PATH_INFEASIBLE;
            float prior_delta=p->count>1?p->frames[p->count-1].motor_rad[a]-p->frames[p->count-2].motor_rad[a]:0;
            if(fabsf(delta-prior_delta)/(dt*dt)>axis->accel_rad_s2*1.00001f) return PATH_INFEASIBLE;
        }
    }
    if(desired_xyz) {
        urdf_pose_t actual;urdf_kinematics_forward(q,&actual);float sum=0;
        for(unsigned i=0;i<3;++i) {float d=actual.position[i]*1000-desired_xyz[i];sum+=d*d;}
        if(sqrtf(sum)>c->max_cartesian_error_mm) return PATH_BAD_GEOMETRY;
        const float s=.7071067811865475f;
        urdf_pose_t target={.rotation={{s,0,-s},{0,1,0},{s,0,s}},.position={0,0,0}};
        memcpy(target.position,actual.position,sizeof(target.position));
        float pe,oe;arm_kinematics_residual(&actual,&target,&pe,&oe);
        if(oe>.00873f) return PATH_BAD_GEOMETRY;
    }
    ++p->count;p->duration_ms=f->time_ms;
    return p->duration_ms<=c->max_job_ms?PATH_OK:PATH_INFEASIBLE;
}
static int hold(const path_config_t *c,path_plan_t *p,unsigned stage,unsigned ms) {
    float q[6];memcpy(q,p->frames[p->count-1].model_joint_rad,sizeof(q));
    unsigned n=(ms+c->sample_ms-1)/c->sample_ms;
    for(unsigned i=0;i<n;++i) {int rc=append(c,p,stage,0,q,0);if(rc) return rc;}
    return PATH_OK;
}
int path_plan_compile(const path_config_t *c,const pick_candidate_report_t *g,const float initial[6],path_plan_t *p) {
    if(!path_config_valid(c)) return PATH_BAD_CONFIG;
    if(!p||!g||!initial||g->magic!=0x50494331U||!g->complete||!g->math_passed||g->count<7||
       g->count>PICK_PREVIEW_MAX_SAMPLES || g->proposed_rpy_deg[0]!=0||g->proposed_rpy_deg[1]!=-45||g->proposed_rpy_deg[2]!=0) return PATH_BAD_GEOMETRY;
    memset(p,0,sizeof(*p));float initial_q[6];
    for(unsigned a=0;a<6;++a) {
        if(!isfinite(initial[a])) return PATH_START_MISMATCH;
        initial_q[a]=(initial[a]-c->axis[a].motor_zero_rad)/c->axis[a].gain;
        if(fabsf(initial_q[a]-g->samples[0].joint_rad[a])>c->start_joint_tolerance_rad) return PATH_START_MISMATCH;
    }
    int rc=append(c,p,0,0,initial_q,0);if(rc) return rc;
    unsigned preset_ticks=(3000+c->sample_ms-1)/c->sample_ms;
    for(unsigned t=1;t<=preset_ticks;++t) {
        float q[6],s=progress((float)t/(float)preset_ticks);
        for(unsigned a=0;a<6;++a) q[a]=initial_q[a]+(g->samples[0].joint_rad[a]-initial_q[a])*s;
        rc=append(c,p,0,t==preset_ticks,q,0);if(rc) return rc;
    }
    unsigned first=1;
    for(unsigned stage=1;stage<7;++stage) {
        unsigned end=first;while(end<g->count && g->samples[end].stage_index==stage) ++end;
        if(end==first) return PATH_BAD_GEOMETRY;
        const pick_preview_sample_t *start=&g->samples[first-1],*finish=&g->samples[end-1];
        unsigned saved=p->count,steps=end-first;
        unsigned minimum_ms=stage==1?2000:stage==2||stage==3?1000:stage==4||stage==5?5000:3000;
        unsigned ticks=(minimum_ms+c->sample_ms-1)/c->sample_ms;int built=0;
        for(unsigned trial=0;trial<14;++trial) {
            p->count=saved;p->duration_ms=p->frames[saved-1].time_ms;rc=0;
            for(unsigned t=1;t<=ticks;++t) {
                float s=progress((float)t/(float)ticks),pos=s*(float)steps;
                unsigned k=(unsigned)pos;if(k>=steps) k=steps-1;
                float blend=pos-(float)k;if(t==ticks) blend=1;
                const float *a=k?g->samples[first+k-1].joint_rad:start->joint_rad;
                const float *b=g->samples[first+k].joint_rad;
                float q[6],xyz[3];for(unsigned j=0;j<6;++j) q[j]=a[j]+(b[j]-a[j])*blend;
                for(unsigned j=0;j<3;++j) xyz[j]=start->xyz_mm[j]+(finish->xyz_mm[j]-start->xyz_mm[j])*s;
                rc=append(c,p,stage,t==ticks,q,xyz);if(rc) break;
            }
            if(!rc) {built=1;break;}
            if(rc==PATH_BAD_GEOMETRY) return rc;
            ticks=(ticks*5+3)/4;
        }
        if(!built) return PATH_INFEASIBLE;
        if(stage==2||stage==3) {rc=hold(c,p,stage,2000);if(rc) return rc;}
        first=end;
    }
    /* Return to the measured initial configuration; never issue motor zero or
     * assume URDF home. This return is joint-space, not a Cartesian straight line. */
    unsigned saved=p->count;float last[6];memcpy(last,p->frames[saved-1].model_joint_rad,sizeof(last));
    unsigned ticks=(3000+c->sample_ms-1)/c->sample_ms;int built=0;
    for(unsigned trial=0;trial<14;++trial) {
        p->count=saved;p->duration_ms=p->frames[saved-1].time_ms;rc=0;
        for(unsigned t=1;t<=ticks;++t) {
            float s=progress((float)t/(float)ticks),q[6];for(unsigned a=0;a<6;++a) q[a]=last[a]+(initial_q[a]-last[a])*s;
            rc=append(c,p,7,t==ticks,q,0);if(rc) break;
        }
        if(!rc) {built=1;break;}if(rc==PATH_BAD_GEOMETRY) return rc;ticks=(ticks*5+3)/4;
    }
    return built?PATH_OK:PATH_INFEASIBLE;
}
