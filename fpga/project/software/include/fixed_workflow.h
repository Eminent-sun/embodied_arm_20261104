#ifndef FIXED_WORKFLOW_H
#define FIXED_WORKFLOW_H
#include "fixed_path.h"
enum { WF_IDLE=0,WF_COMMAND_READY=1,WF_MOVING=2,WF_HOLDING=3,WF_DONE=4,WF_STOP_REQUIRED=5 };
enum { WF_ERR_NONE=0,WF_ERR_SUBMIT=1,WF_ERR_TIMEOUT=2,WF_ERR_FEEDBACK=3,WF_ERR_MOTOR=4,WF_ERR_ABORT=5 };
typedef struct {
    const fixed_path_report_t *plan;
    uint32_t state,index,started_ms,hold_started_ms,error;
    uint32_t fallback_motion_timeout_ms;
} fixed_workflow_t;
/* Pure single-pass sequencer. It emits abstract actions; no physical backend is
 * linked. STOP_REQUIRED is a request to a future backend, never stop proof.
 * Caller must retain an immutable plan and serialize calls. No automatic retry.
 */
void fixed_workflow_init(fixed_workflow_t *flow);
bool fixed_workflow_start(fixed_workflow_t *flow,const fixed_path_report_t *validated_plan,uint32_t motion_timeout_ms);
const fixed_path_stage_result_t *fixed_workflow_next_action(const fixed_workflow_t *flow);
void fixed_workflow_command_result(fixed_workflow_t *flow,bool accepted,uint32_t now_ms);
void fixed_workflow_update(fixed_workflow_t *flow,uint32_t now_ms,bool feedback_fresh,bool all_axes_at_target,bool motor_fault);
void fixed_workflow_abort(fixed_workflow_t *flow);
unsigned fixed_workflow_offline_tests(void);
#endif
