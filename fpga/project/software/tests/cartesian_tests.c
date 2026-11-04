/* Offline synthetic plant only; never used as physical calibration. */
#define CARTESIAN_TESTS_ONLY
#include "workflow_tests.c"

static unsigned services;
static int count_service(void *unused){(void)unused;++services;return 0;}
static int cancel_service(void *unused){(void)unused;return ++services==3;}
static int fail_health(void *context){fixture_t *f=context;return f->m.ms<100000;}
static arm_cartesian_pose_mm_deg_t pose_from_q(const float q[6]){
    urdf_pose_t fk;urdf_kinematics_forward(q,&fk);
    arm_cartesian_pose_mm_deg_t p;
    for(unsigned i=0;i<3;++i)p.xyz_mm[i]=fk.position[i]*1000;
    p.rpy_deg[0]=atan2f(fk.rotation[2][1],fk.rotation[2][2])*57.295779513f;
    p.rpy_deg[1]=atan2f(-fk.rotation[2][0],hypotf(fk.rotation[0][0],fk.rotation[1][0]))*57.295779513f;
    p.rpy_deg[2]=atan2f(fk.rotation[1][0],fk.rotation[0][0])*57.295779513f;
    return p;
}
int main(void){
    unsigned checks=0;fixture_t f={0};path_io_t io={&f,now,healthy,wf_tx,page,stop};
    workflow_init(&workflow,&io,&geometry,&plan,0);
    arm_cartesian_pose_mm_deg_t target={{200,0,100},{0,-45,0}};
    workflow_cartesian_report_t r;
    CHECK(workflow_cartesian(&workflow,&target,&r,0)==0&&r.model_only&&!r.plan_valid&&f.m.commands==0);
    CHECK(workflow_cartesian(&workflow,&target,&r,1)==WF_BAD_STATE&&f.m.enables==0);
    target.xyz_mm[0]=NAN;CHECK(workflow_cartesian(&workflow,&target,&r,0)==PATH_BAD_GEOMETRY);
    target.xyz_mm[0]=99999;CHECK(workflow_cartesian(&workflow,&target,&r,0)==PATH_BAD_GEOMETRY&&f.m.commands==0);
    target.xyz_mm[0]=200;
    arm_ik_solution_t sol;float home[6]={0,1.57f,0,0,1.57f,0};
    services=0;arm_kinematics_set_service(count_service,0);
    CHECK(arm_kinematics_solve_rpy_mm_deg(&target,home,&sol)&&services>0);
    services=0;arm_kinematics_set_service(cancel_service,0);
    CHECK(!arm_kinematics_solve_rpy_mm_deg(&target,home,&sol)&&services==3);
    arm_kinematics_set_service(0,0);
    path_config_t c=config();c.calibration=0;
    for(unsigned a=0;a<6;++a){
        c.axis[a].gain=a==5?1:-1;c.axis[a].speed_rad_s=.5f;c.axis[a].accel_rad_s2=.5f;
        f.m.pos[a]=.2f+c.axis[a].gain*home[a];f.m.target[a]=f.m.pos[a];f.m.count[a]=1;
    }
    CHECK(workflow_configure(&workflow,&c)==0);
    CHECK(workflow_command(&workflow,WF_BEGIN,0,0)==0);
    for(unsigned a=0;a<6;++a)CHECK(workflow_command(&workflow,WF_CAL_AXIS,a+1,home[a])==0);
    CHECK(workflow_command(&workflow,WF_SAVE_INITIAL,0,0)==0);
    workflow_record_t saved_record=workflow.record;
    unsigned enables=f.m.enables;CHECK(workflow_cartesian(&workflow,&target,&r,0)==0&&r.plan_valid&&!r.model_only);
    CHECK(memcmp(&saved_record,&workflow.record,sizeof(saved_record))==0);
    CHECK(r.duration_ms>6000&&r.duration_ms<=c.max_job_ms);
    for(unsigned a=0;a<6;++a)CHECK(fp(f.m.speed[a])==.5f&&fp(f.m.accel[a])==.5f);
    CHECK(workflow.report.state==WF_INITIAL&&f.hold&&f.m.enables==enables&&f.m.seq==0);
    CHECK(workflow_cartesian(&workflow,&target,&r,1)==0&&workflow.report.state==WF_MOVING_CARTESIAN);
    CHECK(workflow_cartesian(&workflow,&target,&r,1)==WF_BAD_STATE);
    CHECK(run_motion(&f,WF_CARTESIAN_HOLD)&&f.hold&&f.m.enables==enables);
    const float q[6]={.5f,2.f,-.8f,.3f,1.f,.4f};target=pose_from_q(q);
    CHECK(workflow_cartesian(&workflow,&target,&r,1)==0);
    CHECK(run_motion(&f,WF_CARTESIAN_HOLD)&&f.hold&&f.m.enables==enables);
    urdf_pose_t fk,desired;float actual[6],pe,oe;
    for(unsigned a=0;a<6;++a)actual[a]=(f.m.pos[a]-.2f)/c.axis[a].gain;
    urdf_kinematics_forward(actual,&fk);CHECK(arm_kinematics_pose_from_rpy_mm_deg(&target,&desired));
    arm_kinematics_residual(&fk,&desired,&pe,&oe);CHECK(pe<=.0005f&&oe<=.00873f);
    float prev[6]={0};
    for(unsigned i=1;i<plan.count;++i)for(unsigned a=0;a<6;++a){
        float d=plan.frames[i].motor_rad[a]-plan.frames[i-1].motor_rad[a];
        CHECK(fabsf(d)/.05f<=.25001f&&fabsf(d-prev[a])/.0025f<=.1251f);prev[a]=d;
    }
    CHECK(plan.frames[plan.count-1].time_ms==plan.duration_ms);
    CHECK(plan.frames[plan.count-1].last_in_stage&&!plan.frames[plan.count-2].last_in_stage);
    for(unsigned a=0;a<6;++a)CHECK(plan.frames[plan.count-1].motor_rad[a]==plan.frames[plan.count-2].motor_rad[a]&&
        fabsf(plan.frames[plan.count-2].motor_rad[a]-plan.frames[plan.count-3].motor_rad[a])<1e-6f);
    CHECK(workflow_go_home(&workflow)==0&&run_motion(&f,WF_INITIAL));
    for(unsigned a=0;a<6;++a)CHECK(fabsf(f.m.pos[a]-workflow.record.initial_motor_rad[a])<1e-6f);
    CHECK(memcmp(&saved_record,&workflow.record,sizeof(saved_record))==0);
    path_config_t limited=workflow.record.config;limited.max_job_ms=3000;
    CHECK(workflow_joint_plan_build(&limited,f.m.pos,q,&plan,0,0)==PATH_INFEASIBLE);
    limited=workflow.record.config;
    for(unsigned a=0;a<6;++a){limited.axis[a].speed_rad_s=.1f;limited.axis[a].accel_rad_s2=.1f;}
    CHECK(workflow_joint_plan_build(&limited,f.m.pos,q,&plan,0,0)==0);
    memset(prev,0,sizeof(prev));
    for(unsigned i=1;i<plan.count;++i)for(unsigned a=0;a<6;++a){
        float d=plan.frames[i].motor_rad[a]-plan.frames[i-1].motor_rad[a];
        CHECK(fabsf(d)/.05f<=.05001f&&fabsf(d-prev[a])/.0025f<=.0251f);prev[a]=d;
    }
    services=0;
    CHECK(workflow_joint_plan_build(&limited,f.m.pos,q,&plan,cancel_service,0)!=0&&services==3);
    float outside[6]={0,1.57f,.01f,0,1.57f,0};
    CHECK(workflow_joint_plan_build(&workflow.record.config,f.m.pos,outside,&plan,0,0)==PATH_BAD_GEOMETRY);
    /* Settled HOME encoder noise at J3/J5 must not widen commanded limits. */
    float noisy[6];memcpy(noisy,f.m.pos,sizeof(noisy));
    noisy[2]+=c.axis[2].gain*.0004f;
    noisy[4]+=c.axis[4].gain*.0004f;
    CHECK(workflow_joint_plan_build(&workflow.record.config,noisy,q,&plan,0,0)==0);
    CHECK(plan.frames[0].model_joint_rad[2]==0&&plan.frames[0].model_joint_rad[4]<=1.57f);
    for(unsigned i=0;i<plan.count;++i)CHECK(workflow_joint_allowed(plan.frames[i].model_joint_rad));
    noisy[2]=f.m.pos[2]+c.axis[2].gain*.0012f;
    CHECK(workflow_joint_plan_build(&workflow.record.config,noisy,q,&plan,0,0)==PATH_BAD_GEOMETRY);
    outside[2]=.0004f;
    CHECK(workflow_joint_plan_build(&workflow.record.config,f.m.pos,outside,&plan,0,0)==PATH_BAD_GEOMETRY);
    path_config_t strict=workflow.record.config;strict.start_joint_tolerance_rad=.0001f;
    noisy[2]=f.m.pos[2]+c.axis[2].gain*.0004f;
    CHECK(workflow_joint_plan_build(&strict,noisy,q,&plan,0,0)==PATH_BAD_GEOMETRY);
    c=workflow.record.config;workflow.record.config.axis[0].speed_rad_s=1;
    workflow.record.crc32=workflow_crc32(&workflow.record,offsetof(workflow_record_t,crc32));
    CHECK(workflow_cartesian(&workflow,&target,&r,1)==PATH_BAD_CONFIG);
    workflow.record.config=c;
    workflow.record.crc32=workflow_crc32(&workflow.record,offsetof(workflow_record_t,crc32));
    /* Failure during planning service stops rather than publishing targets. */
    io.healthy=fail_health;f.m.ms=99999;workflow.next_poll=f.m.ms;unsigned seq=f.m.seq;
    CHECK(workflow_cartesian(&workflow,&target,&r,1)!=0);
    CHECK(workflow.report.state==WF_FAULT&&workflow.report.stop_confirmed&&f.m.seq==seq);
    printf("PASS CARTESIAN %u CHECKS (synthetic plant; no hardware)\n",checks);return 0;
}
