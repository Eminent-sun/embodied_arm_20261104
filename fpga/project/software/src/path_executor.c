#include "path_executor.h"
#include <math.h>
#include <string.h>
static uint32_t bits(float x){union{float f;uint32_t u;}v={.f=x};return v.u;}
static float fp(uint32_t x){union{float f;uint32_t u;}v={.u=x};return v.f;}
typedef struct {const path_config_t *c;const path_io_t *io;path_execution_report_t *r;uint32_t active_start,seq;int active;} runner_t;
static uint32_t now(runner_t *x){return x->io->now_ms(x->io->context);}
static int command(runner_t *x,unsigned id,unsigned op,unsigned index,uint32_t value,uint32_t *out){
    ++x->r->commands;return x->io->transaction(x->io->context,(index<<11)|(op<<8)|id,value,out)?PATH_IO_ERROR:0;
}
static int read_float(runner_t *x,unsigned axis,unsigned index,float *out){
    uint32_t v;if(command(x,axis+1,0,index,0,&v))return PATH_IO_ERROR;*out=fp(v);return isfinite(*out)?0:PATH_IO_ERROR;
}
static int alive(runner_t *x){return x->io->healthy(x->io->context)&&(!x->active||now(x)-x->active_start<x->c->max_job_ms);}
static void snapshot(runner_t *x,uint32_t count[6]){for(unsigned a=0;a<6;++a)count[a]=x->io->feedback_page(x->io->context,a,1);}
static int disabled(runner_t *x,const uint32_t before[6]){
    uint32_t started=now(x);
    for(;;){unsigned mask=0;
        for(unsigned a=0;a<6;++a){uint32_t n=x->io->feedback_page(x->io->context,a,1),s=x->io->feedback_page(x->io->context,a,0);
            if(n!=before[a]&&(s&0x20000U)&&(s&255U)==a+1&&!(s&0xfc00U)&&((s>>8)&3U)==0)mask|=1U<<a;}
        if(mask==63)return 0;
        if(now(x)-started>=300)return PATH_STOP_UNKNOWN;
    }
}
static int observe(runner_t *x,const float target[6],int running,int *arrived){
    *arrived=1;
    for(unsigned a=0;a<6;++a){float p,v;x->r->axis=a+1;
        if(read_float(x,a,0x7019,&p)||read_float(x,a,0x701b,&v))return PATH_IO_ERROR;
        const path_axis_config_t *c=&x->c->axis[a];x->r->final_motor_rad[a]=p;x->r->final_velocity_rad_s[a]=v;
        if(p<c->safe_min_rad||p>c->safe_max_rad||fabsf(v)>c->velocity_trip_rad_s)return PATH_TRACK_ERROR;
        if(running&&fabsf(p-target[a])>c->following_error_rad)return PATH_TRACK_ERROR;
        if(fabsf(p-target[a])>c->arrival_position_rad||fabsf(v)>c->arrival_velocity_rad_s)*arrived=0;
        uint32_t s=x->io->feedback_page(x->io->context,a,0);
        if(!(s&0x20000U)||(s&255U)!=a+1||(s&0xfc00U)||(running&&((s>>8)&3U)!=2))return PATH_TRACK_ERROR;
    }
    x->r->axis=0;return alive(x)?0:PATH_IO_ERROR;
}
static int publish(runner_t *x,const float target[6],int staged){
    for(unsigned a=0;a<6&&!staged;++a)if(command(x,a+1,5,0x7016,bits(target[a]),0))return PATH_IO_ERROR;
    if(x->seq==0xffffffffU)return PATH_IO_ERROR;
    uint32_t value;if(command(x,1,7,1,x->seq+1,&value)||value!=x->seq+1)return PATH_IO_ERROR;
    ++x->seq;x->r->last_sequence=x->seq;return 0;
}
static int arrive(runner_t *x,const float target[6]){
    uint32_t start=now(x),next=start;unsigned streak=0;
    while(now(x)-start<x->c->arrival_timeout_ms){
        if(!alive(x))return PATH_IO_ERROR;
        if((int32_t)(now(x)-next)<0)continue;
        int arrived,rc=observe(x,target,1,&arrived);if(rc)return rc;
        streak=arrived?streak+1:0;if(streak==3)return 0;
        rc=publish(x,target,0);if(rc)return rc;next=now(x)+x->c->sample_ms;
    }
    return PATH_ARRIVAL_ERROR;
}
static int stop_normal(runner_t *x){
    uint32_t count[6];snapshot(x,count);x->r->stop_confirmed=0;
    if(command(x,1,4,0,0,0)||disabled(x,count))return PATH_STOP_UNKNOWN;
    x->active=0;
    uint32_t start=now(x),next=start;unsigned streak=0;
    while(now(x)-start<600){
        if((int32_t)(now(x)-next)<0)continue;
        int stable=1;
        for(unsigned a=0;a<6;++a){float p,v;if(read_float(x,a,0x7019,&p)||read_float(x,a,0x701b,&v))return PATH_STOP_UNKNOWN;
            x->r->final_motor_rad[a]=p;x->r->final_velocity_rad_s[a]=v;
            if(p<x->c->axis[a].safe_min_rad||p>x->c->axis[a].safe_max_rad||fabsf(v)>x->c->axis[a].arrival_velocity_rad_s)stable=0;}
        streak=stable?streak+1:0;if(streak==3){x->r->stop_confirmed=1;return 0;}next=now(x)+x->c->sample_ms;
    }
    return PATH_STOP_UNKNOWN;
}
static void emergency(runner_t *x){
    uint32_t count[6];snapshot(x,count);x->r->stop_confirmed=0;x->io->emergency_stop(x->io->context);
    if(!disabled(x,count)){
        int stable=1;for(unsigned a=0;a<6;++a){float v;if(read_float(x,a,0x701b,&v)||fabsf(v)>x->c->axis[a].arrival_velocity_rad_s)stable=0;}
        x->r->stop_confirmed=stable?1U:0U;
    }
}
int path_execute_once(const path_config_t *c,const pick_candidate_report_t *geometry,path_plan_t *plan,
                      const path_io_t *io,path_execution_report_t *r){
    if(!r)return PATH_BAD_CONFIG;
    memset(r,0,sizeof(*r));r->magic=0x50544831U;r->version=1;r->phase=1;
    int rc=PATH_BAD_CONFIG;
    if(!path_config_valid(c)||!plan||!io||!io->now_ms||!io->healthy||!io->transaction||!io->feedback_page||!io->emergency_stop)goto early;
    runner_t x={c,io,r,0,0,0};uint32_t started=now(&x),v;
    if(!alive(&x)){rc=PATH_IO_ERROR;goto done;}
    /* Only reads until mechanical bounds, initial configuration and complete
     * time schedule have passed. No default signs/offsets are substituted. */
    for(unsigned a=0;a<6;++a){float velocity,positive;r->axis=a+1;
        if(command(&x,a+1,0,0x7005,0,&v)||v>1||read_float(&x,a,0x7019,&r->initial_motor_rad[a])||
           read_float(&x,a,0x701b,&velocity)||fabsf(velocity)>c->axis[a].arrival_velocity_rad_s||
           command(&x,a+1,0,0x7029,0,&v)||v!=c->axis[a].expected_zero_state||
           command(&x,a+1,0,0x702b,0,&v)||v!=c->axis[a].expected_offset_bits||
           read_float(&x,a,0x7018,&positive)||positive<=0||read_float(&x,a,0x700b,&positive)||positive<=0){rc=PATH_BAD_CONFIG;goto done;}
    }
    r->axis=0;r->phase=10;rc=path_plan_compile(c,geometry,r->initial_motor_rad,plan);if(rc)goto done;
    r->phase=20;
    /* Stop policy is an explicitly verified configuration requirement. */
    rc=stop_normal(&x);if(rc)goto done;
    if(command(&x,1,7,0,0x54524a31U,&v)||v!=0){rc=PATH_PREPARE_ERROR;goto done;}
    for(unsigned a=0;a<6;++a){float current;r->axis=a+1;
        if(command(&x,a+1,2,0x7005,1,&v)||v!=1||
           command(&x,a+1,1,0x7024,bits(c->axis[a].speed_rad_s),&v)||v!=bits(c->axis[a].speed_rad_s)||
           command(&x,a+1,1,0x7025,bits(c->axis[a].accel_rad_s2),&v)||v!=bits(c->axis[a].accel_rad_s2)||
           read_float(&x,a,0x7019,&current)||fabsf(current-r->initial_motor_rad[a])>c->axis[a].arrival_position_rad||
           command(&x,a+1,1,0x7016,bits(current),&v)||!isfinite(fp(v))||fabsf(fp(v)-current)>.001f||
           command(&x,a+1,5,0x7016,bits(plan->frames[0].motor_rad[a]),0)){rc=PATH_PREPARE_ERROR;goto done;}
    }
    r->axis=0;r->phase=30;x.active=1;x.active_start=now(&x);r->stop_confirmed=0;
    for(unsigned a=0;a<6;++a){r->enabled_mask|=1U<<a;if(command(&x,a+1,3,0,0x50505431U,0)){rc=PATH_IO_ERROR;goto active_done;}}
    uint32_t epoch=now(&x),pause=0;
    for(unsigned f=0;f<plan->count;++f){
        const path_frame_t *frame=&plan->frames[f];uint32_t due=epoch+frame->time_ms+pause;
        while((int32_t)(now(&x)-due)<0){if(!alive(&x)){rc=PATH_IO_ERROR;goto active_done;}}
        if(now(&x)-due>c->command_timeout_ms){rc=PATH_FRAME_LATE;goto active_done;}
        int arrived;rc=observe(&x,f?plan->frames[f-1].motor_rad:frame->motor_rad,1,&arrived);if(rc)goto active_done;
        rc=publish(&x,frame->motor_rad,f==0);if(rc)goto active_done;
        r->frames_completed=f+1;
        if(frame->last_in_stage){uint32_t before=now(&x);rc=arrive(&x,frame->motor_rad);if(rc)goto active_done;pause+=now(&x)-before;}
    }
    rc=stop_normal(&x);
active_done:
    if(rc&&x.active)emergency(&x);
done:
    r->elapsed_ms=now(&x)-started;
early:
    r->error=rc;r->phase=rc?((rc==PATH_STOP_UNKNOWN || (r->enabled_mask&&!r->stop_confirmed))?0xe2U:0xe0U):100U;
    return rc;
}
