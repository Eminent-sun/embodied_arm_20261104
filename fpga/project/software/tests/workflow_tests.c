/* Synthetic transport only. Nothing in this fixture is real calibration. */
#define main legacy_path_tests_not_called
#include "path_executor_tests.c"
#undef main
#include "arm_workflow.h"
typedef struct {mock_t m;unsigned hold,lease;} fixture_t;
static arm_workflow_t workflow;
static int wf_tx(void *context,uint32_t word,uint32_t value,uint32_t *out){
    fixture_t *f=context;mock_t *m=&f->m;unsigned a=(word&255)-1,op=(word>>8)&7,index=word>>11;uint32_t result=0;
    if(op==0||op==4)return transaction(&f->m,word,value,out);
    if(a>=6)return -1;
    ++m->ms;++m->commands;++m->writes;
    if(op==7&&index==2&&value==0x484c4431U){f->hold=1;f->lease=0;m->staged=0;}
    else if(op==7&&index==3){if(!f->hold||value!=f->lease+1)return -1;f->lease=value;result=value;}
    else if(op==7&&index==4&&value==0x54524a31U){if(!f->hold||m->enabled!=63)return -1;f->hold=0;m->seq=0;m->staged=0;}
    else if(op==2&&index==0x7005&&value==1){if(m->enabled&(1U<<a))return -1;m->mode[a]=1;result=1;}
    else if(op==1){if(m->enabled&(1U<<a))return -1;
        if(index==0x7024)m->speed[a]=value;else if(index==0x7025)m->accel[a]=value;
        else if(index==0x7016){if(fabsf(fp(value)-m->pos[a])>.001f)return -1;m->preload[a]=1;m->target[a]=fp(value);}
        else return -1;
        result=value;
    }else if(op==3){if(!f->hold||!m->preload[a]||!m->mode[a]||!m->speed[a]||!m->accel[a])return -1;
        m->enabled|=1U<<a;++m->enables;++m->count[a];m->ever_enabled=1;
    }else if(op==5&&index==0x7016){if(f->hold||m->staged&(1U<<a)||fabsf(fp(value)-m->target[a])>.1001f)return -1;
        m->target[a]=fp(value);m->staged|=1U<<a;
    }else if(op==7&&index==1){if(f->hold||value!=m->seq+1||m->staged!=63||m->enabled!=63)return -1;
        m->seq=value;m->staged=0;for(unsigned i=0;i<6;++i){m->pos[i]=m->target[i];++m->count[i];}result=value;
    }else return -1;
    if(out)*out=result;
    return 0;
}
#define CHECK(c) do{if(!(c)){printf("FAIL workflow line %d state=%u error=%u\n",__LINE__,workflow.report.state,workflow.report.error);return 1;}++checks;}while(0)
static int run_motion(fixture_t *f,unsigned desired){
    for(unsigned i=0;i<120000&&workflow.report.state!=desired&&workflow.report.state!=WF_FAULT;++i){++f->m.ms;workflow_tick(&workflow,1);}
    return workflow.report.state==desired;
}
#ifndef CARTESIAN_TESTS_ONLY
int main(void){
    unsigned checks=0;fixture_t f={0};pick_candidate_preview(&geometry);CHECK(geometry.math_passed);
    const float reference[6]={0,1.57f,0,0,1.57f,0};
    path_config_t c=config();c.calibration=0;
    for(unsigned a=0;a<6;++a){f.m.pos[a]=reference[a]+.2f;f.m.target[a]=f.m.pos[a];f.m.count[a]=1;}
    path_io_t io={&f,now,healthy,wf_tx,page,stop};workflow_init(&workflow,&io,&geometry,&plan,0);
    CHECK(workflow_configure(&workflow,&c)==0&&f.m.commands==0);
    CHECK(workflow_command(&workflow,WF_PICK,0,0)==WF_BAD_STATE&&f.m.enables==0);
    CHECK(workflow_command(&workflow,WF_BEGIN,0,0)==0&&f.m.enables==0);
    CHECK(workflow_command(&workflow,WF_CAL_AXIS,2,0)==PATH_BAD_CONFIG&&f.m.enables==0);
    for(unsigned a=0;a<6;++a){float before=f.m.pos[a];CHECK(workflow_command(&workflow,WF_CAL_AXIS,a+1,reference[a])==0);
        CHECK(f.m.enabled==(1U<<(a+1))-1&&f.m.pos[a]==before);
        CHECK(fabsf(workflow.record.config.axis[a].motor_zero_rad-.2f)<1e-6f);
        CHECK(workflow.record.calibrated_mask==(1U<<(a+1))-1);
        if(a<5)CHECK(workflow_command(&workflow,WF_SAVE_INITIAL,0,0)==WF_BAD_STATE);
        for(unsigned k=0;k<50;++k){f.m.ms+=20;workflow_tick(&workflow,1);}CHECK(workflow.report.state==WF_CALIBRATING);
    }
    CHECK(workflow_command(&workflow,WF_SAVE_INITIAL,0,0)==0&&workflow.report.state==WF_INITIAL);
    CHECK(workflow_record_valid(&workflow.record));workflow_record_t saved=workflow.record;
    CHECK(workflow_command(&workflow,WF_DELIVER,0,0)==WF_BAD_STATE&&f.m.enabled==63);
    CHECK(workflow_command(&workflow,WF_PICK,0,0)==0);printf("PICK frames=%u ms=%u\n",plan.count,plan.duration_ms);
    CHECK(run_motion(&f,WF_AT_PICK)&&f.m.enabled==63&&f.hold);
    for(unsigned a=0;a<6;++a)CHECK(fabsf(f.m.pos[a]-plan.frames[plan.count-1].motor_rad[a])<1e-6f);
    CHECK(workflow_command(&workflow,WF_DELIVER,0,0)==0);printf("DELIVER frames=%u ms=%u\n",plan.count,plan.duration_ms);
    CHECK(run_motion(&f,WF_AT_DELIVERY)&&f.m.enabled==63&&f.hold);
    CHECK(workflow_command(&workflow,WF_RETURN,0,0)==0);printf("RETURN frames=%u ms=%u\n",plan.count,plan.duration_ms);
    CHECK(run_motion(&f,WF_INITIAL)&&f.m.enabled==63);
    for(unsigned a=0;a<6;++a)CHECK(fabsf(f.m.pos[a]-saved.initial_motor_rad[a])<1e-6f);
    unsigned before=f.m.commands,stops_before=f.m.stops;workflow_tick(&workflow,0);
    CHECK(workflow.report.state==WF_FAULT&&workflow.report.error==WF_HOST_LOST&&f.m.enabled==0&&
          f.m.stops==stops_before+1&&f.m.commands==before&&workflow.report.stop_confirmed);
    CHECK(workflow_command(&workflow,WF_PICK,0,0)==WF_BAD_STATE);
    workflow_init(&workflow,&io,&geometry,&plan,0);before=f.m.commands;CHECK(workflow_restore(&workflow,&saved)==0&&f.m.commands==before);
    saved.initial_motor_rad[0]+=.1f;CHECK(workflow_restore(&workflow,&saved)==WF_BAD_RECORD);saved=workflow.record;
    CHECK(workflow_command(&workflow,WF_BEGIN,0,0)==0&&workflow.report.state==WF_INITIAL&&f.m.enabled==63);
    workflow_tick(&workflow,0);workflow_init(&workflow,&io,&geometry,&plan,0);CHECK(workflow_restore(&workflow,&saved)==0);
    f.m.pos[1]+=.2f;before=f.m.enables;CHECK(workflow_command(&workflow,WF_BEGIN,0,0)==PATH_START_MISMATCH&&f.m.enables==before);
    printf("PASS WORKFLOW %u CHECKS (synthetic ideal tracking only)\n",checks);return 0;
}
#endif
