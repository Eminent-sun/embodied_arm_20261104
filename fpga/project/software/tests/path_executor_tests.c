/* Ideal tracking transport fixture; all calibration/rate values here are
 * synthetic and never compiled into the production request/configuration. */
#include "path_executor.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
typedef struct {
    uint32_t ms,polls,seq,staged,enabled,count[6],commands,enables,stops,scenario,ever_enabled,writes;
    float pos[6],target[6],actual_velocity[6];uint32_t mode[6],speed[6],accel[6],preload[6];
} mock_t;
static pick_candidate_report_t geometry;
static path_plan_t plan;
static path_execution_report_t report;
static uint32_t bits(float f){union{float f;uint32_t u;}v={.f=f};return v.u;}
static float fp(uint32_t u){union{float f;uint32_t u;}v={.u=u};return v.f;}
static uint32_t now(void *v){mock_t *m=v;if(++m->polls%16==0)++m->ms;return m->ms;}
static int healthy(void *v){(void)v;return 1;}
static uint32_t page(void *v,unsigned a,unsigned p){mock_t *m=v;
    if(p==1)return m->count[a];
    if(p==5)return 0x80000000U; /* synthetic zero velocity status payload */
    return (a+1)|0x20000U|((m->enabled&(1U<<a))?0x200U:0)|((m->scenario==10&&m->seq>=3)?0x400U:0);}
static void stop(void *v){mock_t *m=v;m->enabled=0;m->staged=0;++m->stops;for(unsigned a=0;a<6;++a)if(!(m->scenario==4&&m->ever_enabled))++m->count[a];}
static int transaction(void *v,uint32_t w,uint32_t value,uint32_t *out){
    mock_t *m=v;unsigned a=(w&255)-1,op=(w>>8)&7,index=(w>>11)&65535;uint32_t result=0;
    ++m->commands;++m->ms;if(a>=6)return -1;
    if(op==0){
        switch(index){case 0x7005:result=m->mode[a];break;case 0x7019:result=bits(m->pos[a]);break;
            case 0x701b:result=bits(m->actual_velocity[a]);break;case 0x7029:result=1;break;case 0x702b:result=0;break;
            case 0x7018:result=bits(10);break;case 0x700b:result=bits(6);break;default:return -1;}
    }else if(op==4){stop(m);}
    else if(op==7&&index==0&&value==0x54524a31U){if(m->enabled)return -1;m->seq=0;m->staged=0;memset(m->preload,0,sizeof(m->preload));}
    else if(op==2&&index==0x7005&&value==1){if(m->enabled)return -1;m->mode[a]=1;result=1;}
    else if(op==1){
        if(m->enabled)return -1;
        if(index==0x7024)m->speed[a]=value;
        else if(index==0x7025)m->accel[a]=value;
        else if(index==0x7016){if(fabsf(fp(value)-m->pos[a])>.001f)return -1;m->preload[a]=1;m->target[a]=fp(value);}
        else return -1;
        result=(m->scenario==8&&index==0x7024)?value^1U:value;
    }else if(op==3&&value==0x50505431U){
        if(!m->mode[a]||!m->speed[a]||!m->accel[a]||!m->preload[a])return -1;
        m->enabled|=1U<<a;m->ever_enabled=1;++m->enables;++m->count[a];
    }else if(op==5&&index==0x7016){
        if((m->staged&(1U<<a))||fabsf(fp(value)-m->target[a])>.1001f)return -1;
        m->target[a]=fp(value);m->staged|=1U<<a;
    }else if(op==7&&index==1){
        if(value!=m->seq+1||m->staged!=63||m->enabled!=63)return -1;
        m->seq=value;m->staged=0;for(unsigned i=0;i<6;++i){m->pos[i]=m->target[i];++m->count[i];}
        result=value;
        if(m->scenario==1&&value==3)result=value+1;
        if(m->scenario==2&&value==3)m->pos[0]+=.2f;
        if(m->scenario==3&&value==3)m->ms+=100;
        if(m->scenario==9&&value==3)m->actual_velocity[0]=2;
    }else return -1;
    if(op!=0)++m->writes;
    if(out)*out=result;
    return 0;
}
static path_config_t config(void){
    path_config_t c={0};c.calibration=PATH_CAL_CONFIRMED;c.stop_policy=PATH_STOP_POLICY_CONFIRMED;
    c.sample_ms=50;c.command_timeout_ms=50;c.arrival_timeout_ms=500;c.max_job_ms=55000;
    c.start_joint_tolerance_rad=.001f;c.max_cartesian_error_mm=.5f;
    for(unsigned a=0;a<6;++a)c.axis[a]=(path_axis_config_t){a+1,1,0,1,0,-6,6,1,2,1.2f,.099f,.01f,.02f};
    return c;
}
int main(void){
    pick_candidate_preview(&geometry);if(!geometry.math_passed)return 1;
    path_config_t c=config();float initial[6];memcpy(initial,geometry.samples[0].joint_rad,sizeof(initial));
    int rc=path_plan_compile(&c,&geometry,initial,&plan);
    printf("PLAN rc=%d frames=%u duration_ms=%u\n",rc,plan.count,plan.duration_ms);if(rc)return 1;
    unsigned passed=0;
    for(unsigned scenario=0;scenario<11;++scenario){mock_t m={0};m.scenario=scenario;
        for(unsigned a=0;a<6;++a){m.pos[a]=initial[a];m.target[a]=initial[a];m.count[a]=1;}
        path_io_t io={&m,now,healthy,transaction,page,stop};path_config_t current=c;
        if(scenario==5)current.calibration=0;
        if(scenario==6)m.pos[0]+=.1f;
        if(scenario==7)current.axis[3].motor_id=9;
        rc=path_execute_once(&current,&geometry,&plan,&io,&report);
        int ok=scenario==0?(rc==0&&report.stop_confirmed&&report.frames_completed==plan.count&&m.enables==6):
            scenario==1?(rc==PATH_IO_ERROR&&m.stops>=2):scenario==2?(rc==PATH_TRACK_ERROR&&m.stops>=2):
            scenario==3?(rc==PATH_FRAME_LATE&&m.stops>=2):scenario==4?(rc==PATH_STOP_UNKNOWN&&!report.stop_confirmed):
            scenario==5?(rc==PATH_BAD_CONFIG&&m.commands==0&&m.enables==0):
            scenario==6?(rc==PATH_START_MISMATCH&&m.writes==0&&m.enables==0):
            scenario==7?(rc==PATH_BAD_CONFIG&&m.commands==0):
            scenario==8?(rc==PATH_PREPARE_ERROR&&m.enables==0):
            (rc==PATH_TRACK_ERROR&&m.stops>=2);
        printf("SCENARIO %u rc=%d phase=%u frames=%u commands=%u stop=%u %s\n",scenario,rc,report.phase,report.frames_completed,m.commands,report.stop_confirmed,ok?"PASS":"FAIL");
        if(!ok)return 1;
        ++passed;
    }
    printf("PASS PATH_EXECUTOR %u CASES (synthetic ideal tracking model only)\n",passed);return 0;
}
