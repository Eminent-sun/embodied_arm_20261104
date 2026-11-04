#include "fixed_workflow.h"
#include <string.h>
void fixed_workflow_init(fixed_workflow_t *f) {if(f) memset(f,0,sizeof(*f));}
bool fixed_workflow_start(fixed_workflow_t *f,const fixed_path_report_t *p,uint32_t timeout) {
    if(!f || f->state!=WF_IDLE || !fixed_path_can_start(p) || !timeout || timeout>=0x80000000U) return false;
    for(unsigned i=0;i<FIXED_PATH_STAGE_COUNT;++i) if(timeout<p->stages[i].waypoint.original_gate_ms) return false;
    f->plan=p;f->index=0;f->error=WF_ERR_NONE;f->fallback_motion_timeout_ms=timeout;f->state=WF_COMMAND_READY;
    return true;
}
const fixed_path_stage_result_t *fixed_workflow_next_action(const fixed_workflow_t *f) {
    if(!f || !f->plan || f->state!=WF_COMMAND_READY || f->index>=FIXED_PATH_STAGE_COUNT) return NULL;
    return &f->plan->stages[f->index];
}
static void fail(fixed_workflow_t *f,unsigned error) {f->error=error;f->state=WF_STOP_REQUIRED;}
void fixed_workflow_command_result(fixed_workflow_t *f,bool accepted,uint32_t now) {
    if(!f || f->state!=WF_COMMAND_READY) return;
    if(!accepted) {fail(f,WF_ERR_SUBMIT);return;}
    f->started_ms=now;f->state=WF_MOVING;
}
static void advance(fixed_workflow_t *f) {
    ++f->index;f->state=(f->index==FIXED_PATH_STAGE_COUNT)?WF_DONE:WF_COMMAND_READY;
}
void fixed_workflow_update(fixed_workflow_t *f,uint32_t now,bool fresh,bool arrived,bool fault) {
    if(!f || (f->state!=WF_MOVING && f->state!=WF_HOLDING)) return;
    if(fault) {fail(f,WF_ERR_MOTOR);return;}
    if(!fresh) {fail(f,WF_ERR_FEEDBACK);return;}
    const fixed_waypoint_t *w=&f->plan->stages[f->index].waypoint;
    uint32_t elapsed=now-f->started_ms;
    if(f->state==WF_HOLDING) {
        if(!arrived) {fail(f,WF_ERR_FEEDBACK);return;}
        if(now-f->hold_started_ms>=w->hold_after_arrival_ms) advance(f);
        return;
    }
    if(arrived && elapsed>=w->original_gate_ms) {
        if(w->hold_after_arrival_ms) {f->hold_started_ms=now;f->state=WF_HOLDING;}
        else advance(f);
        return;
    }
    uint32_t timeout=w->original_arrival_timeout_ms?w->original_arrival_timeout_ms:f->fallback_motion_timeout_ms;
    /* Preserve points/order/hold values, but never treat a timeout as arrival. */
    if(elapsed>=timeout) fail(f,WF_ERR_TIMEOUT);
}
void fixed_workflow_abort(fixed_workflow_t *f) {
    if(f && f->state!=WF_IDLE && f->state!=WF_DONE) fail(f,WF_ERR_ABORT);
}
