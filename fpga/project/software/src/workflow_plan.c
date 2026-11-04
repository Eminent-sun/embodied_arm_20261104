#include "arm_workflow.h"
#include "arm_kinematics_port.h"
#include <math.h>
#include <string.h>
static const float lo[6]={-3.14f,.395710f,-3.027351f,-3.14f,-1.545172f,-3.14f};
static const float hi[6]={3.14f,3.223736f,.074481f,3.14f,1.57f,3.14f};
/* User-stated travel from RA8P1 HOME. ID3/ID5 clockwise mechPos increase,
 * separately confirmed on 2026-11-04; their RA8P1 gain is -1. Targets stay
 * inside these bounds even if a host config accidentally widens motor limits. */
static const float physical_lo[6]={-1.7453293f,-.0007964f,-2.0943951f,-2.0943951f,-.1753293f,-3.14f};
static const float physical_hi[6]={1.7453293f,3.1407964f,0.f,2.0943951f,1.57f,3.14f};
int workflow_joint_allowed(const float q[6]){
    if(!q)return 0;
    for(unsigned a=0;a<6;++a)if(!isfinite(q[a])||q[a]<lo[a]-1e-6f||q[a]>hi[a]+1e-6f||
        q[a]<physical_lo[a]-1e-6f||q[a]>physical_hi[a]+1e-6f)return 0;
    return 1;
}
static int append(const path_config_t *c,path_plan_t *p,const float q[6],unsigned stage,unsigned last,
                  workflow_yield_fn yield,void *context){
    if(yield){int rc=yield(context);if(rc)return rc;}
    if(p->count>=PATH_MAX_FRAMES)return PATH_INFEASIBLE;
    path_frame_t *f=&p->frames[p->count];f->time_ms=p->count*c->sample_ms;f->stage=stage;f->last_in_stage=last;
    float dt=c->sample_ms*.001f;
    for(unsigned a=0;a<6;++a){
        const path_axis_config_t *x=&c->axis[a];
        if(!isfinite(q[a])||q[a]<lo[a]-1e-6f||q[a]>hi[a]+1e-6f||
           q[a]<physical_lo[a]-1e-6f||q[a]>physical_hi[a]+1e-6f)return PATH_BAD_GEOMETRY;
        f->model_joint_rad[a]=q[a];f->motor_rad[a]=x->motor_zero_rad+x->gain*q[a];
        if(!isfinite(f->motor_rad[a])||f->motor_rad[a]<x->safe_min_rad||f->motor_rad[a]>x->safe_max_rad)return PATH_BAD_GEOMETRY;
        if(p->count){float d=f->motor_rad[a]-p->frames[p->count-1].motor_rad[a];
            float prior=p->count>1?p->frames[p->count-1].motor_rad[a]-p->frames[p->count-2].motor_rad[a]:0;
            if(fabsf(d)>.099f||fabsf(d)/dt>x->speed_rad_s*1.00001f||fabsf(d-prior)/(dt*dt)>x->accel_rad_s2*1.00001f)return PATH_INFEASIBLE;}
    }
    ++p->count;p->duration_ms=f->time_ms;
    return p->duration_ms<=c->max_job_ms?0:PATH_INFEASIBLE;
}
static int joint_segment(const path_config_t *c,path_plan_t *p,const float end[6],unsigned stage,workflow_yield_fn yield,void *context){
    unsigned saved=p->count,ticks=(3000+c->sample_ms-1)/c->sample_ms;
    float begin[6];memcpy(begin,p->frames[saved-1].model_joint_rad,sizeof(begin));
    for(unsigned trial=0;trial<16;++trial){
        p->count=saved;p->duration_ms=p->frames[saved-1].time_ms;int rc=0;
        for(unsigned t=1;t<=ticks;++t){float q[6],u=(float)t/ticks,s=u*u*u*(10+u*(-15+6*u));
            for(unsigned a=0;a<6;++a)q[a]=begin[a]+s*(end[a]-begin[a]);
            rc=append(c,p,q,stage,t==ticks,yield,context);if(rc)break;}
        if(!rc)return 0;
        if(rc!=PATH_INFEASIBLE)return rc;
        ticks=(ticks*5+3)/4;
    }
    return PATH_INFEASIBLE;
}
int workflow_joint_plan_build(const path_config_t *c,const float current[6],const float target[6],
 path_plan_t *p,workflow_yield_fn yield,void *context){
    if(!path_config_valid(c)||!p||!current||!workflow_joint_allowed(target))return PATH_BAD_GEOMETRY;
    /* MOVETO/GOHOME stream position targets to the motor's own PP planner.
     * A target profile at the full PP limits leaves no response headroom.
     * Retiming is private: do not reduce the motor's configured PP limits,
     * change the calibration CRC, or relax following/range/stop guards.
     * Validate the external config above; these lower internal planning
     * limits may be below the minimum accepted for motor parameter writes. */
    path_config_t trajectory=*c;
    for(unsigned a=0;a<6;++a){
        trajectory.axis[a].speed_rad_s*=.5f;
        trajectory.axis[a].accel_rad_s2*=.25f;
    }
    float start[6];
    for(unsigned a=0;a<6;++a){
        const path_axis_config_t *axis=&c->axis[a];
        start[a]=(current[a]-axis->motor_zero_rad)/axis->gain;
        /* A settled HOME lies on the J3/J5 physical limits. Encoder noise
         * must not turn its measured start into an out-of-range command.
         * Project only the START, by at most 0.001 model rad and never more
         * than the existing start/arrival tolerances. Targets and every
         * generated frame retain the original strict joint/motor bounds.
         * The caller still checks fresh settled feedback against frame 0.
         * Raw feedback and calibration are never rewritten. */
        float lower=fmaxf(lo[a],physical_lo[a]),upper=fminf(hi[a],physical_hi[a]);
        float bounded=fmaxf(lower,fminf(upper,start[a]));
        float tolerance=fminf(.001f,fminf(c->start_joint_tolerance_rad,
                              axis->arrival_position_rad/fabsf(axis->gain)));
        if(!isfinite(start[a])||fabsf(start[a]-bounded)>tolerance)return PATH_BAD_GEOMETRY;
        start[a]=bounded;
    }
    memset(p,0,sizeof(*p));int rc=append(&trajectory,p,start,8,0,yield,context);if(rc)return rc;
    rc=joint_segment(&trajectory,p,target,8,yield,context);if(rc)return rc;
    /* Only the final stationary frame requests arrival verification. */
    p->frames[p->count-1].last_in_stage=0;
    rc=append(&trajectory,p,target,8,0,yield,context);if(rc)return rc;
    return append(&trajectory,p,target,8,1,yield,context);
}
int workflow_plan_build(const path_config_t *c,const pick_candidate_report_t *g,unsigned op,
 const float current[6],const float initial[6],path_plan_t *p,workflow_yield_fn yield,void *context){
    if(!path_config_valid(c)||!p||!current||!initial)return PATH_BAD_CONFIG;
    if(!g||!g->math_passed||!g->complete||g->count<7||g->count>PICK_PREVIEW_MAX_SAMPLES||
       g->proposed_rpy_deg[0]!=0||g->proposed_rpy_deg[1]!=-45||g->proposed_rpy_deg[2]!=0)return PATH_BAD_GEOMETRY;
    if(op!=WF_PICK&&op!=WF_DELIVER&&op!=WF_RETURN)return WF_BAD_STATE;
    float q[6],desired[6];
    for(unsigned a=0;a<6;++a)q[a]=(current[a]-c->axis[a].motor_zero_rad)/c->axis[a].gain;
    memset(p,0,sizeof(*p));int rc=append(c,p,q,0,0,yield,context);if(rc)return rc;
    unsigned from=op==WF_PICK?1:op==WF_DELIVER?3:6;
    unsigned to=op==WF_PICK?2:op==WF_DELIVER?5:6;
    const float *entry=g->samples[0].joint_rad;
    if(from>1){for(unsigned i=0;i<g->count;++i)if(g->samples[i].stage_index==from-1)entry=g->samples[i].joint_rad;}
    /* Only PICK may approach from the saved initial configuration. Later
     * commands must still be at the endpoint of the preceding operation. */
    for(unsigned a=0;a<6;++a){float expected=op==WF_PICK?initial[a]:c->axis[a].motor_zero_rad+c->axis[a].gain*entry[a];
        if(!isfinite(expected)||fabsf(current[a]-expected)>c->axis[a].arrival_position_rad)return PATH_START_MISMATCH;}
    rc=joint_segment(c,p,entry,0,yield,context);if(rc)return rc;
    for(unsigned stage=from;stage<=to;++stage){
        unsigned first=0,end=0;while(first<g->count&&g->samples[first].stage_index<stage)++first;
        end=first;while(end<g->count&&g->samples[end].stage_index==stage)++end;
        if(!first||first==end)return PATH_BAD_GEOMETRY;
        const pick_preview_sample_t *start=&g->samples[first-1],*finish=&g->samples[end-1];
        unsigned saved=p->count,steps=end-first;
        unsigned ms=stage==1?2000:stage==2||stage==3?1000:stage==4||stage==5?5000:3000;
        unsigned ticks=(ms+c->sample_ms-1)/c->sample_ms;int built=0;
        for(unsigned trial=0;trial<16;++trial){p->count=saved;rc=0;
            for(unsigned t=1;t<=ticks;++t){float u=(float)t/ticks,s=u*u*u*(10+u*(-15+6*u)),pos=s*steps;
                unsigned k=(unsigned)pos;if(k>=steps)k=steps-1;float blend=t==ticks?1:pos-k;
                const float *a=k?g->samples[first+k-1].joint_rad:start->joint_rad,*b=g->samples[first+k].joint_rad;
                for(unsigned j=0;j<6;++j)q[j]=a[j]+(b[j]-a[j])*blend;
                urdf_pose_t actual,target={.rotation={{.7071067812f,0,-.7071067812f},{0,1,0},{.7071067812f,0,.7071067812f}}};
                urdf_kinematics_forward(q,&actual);
                for(unsigned j=0;j<3;++j)target.position[j]=(start->xyz_mm[j]+(finish->xyz_mm[j]-start->xyz_mm[j])*s)*.001f;
                float pe,oe;arm_kinematics_residual(&actual,&target,&pe,&oe);
                if(pe*1000>c->max_cartesian_error_mm||oe>.00873f)return PATH_BAD_GEOMETRY;
                rc=append(c,p,q,stage,t==ticks,yield,context);if(rc)break;
            }
            if(!rc){built=1;break;}if(rc!=PATH_INFEASIBLE)return rc;ticks=(ticks*5+3)/4;
        }
        if(!built)return PATH_INFEASIBLE;
        if(stage==2||stage==3){memcpy(q,p->frames[p->count-1].model_joint_rad,sizeof(q));
            unsigned n=(2000+c->sample_ms-1)/c->sample_ms;
            for(unsigned i=0;i<n;++i){rc=append(c,p,q,stage,0,yield,context);if(rc)return rc;}}
    }
    if(op==WF_RETURN){for(unsigned a=0;a<6;++a)desired[a]=(initial[a]-c->axis[a].motor_zero_rad)/c->axis[a].gain;
        rc=joint_segment(c,p,desired,7,yield,context);if(rc)return rc;}
    /* Two stationary frames explicitly check the final discrete deceleration. */
    memcpy(q,p->frames[p->count-1].model_joint_rad,sizeof(q));
    unsigned final_stage=op==WF_RETURN?7:to;
    rc=append(c,p,q,final_stage,0,yield,context);if(rc)return rc;return append(c,p,q,final_stage,1,yield,context);
}
