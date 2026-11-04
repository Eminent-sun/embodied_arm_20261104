#include "arm_workflow.h"
#include "pieper_kinematics.h"
#include <math.h>
#include <string.h>
static const float lo[6]={-3.14f,.395710f,-3.027351f,-3.14f,-1.545172f,-3.14f};
static const float hi[6]={3.14f,3.223736f,.074481f,3.14f,1.57f,3.14f};
static uint32_t bits(float f){union{float f;uint32_t u;}v={.f=f};return v.u;}
static float fp(uint32_t u){union{float f;uint32_t u;}v={.u=u};return v.f;}
uint32_t workflow_crc32(const void *data,size_t n){const unsigned char *p=data;uint32_t c=~0U;
    while(n--){c^=*p++;for(unsigned b=0;b<8;++b)c=(c>>1)^(0xedb88320U&-(c&1U));}return ~c;}
static void seal(arm_workflow_t *w){++w->record.generation;w->record.crc32=workflow_crc32(&w->record,offsetof(workflow_record_t,crc32));
    w->report.calibrated_mask=w->record.calibrated_mask;w->report.initial_valid=w->record.initial_valid;}
static int config_valid(const path_config_t *c){path_config_t copy=*c;copy.calibration=PATH_CAL_CONFIRMED;return path_config_valid(&copy);}
int workflow_record_valid(const workflow_record_t *r){
    if(!r||r->magic!=WF_RECORD_MAGIC||r->version!=1||r->reserved||!r->generation||r->calibrated_mask!=63||r->initial_valid!=1||
       !path_config_valid(&r->config)||r->crc32!=workflow_crc32(r,offsetof(workflow_record_t,crc32)))return 0;
    for(unsigned a=0;a<6;++a){const path_axis_config_t *c=&r->config.axis[a];
        float derived=c->motor_zero_rad+c->gain*r->reference_joint_rad[a];
        float init=c->motor_zero_rad+c->gain*r->initial_joint_rad[a];
        if(!isfinite(r->reference_joint_rad[a])||r->reference_joint_rad[a]<lo[a]||r->reference_joint_rad[a]>hi[a]||
           !isfinite(r->captured_motor_rad[a])||fabsf(derived-r->captured_motor_rad[a])>.001f||
           r->captured_motor_rad[a]<c->safe_min_rad||r->captured_motor_rad[a]>c->safe_max_rad||
           !isfinite(r->initial_joint_rad[a])||r->initial_joint_rad[a]<lo[a]-1e-6f||r->initial_joint_rad[a]>hi[a]+1e-6f||
           !isfinite(r->initial_motor_rad[a])||fabsf(init-r->initial_motor_rad[a])>.001f||
           r->initial_motor_rad[a]<c->safe_min_rad||r->initial_motor_rad[a]>c->safe_max_rad)return 0;
    }return 1;
}
void workflow_init(arm_workflow_t *w,const path_io_t *io,const pick_candidate_report_t *g,path_plan_t *p,path_plan_t *s){
    memset(w,0,sizeof(*w));w->io=io;w->geometry=g;w->plan=p;w->scratch=s;w->report.magic=0x57465231U;w->report.version=1;}
int workflow_configure(arm_workflow_t *w,const path_config_t *c){
    if(!w||!c||!config_valid(c))return PATH_BAD_CONFIG;
    if(w->report.active_mask||w->report.state==WF_FAULT)return WF_BAD_STATE;
    memset(&w->record,0,sizeof(w->record));w->record.magic=WF_RECORD_MAGIC;w->record.version=1;w->record.config=*c;
    w->record.config.calibration=0;w->report.state=WF_CONFIGURED;w->report.error=0;seal(w);return 0;
}
int workflow_restore(arm_workflow_t *w,const workflow_record_t *r){
    if(!w||!workflow_record_valid(r))return WF_BAD_RECORD;
    if(w->report.active_mask||w->report.state==WF_FAULT)return WF_BAD_STATE;
    w->record=*r;w->report.state=WF_CONFIGURED;w->report.calibrated_mask=63;w->report.initial_valid=1;w->report.error=0;return 0;
}
static uint32_t now(arm_workflow_t *w){return w->io->now_ms(w->io->context);}
static void start_timing(arm_workflow_t *w,unsigned completion_spacing){
    memset(&w->timing,0,sizeof(w->timing));w->timing.magic=0x54494d31U;w->timing.version=1;
    w->timing.period_policy=completion_spacing;w->timing.sample_ms=w->record.config.sample_ms;
    w->timing.dispatch_late_limit_ms=WF_DISPATCH_LATE_LIMIT_MS;
    w->next_frame_due=w->epoch;
}
static int cmd(arm_workflow_t *w,unsigned a,unsigned op,unsigned index,uint32_t value,uint32_t *result){
    return w->io->transaction(w->io->context,(index<<11)|(op<<8)|(a+1),value,result)?PATH_IO_ERROR:0;}
static int readf(arm_workflow_t *w,unsigned a,unsigned index,float *value){uint32_t u;
    if(cmd(w,a,0,index,0,&u))return PATH_IO_ERROR;
    *value=fp(u);return isfinite(*value)?0:PATH_IO_ERROR;}
int workflow_read_parameters(arm_workflow_t *w,workflow_readback_t out[6]){
    if(!w||!out||!w->io||!w->io->healthy(w->io->context))return PATH_IO_ERROR;
    for(unsigned a=0;a<6;++a){workflow_readback_t *r=&out[a];r->motor_id=a+1;
        if(cmd(w,a,0,0x7005,0,&r->run_mode)||cmd(w,a,0,0x7029,0,&r->zero_state)||cmd(w,a,0,0x702b,0,&r->offset_bits)||
           readf(w,a,0x7019,&r->position_rad)||readf(w,a,0x701b,&r->velocity_rad_s))return PATH_IO_ERROR;
        w->report.position[a]=r->position_rad;w->report.velocity[a]=r->velocity_rad_s;
        workflow_tick(w,w->io->healthy(w->io->context));if(w->report.state==WF_FAULT)return (int)w->report.error;
    }return 0;
}
static int observe(arm_workflow_t *w,unsigned mask,int *arrived){
    *arrived=1;
    /* A completed six-axis hold keeps its original PP target when a
     * person deflects the arm.  Do not fault on following error, the narrow
     * startup window, or hand-guiding speed.  Keep motor status, finite value,
     * protocol range, CAN health, host heartbeat and PL lease protections.
     * Partial-axis preparation and every trajectory state retain all checks. */
    const int hold_state=w->report.state==WF_REFERENCE_HOLD||w->report.state==WF_INITIAL||
                         w->report.state==WF_AT_PICK||w->report.state==WF_AT_DELIVERY||w->report.state==WF_CARTESIAN_HOLD;
    const int drag_tolerant_hold=hold_state && w->report.active_mask==63 && mask==63;
    for(unsigned a=0;a<6;++a)if(mask&(1U<<a)){
        float p,v;const path_axis_config_t *c=&w->record.config.axis[a];
        if(readf(w,a,0x7019,&p)||readf(w,a,0x701b,&v))return PATH_IO_ERROR;
        w->report.position[a]=p;w->report.velocity[a]=v;
        uint32_t s=w->io->feedback_page(w->io->context,a,0);
        if(!(s&0x20000U)||(s&255U)!=a+1||(s&0xfc00U)||((s>>8)&3U)!=2||fabsf(p)>=15.9f||
           (!drag_tolerant_hold&&(p<c->safe_min_rad||p>c->safe_max_rad||
             fabsf(v)>c->velocity_trip_rad_s||fabsf(p-w->report.target[a])>c->following_error_rad)))return PATH_TRACK_ERROR;
        if(fabsf(p-w->report.target[a])>c->arrival_position_rad||fabsf(v)>c->arrival_velocity_rad_s)*arrived=0;
    }return w->io->healthy(w->io->context)?0:PATH_IO_ERROR;
}
static int stop(arm_workflow_t *w,int fault,int error){
    if(fault&&!w->report.fault_cause)w->report.fault_cause=(unsigned)error;
    workflow_stop_trace_t *trace=&w->stop_trace;
    memset(trace,0,sizeof(*trace));trace->magic=0x53545031U;trace->version=1;
    for(unsigned a=0;a<6;++a)trace->before_count[a]=w->io->feedback_page(w->io->context,a,1);
    w->report.stop_confirmed=0;
    int rc=0;if(fault)w->io->emergency_stop(w->io->context);else rc=cmd(w,0,4,0,0,0);
    uint32_t started=now(w);unsigned mask=0;
    while(!rc&&now(w)-started<300){mask=0;unsigned stable_mask=0;
        for(unsigned a=0;a<6;++a){
            uint32_t n=w->io->feedback_page(w->io->context,a,1);
            uint32_t s=w->io->feedback_page(w->io->context,a,0);
            /* A5 locks the PL and the host STOP flag blocks normal CAN reads.
             * Decode velocity from the NEW status frame already cached by PL.
             * Vendor type-2 feedback: EL05 maps uint16 to +/-50 rad/s;
             * RS00 (ID2) maps uint16 to +/-33 rad/s. */
            uint32_t raw=(w->io->feedback_page(w->io->context,a,5)>>16)&0xffffU;
            uint32_t after=w->io->feedback_page(w->io->context,a,1);
            trace->last_count[a]=after;trace->last_status[a]=s;
            trace->velocity_raw[a]=raw;
            /* The count brackets the cached status/payload reads. Retry if a
             * status frame changed while reading; never combine two frames. */
            if(n!=after||n==trace->before_count[a]||!(s&0x20000U)||
               (s&255U)!=a+1||(s&0x10ff00U))continue;
            mask|=1U<<a;
            float fullscale=a==1?33.f:50.f;
            float v=2.f*fullscale*(float)raw/65535.f-fullscale;
            float limit=w->record.config.axis[a].arrival_velocity_rad_s;
            if(isfinite(limit)&&limit>0&&fabsf(v)<=limit)stable_mask|=1U<<a;
        }
        trace->ack_mask=mask;
        if(mask==63&&stable_mask==63){w->report.stop_confirmed=1;break;}
    }
    trace->elapsed_ms=now(w)-started;
    if(!w->report.stop_confirmed){fault=1;error=PATH_STOP_UNKNOWN;}
    /* A fault remains latched even when stopped. No auto unlock/recovery. */
    w->report.state=fault?WF_FAULT:WF_CONFIGURED;w->report.error=(unsigned)error;
    if(w->report.stop_confirmed)w->report.active_mask=0;
    return error;
}
static int renew(arm_workflow_t *w){uint32_t value;
    if(w->hold_sequence==0xffffffffU||cmd(w,0,7,3,w->hold_sequence+1,&value)||value!=w->hold_sequence+1)return PATH_IO_ERROR;
    ++w->hold_sequence;return 0;}
static int publish(arm_workflow_t *w,const float target[6]){uint32_t value;
    for(unsigned a=0;a<6;++a)if(cmd(w,a,5,0x7016,bits(target[a]),0))return PATH_IO_ERROR;
    if(w->path_sequence==0xffffffffU||cmd(w,0,7,1,w->path_sequence+1,&value)||value!=w->path_sequence+1)return PATH_IO_ERROR;
    ++w->path_sequence;memcpy(w->report.target,target,sizeof(w->report.target));return 0;}
static int prepare(arm_workflow_t *w,unsigned a,float *pout){
    const path_axis_config_t *c=&w->record.config.axis[a];uint32_t value;float p,v,positive;
    if(cmd(w,a,0,0x7029,0,&value)||value!=c->expected_zero_state||cmd(w,a,0,0x702b,0,&value)||value!=c->expected_offset_bits||
       readf(w,a,0x7019,&p)||readf(w,a,0x701b,&v)||p<c->safe_min_rad||p>c->safe_max_rad||fabsf(v)>c->arrival_velocity_rad_s||
       readf(w,a,0x7018,&positive)||positive<=0||readf(w,a,0x700b,&positive)||positive<=0)return PATH_PREPARE_ERROR;
    uint32_t s=w->io->feedback_page(w->io->context,a,0);
    if(!(s&0x20000U)||(s&255U)!=a+1||(s&0xff00U))return PATH_PREPARE_ERROR;
    if(cmd(w,a,2,0x7005,1,&value)||value!=1||cmd(w,a,1,0x7024,bits(c->speed_rad_s),&value)||value!=bits(c->speed_rad_s)||
       cmd(w,a,1,0x7025,bits(c->accel_rad_s2),&value)||value!=bits(c->accel_rad_s2)||
       readf(w,a,0x7019,&p)||p<c->safe_min_rad||p>c->safe_max_rad||
       cmd(w,a,1,0x7016,bits(p),&value)||!isfinite(fp(value))||fabsf(fp(value)-p)>.001f)return PATH_PREPARE_ERROR;
    w->report.target[a]=fp(value);w->report.active_mask|=1U<<a;w->report.stop_confirmed=0;
    if(cmd(w,a,3,0,0x50505431U,0))return PATH_IO_ERROR;
    *pout=p;return 0;
}
static int plan_yield(void *context){arm_workflow_t *w=context;workflow_tick(w,w->io->healthy(w->io->context));
    return w->report.state==WF_FAULT?(int)w->report.error:0;}
int workflow_pose_valid(const workflow_pose_record_t *r){
    if(!r||r->magic!=0x504f5331U||r->version!=1||!r->generation||r->captured_mask!=63||
       r->crc32!=workflow_crc32(r,offsetof(workflow_pose_record_t,crc32)))return 0;
    for(unsigned a=0;a<6;++a)if(r->zero_state[a]>1||!isfinite(r->position_rad[a])||fabsf(r->position_rad[a])>=15.9f||
        !isfinite(r->velocity_rad_s[a])||fabsf(r->velocity_rad_s[a])>.02f)return 0;
    return 1;
}
int workflow_capture_pose(arm_workflow_t *w,workflow_pose_record_t *out){
    if(!w||!out||w->report.active_mask||(w->report.state!=WF_OFF&&w->report.state!=WF_REFERENCE_SAVED))return WF_BAD_STATE;
    workflow_readback_t reads[6];int rc=workflow_read_parameters(w,reads);if(rc)return rc;
    workflow_pose_record_t r;memset(&r,0,sizeof(r));r.magic=0x504f5331U;r.version=1;
    r.generation=workflow_pose_valid(out)?out->generation+1:1;if(!r.generation)return WF_BAD_RECORD;r.captured_mask=63;
    for(unsigned a=0;a<6;++a){if(reads[a].run_mode>1)return PATH_PREPARE_ERROR;
        r.zero_state[a]=reads[a].zero_state;r.offset_bits[a]=reads[a].offset_bits;
        r.position_rad[a]=reads[a].position_rad;r.velocity_rad_s[a]=reads[a].velocity_rad_s;}
    r.crc32=workflow_crc32(&r,offsetof(workflow_pose_record_t,crc32));
    if(!workflow_pose_valid(&r))return PATH_NOT_STOPPED;
    *out=r;w->report.state=WF_REFERENCE_SAVED;w->report.error=0;return 0;
}
int workflow_restore_pose(arm_workflow_t *w,const workflow_pose_record_t *r){
    if(!w||!workflow_pose_valid(r))return WF_BAD_RECORD;
    if(w->report.active_mask||(w->report.state!=WF_OFF&&w->report.state!=WF_REFERENCE_SAVED))return WF_BAD_STATE;
    w->report.state=WF_REFERENCE_SAVED;w->report.error=0;return 0;
}
static int pose_matches(arm_workflow_t *w,const workflow_pose_record_t *r){
    for(unsigned a=0;a<6;++a){float p,v;uint32_t value;
        if(cmd(w,a,0,0x7029,0,&value)||value!=r->zero_state[a]||cmd(w,a,0,0x702b,0,&value)||value!=r->offset_bits[a]||
           readf(w,a,0x7019,&p)||readf(w,a,0x701b,&v))return PATH_IO_ERROR;
        if(fabsf(p-r->position_rad[a])>.001f||fabsf(v)>.02f)return PATH_START_MISMATCH;
    }return 0;
}
int workflow_hold_pose(arm_workflow_t *w,const workflow_pose_record_t *r){
    if(!w||!workflow_pose_valid(r))return WF_BAD_RECORD;
    if(w->report.state!=WF_REFERENCE_SAVED||w->report.active_mask)return WF_BAD_STATE;
    if(!w->io->healthy(w->io->context))return PATH_IO_ERROR;
    int rc=pose_matches(w,r);if(rc)return rc;
    /* Frozen-reference supervision, not an assumed mechanical travel range.
     * No model mapping/calibration flag is created. Full motion remains gated.
     * 0.1 speed/accel match original RA8P1 direct-control defaults and current
     * PL admission; they apply only to current-position PP preload/holding. */
    memset(&w->record,0,sizeof(w->record));path_config_t *c=&w->record.config;
    c->sample_ms=50;c->command_timeout_ms=50;c->arrival_timeout_ms=500;c->max_job_ms=55000;
    for(unsigned a=0;a<6;++a){path_axis_config_t *x=&c->axis[a];
        x->motor_id=a+1;x->expected_zero_state=r->zero_state[a];x->expected_offset_bits=r->offset_bits[a];
        x->gain=1;x->safe_min_rad=fmaxf(-15.899f,r->position_rad[a]-.02f);x->safe_max_rad=fminf(15.899f,r->position_rad[a]+.02f);
        x->speed_rad_s=.1f;x->accel_rad_s2=.1f;x->velocity_trip_rad_s=.1f;x->following_error_rad=.01f;
        x->arrival_position_rad=.001f;x->arrival_velocity_rad_s=.02f;}
    rc=stop(w,0,0);if(rc)return rc;
    rc=pose_matches(w,r);if(rc){w->report.state=WF_REFERENCE_SAVED;return rc;}
    uint32_t value;if(cmd(w,0,7,2,0x484c4431U,&value)||value)return stop(w,1,PATH_IO_ERROR);
    w->hold_sequence=0;w->report.state=WF_REFERENCE_HOLD;w->next_poll=now(w);
    for(unsigned a=0;a<6;++a){float p;int arrived;
        rc=prepare(w,a,&p);
        if(!rc&&fabsf(p-r->position_rad[a])>.001f)rc=PATH_START_MISMATCH;
        if(!rc)rc=observe(w,w->report.active_mask,&arrived);
        if(!rc)rc=renew(w);
        if(rc)return stop(w,1,rc);
    }
    /* Hold never sets record.config.calibration or a model initial pose. */
    return 0;
}
int workflow_command(arm_workflow_t *w,unsigned op,unsigned axis,float reference){
    if(!w||!w->io||!w->io->now_ms||!w->io->transaction||!w->io->healthy||!w->io->feedback_page||!w->io->emergency_stop)return PATH_BAD_CONFIG;
    if(op==WF_STOP)return stop(w,1,0);
    if(w->report.state==WF_FAULT)return WF_BAD_STATE;
    int rc=0,arrived;uint32_t value;
    if(op==WF_BEGIN||op==WF_RESUME){
        if(w->report.state!=WF_CONFIGURED||!config_valid(&w->record.config))return WF_BAD_STATE;
        if(op==WF_RESUME&&!workflow_record_valid(&w->record))return WF_BAD_RECORD;
        if(!w->io->healthy(w->io->context))return PATH_IO_ERROR;
        rc=stop(w,0,0);if(rc)return rc;
        if(cmd(w,0,7,2,0x484c4431U,&value)||value)return stop(w,1,PATH_IO_ERROR);
        w->hold_sequence=0;w->report.state=WF_CALIBRATING;w->next_poll=now(w);
        if(workflow_record_valid(&w->record)){
            /* Restore is passive. BEGIN is the separate explicit enable step,
             * and first checks all six saved positions before enabling any. */
            float current_joint[6];
            for(unsigned a=0;a<6;++a){float p,v;uint32_t z,o;const path_axis_config_t *c=&w->record.config.axis[a];
                if(readf(w,a,0x7019,&p)||readf(w,a,0x701b,&v)||cmd(w,a,0,0x7029,0,&z)||cmd(w,a,0,0x702b,0,&o)||
                   z!=c->expected_zero_state||o!=c->expected_offset_bits||p<c->safe_min_rad||p>c->safe_max_rad||
                   (op==WF_BEGIN&&fabsf(p-w->record.initial_motor_rad[a])>c->arrival_position_rad)||
                   fabsf(v)>c->arrival_velocity_rad_s){w->report.state=WF_CONFIGURED;return PATH_START_MISMATCH;}
                current_joint[a]=(p-c->motor_zero_rad)/c->gain;
            }
            if(op==WF_RESUME&&!workflow_joint_allowed(current_joint)){w->report.state=WF_CONFIGURED;return PATH_BAD_GEOMETRY;}
            for(unsigned a=0;a<6;++a){float p;rc=prepare(w,a,&p);
                if(!rc&&op==WF_BEGIN&&fabsf(p-w->record.initial_motor_rad[a])>w->record.config.axis[a].arrival_position_rad)rc=PATH_START_MISMATCH;
                if(!rc)rc=observe(w,w->report.active_mask,&arrived);
                if(!rc)rc=renew(w);
                if(rc)return stop(w,1,rc);}
            w->report.state=op==WF_RESUME?WF_CARTESIAN_HOLD:WF_INITIAL;
        }
        return 0;
    }
    if(op==WF_CAL_AXIS){
        if(w->report.state!=WF_CALIBRATING||axis<1||axis>6||(w->report.active_mask&(1U<<(axis-1))))return WF_BAD_AXIS;
        unsigned a=axis-1;if(!isfinite(reference)||reference<lo[a]||reference>hi[a])return PATH_BAD_CONFIG;
        float p;rc=prepare(w,a,&p);if(rc)return stop(w,1,rc);
        w->record.config.axis[a].motor_zero_rad=p-w->record.config.axis[a].gain*reference;
        w->record.reference_joint_rad[a]=reference;w->record.captured_motor_rad[a]=p;w->record.calibrated_mask|=1U<<a;
        w->record.initial_valid=0;if(w->record.calibrated_mask==63)w->record.config.calibration=PATH_CAL_CONFIRMED;
        seal(w);rc=observe(w,w->report.active_mask,&arrived);if(!rc)rc=renew(w);
        if(rc)return stop(w,1,rc);
        return 0;
    }
    if(op==WF_SAVE_INITIAL){
        if(w->report.state!=WF_CALIBRATING||w->record.calibrated_mask!=63||w->report.active_mask!=63)return WF_BAD_STATE;
        rc=observe(w,63,&arrived);if(rc)return stop(w,1,rc);if(!arrived)return PATH_NOT_STOPPED;
        for(unsigned a=0;a<6;++a){float q=(w->report.position[a]-w->record.config.axis[a].motor_zero_rad)/w->record.config.axis[a].gain;
            if(!isfinite(q)||q<lo[a]-1e-6f||q>hi[a]+1e-6f)return PATH_BAD_GEOMETRY;
            w->record.initial_joint_rad[a]=q;w->record.initial_motor_rad[a]=w->report.position[a];}
        w->record.initial_valid=1;seal(w);w->report.state=WF_INITIAL;return 0;
    }
    if(op==WF_PICK||op==WF_DELIVER||op==WF_RETURN){
        if(!workflow_record_valid(&w->record)||w->report.active_mask!=63||
          (op==WF_PICK?w->report.state!=WF_INITIAL:op==WF_DELIVER?w->report.state!=WF_AT_PICK:w->report.state!=WF_AT_DELIVERY))return WF_BAD_STATE;
        rc=observe(w,63,&arrived);if(rc)return stop(w,1,rc);if(!arrived)return PATH_NOT_STOPPED;
        /* Cooperative planning services the same frozen-target hold monitor
         * between samples. No unmonitored long IK/planning work while enabled. */
        float current[6];memcpy(current,w->report.position,sizeof(current));
        rc=workflow_plan_build(&w->record.config,w->geometry,op,current,w->record.initial_motor_rad,w->plan,plan_yield,w);
        if(rc)return rc;
        w->job_operation=op;
        for(unsigned a=0;a<6;++a)if(fabsf(w->report.position[a]-w->plan->frames[0].motor_rad[a])>w->record.config.axis[a].arrival_position_rad)return PATH_START_MISMATCH;
        if(cmd(w,0,7,4,0x54524a31U,&value)||value)return stop(w,1,PATH_IO_ERROR);
        w->path_sequence=0;w->frame=0;w->pause=0;w->waiting=0;w->epoch=now(w);w->report.frames_completed=0;w->report.frames_total=w->plan->count;
        start_timing(w,0);
        w->report.state=op==WF_PICK?WF_PICKING:op==WF_DELIVER?WF_DELIVERING:WF_RETURNING;return 0;
    }
    return WF_BAD_STATE;
}
int workflow_recover(arm_workflow_t *w,int (*transport_recover)(void *),void *context){
    if(!w||!transport_recover||w->report.state!=WF_FAULT)return WF_BAD_STATE;
    uint32_t before[6];
    for(unsigned a=0;a<6;++a)before[a]=w->io->feedback_page(w->io->context,a,1);
    if(!w->io->healthy(w->io->context))return PATH_IO_ERROR;
    if(transport_recover(context))return stop(w,1,PATH_IO_ERROR);
    int keep=workflow_record_valid(&w->record);
    /* Recovery sends only a new disable burst and read queries. Each axis
     * needs a new coherent stopped-mode status, plus fresh finite velocity.
     * No target/parameter write or enable is admitted here. */
    for(unsigned a=0;a<6;++a){
        float p,v;uint32_t z,o;
        if(!w->io->healthy(w->io->context)||readf(w,a,0x7019,&p)||readf(w,a,0x701b,&v)||
           cmd(w,a,0,0x7029,0,&z)||cmd(w,a,0,0x702b,0,&o))return stop(w,1,PATH_IO_ERROR);
        uint32_t n=w->io->feedback_page(w->io->context,a,1),s=w->io->feedback_page(w->io->context,a,0);
        uint32_t after=w->io->feedback_page(w->io->context,a,1);
        float limit=keep?w->record.config.axis[a].arrival_velocity_rad_s:.02f;
        if(n!=after||n==before[a]||!(s&0x20000U)||(s&255U)!=a+1||(s&0x10ff00U)||
           fabsf(p)>=15.9f||fabsf(v)>limit)return stop(w,1,PATH_NOT_STOPPED);
        w->report.position[a]=p;w->report.velocity[a]=v;
        if(keep&&(z!=w->record.config.axis[a].expected_zero_state||o!=w->record.config.axis[a].expected_offset_bits))keep=0;
    }
    if(!w->io->healthy(w->io->context))return stop(w,1,PATH_IO_ERROR);
    if(!keep)memset(&w->record,0,sizeof(w->record));
    w->report.state=keep?WF_CONFIGURED:WF_OFF;w->report.error=0;w->report.fault_cause=0;
    w->report.active_mask=0;w->report.stop_confirmed=1;
    w->report.calibrated_mask=keep?63:0;w->report.initial_valid=keep?1:0;
    w->report.frames_completed=0;w->report.frames_total=0;
    w->hold_sequence=0;w->path_sequence=0;w->frame=0;w->waiting=0;w->pause=0;
    if(w->plan){w->plan->count=0;w->plan->duration_ms=0;}
    memset(w->report.target,0,sizeof(w->report.target));
    memset(&w->stop_trace,0,sizeof(w->stop_trace)); /* Old trace was archived before RECOVER. */
    return 0;
}
static int calibrated_hold(const arm_workflow_t *w){
    return workflow_record_valid(&w->record)&&w->report.active_mask==63&&
       (w->report.state==WF_INITIAL||w->report.state==WF_PAUSED_HOLD||w->report.state==WF_AT_PICK||
        w->report.state==WF_AT_DELIVERY||w->report.state==WF_CARTESIAN_HOLD);
}
typedef struct {arm_workflow_t *w;uint32_t started;int error;} cartesian_service_t;
static int cartesian_service(void *context){
    cartesian_service_t *c=context;
    c->error=plan_yield(c->w);
    if(!c->error&&now(c->w)-c->started>10000)c->error=PATH_INFEASIBLE;
    return c->error;
}
static int cartesian_rates_allowed(const path_config_t *c){
    for(unsigned a=0;a<6;++a)if(c->axis[a].speed_rad_s>.500001f||c->axis[a].accel_rad_s2>.500001f)return 0;
    return 1;
}
static int start_cartesian_plan(arm_workflow_t *w,unsigned operation){
    int arrived,rc=observe(w,63,&arrived);if(rc)return stop(w,1,rc);
    if(!arrived)return PATH_NOT_STOPPED;
    for(unsigned a=0;a<6;++a)if(fabsf(w->report.position[a]-w->plan->frames[0].motor_rad[a])>
       fminf(w->record.config.axis[a].arrival_position_rad,
             fabsf(w->record.config.axis[a].gain)*w->record.config.start_joint_tolerance_rad))return PATH_START_MISMATCH;
    uint32_t value;if(cmd(w,0,7,4,0x54524a31U,&value)||value)return stop(w,1,PATH_IO_ERROR);
    w->job_operation=operation;w->path_sequence=0;w->frame=0;w->pause=0;w->waiting=0;
    w->epoch=now(w);w->report.frames_completed=0;w->report.frames_total=w->plan->count;
    start_timing(w,1);
    w->report.state=WF_MOVING_CARTESIAN;return 0;
}
int workflow_cartesian(arm_workflow_t *w,const arm_cartesian_pose_mm_deg_t *pose,
 workflow_cartesian_report_t *r,int execute){
    if(!w||!pose||!r)return PATH_BAD_CONFIG;
    memset(r,0,sizeof(*r));r->magic=0x43505231U;r->version=1;r->model_only=1;r->pose=*pose;
    const float home[6]={0,1.57f,0,0,1.57f,0};memcpy(r->seed_joint_rad,home,sizeof(home));
    int live=calibrated_hold(w),rc=0,arrived;
    if(w->report.state==WF_FAULT||(!live&&w->report.active_mask)||(execute&&!live))return r->error=WF_BAD_STATE;
    if(live){
        if(!cartesian_rates_allowed(&w->record.config))return r->error=PATH_BAD_CONFIG;
        rc=observe(w,63,&arrived);if(rc)return r->error=stop(w,1,rc);
        if(!arrived)return r->error=PATH_NOT_STOPPED;
        r->model_only=0;
        for(unsigned a=0;a<6;++a)r->seed_joint_rad[a]=(w->report.position[a]-w->record.config.axis[a].motor_zero_rad)/w->record.config.axis[a].gain;
    }
    for(unsigned a=0;a<3;++a)if(!isfinite(pose->xyz_mm[a])||!isfinite(pose->rpy_deg[a])||
        fabsf(pose->xyz_mm[a])>1000000.f||fabsf(pose->rpy_deg[a])>360.f)return r->error=PATH_BAD_GEOMETRY;
    float current[6];memcpy(current,w->report.position,sizeof(current));
    cartesian_service_t service={w,live?now(w):0,0};
    arm_kinematics_set_service(live?cartesian_service:0,live?&service:0);
    const float physical_min[6]={-1.7453293f,-.0007964f,-2.0943951f,-2.0943951f,-.1753293f,-3.14f};
    const float physical_max[6]={1.7453293f,3.1407964f,0,2.0943951f,1.57f,3.14f};
    urdf_pose_t desired;urdf_ik_result_t analytic;arm_ik_solution_t solution={0};unsigned solutions=0;
    int solved=arm_kinematics_pose_from_rpy_mm_deg(pose,&desired)&&
        pieper_kinematics_inverse(&desired,r->seed_joint_rad,physical_min,physical_max,&analytic,&solutions);
    r->solutions=solutions;
    if(solved){r->solver=1;memcpy(solution.joint_rad,analytic.joint_rad,sizeof(solution.joint_rad));
        solution.position_error_mm=analytic.position_error_m*1000;solution.orientation_error_rad=analytic.orientation_error_rad;
    }else if(!service.error){r->solver=2;solved=arm_kinematics_solve_rpy_mm_deg(pose,r->seed_joint_rad,&solution);}
    arm_kinematics_set_service(0,0);
    if(service.error)return r->error=service.error;
    if(!solved||!workflow_joint_allowed(solution.joint_rad))return r->error=PATH_BAD_GEOMETRY;
    memcpy(r->target_joint_rad,solution.joint_rad,sizeof(r->target_joint_rad));
    r->position_error_mm=solution.position_error_mm;r->orientation_error_rad=solution.orientation_error_rad;
    if(!live)return 0; /* Model-only preview never accesses the motor interface. */
    if(solution.position_error_mm>w->record.config.max_cartesian_error_mm)return r->error=PATH_BAD_GEOMETRY;
    rc=workflow_joint_plan_build(&w->record.config,current,solution.joint_rad,w->plan,cartesian_service,&service);
    if(rc)return r->error=rc;
    r->plan_valid=1;r->frames=w->plan->count;r->duration_ms=w->plan->duration_ms;
    memcpy(r->target_motor_rad,w->plan->frames[w->plan->count-1].motor_rad,sizeof(r->target_motor_rad));
    if(execute){rc=start_cartesian_plan(w,WF_MOVETO);if(rc)r->plan_valid=0;}
    r->error=(unsigned)rc;return rc;
}
int workflow_go_home(arm_workflow_t *w){
    if(!w||!calibrated_hold(w))return WF_BAD_STATE;
    if(!cartesian_rates_allowed(&w->record.config))return PATH_BAD_CONFIG;
    int arrived,rc=observe(w,63,&arrived);if(rc)return stop(w,1,rc);
    if(!arrived)return PATH_NOT_STOPPED;
    float current[6];memcpy(current,w->report.position,sizeof(current));
    cartesian_service_t service={w,now(w),0};
    rc=workflow_joint_plan_build(&w->record.config,current,w->record.initial_joint_rad,w->plan,cartesian_service,&service);
    if(rc)return rc;
    return start_cartesian_plan(w,WF_GOHOME);
}
static void pause_late_trajectory(arm_workflow_t *w){
    /* No target replacement, disable, re-enable, or motor parameter write.
     * The drive's existing PP profile settles at the last verified target.
     * Fresh feedback must pass all trajectory guards before PL enters HOLD;
     * uncertainty or transport failure still invokes the existing stop path. */
    if(w->report.active_mask!=63||!workflow_record_valid(&w->record)){
        stop(w,1,WF_BAD_RECORD);return;
    }
    int arrived,rc=observe(w,63,&arrived);
    if(rc){stop(w,1,rc);return;}
    uint32_t value;
    if(cmd(w,0,7,2,0x484c4431U,&value)||value){stop(w,1,PATH_IO_ERROR);return;}
    w->hold_sequence=0;w->waiting=0;w->arrival_streak=0;
    w->report.state=WF_PAUSED_HOLD;w->next_poll=now(w);
    /* Keep interrupted frame/timing evidence. PAUSED_HOLD is deliberately
     * excluded from drag_tolerant_hold, retaining range/speed/tracking guards.
     * New MOVETO/GOHOME needs an explicit command and settled fresh feedback. */
    rc=renew(w);if(rc)stop(w,1,rc);
}
void workflow_tick(arm_workflow_t *w,int host_alive){
    if(!w||!w->report.active_mask||w->report.state==WF_FAULT)return;
    if(!host_alive){stop(w,1,WF_HOST_LOST);return;}
    if(!w->io->healthy(w->io->context)){stop(w,1,PATH_IO_ERROR);return;}
    int rc=0,arrived;uint32_t time=now(w);
    if(w->report.state!=WF_PICKING&&w->report.state!=WF_DELIVERING&&w->report.state!=WF_RETURNING&&w->report.state!=WF_MOVING_CARTESIAN){
        if((int32_t)(time-w->next_poll)<0)return;
        rc=observe(w,w->report.active_mask,&arrived);if(!rc)rc=renew(w);w->next_poll=now(w)+50;
    }else{
        w->timing.elapsed_ms=time-w->epoch;w->timing.frame_index=w->frame;
        if(time-w->epoch>w->record.config.max_job_ms){w->timing.fault_kind=WF_TIME_JOB_LIMIT;stop(w,1,PATH_FRAME_LATE);return;}
        if(w->waiting){
            if(time-w->wait_start>=w->record.config.arrival_timeout_ms){stop(w,1,PATH_ARRIVAL_ERROR);return;}
            if((int32_t)(time-w->wait_next)<0)return;
            rc=observe(w,63,&arrived);if(!rc){w->arrival_streak=arrived?w->arrival_streak+1:0;
                if(w->arrival_streak>=3){w->waiting=0;w->pause+=now(w)-w->wait_start;
                    if(w->frame==w->plan->count){uint32_t value;
                        if(cmd(w,0,7,2,0x484c4431U,&value)||value)rc=PATH_IO_ERROR;
                        else{w->hold_sequence=0;w->next_poll=now(w);w->report.state=w->job_operation==WF_PICK?WF_AT_PICK:w->job_operation==WF_DELIVER?WF_AT_DELIVERY:w->job_operation==WF_MOVETO?WF_CARTESIAN_HOLD:WF_INITIAL;}}
                }else{rc=publish(w,w->report.target);w->wait_next=now(w)+w->record.config.sample_ms;}}
        }else{
            const path_frame_t *f=&w->plan->frames[w->frame];
            uint32_t due=w->report.state==WF_MOVING_CARTESIAN?w->next_frame_due:w->epoch+f->time_ms+w->pause;
            w->timing.due_elapsed_ms=due-w->epoch;
            w->timing.lateness_ms=(int32_t)(time-due)>0?time-due:0;
            if((int32_t)(time-due)<0)return;
            if(time-due>WF_DISPATCH_LATE_LIMIT_MS){w->timing.fault_kind=WF_TIME_FRAME_LATE;pause_late_trajectory(w);return;}
            uint32_t started=now(w);
            rc=observe(w,63,&arrived);
            uint32_t observed=now(w);w->timing.observe_ms=observed-started;
            if(!rc)rc=publish(w,f->motor_rad);
            uint32_t completed=now(w);w->timing.publish_ms=completed-observed;
            w->timing.last_service_ms=completed-started;
            if(w->timing.last_service_ms>w->timing.max_service_ms)w->timing.max_service_ms=w->timing.last_service_ms;
            if(!rc){++w->frame;w->report.frames_completed=w->frame;
                /* Cartesian samples advance only after the preceding group
                 * has been verified, then wait a full sample interval. Never
                 * burst/skip samples to catch up with an old wall-clock grid.
                 * Keep transaction, wakeup lateness, PL lease and job guards. */
                w->next_frame_due=completed+w->record.config.sample_ms;
                w->timing.completed_at_ms=completed-w->epoch;
                w->timing.next_due_elapsed_ms=w->next_frame_due-w->epoch;
                if(f->last_in_stage||w->frame==w->plan->count){w->waiting=1;w->arrival_streak=0;w->wait_start=now(w);w->wait_next=w->wait_start;}}
        }
    }
    if(rc)stop(w,1,rc);
}
