#ifndef ARM_WORKFLOW_H
#define ARM_WORKFLOW_H
#include "path_executor.h"
#include "arm_kinematics_port.h"
#include <stddef.h>
#define WF_RECORD_MAGIC 0x43414C32U
#define WF_GO 0x57464C31U
#define WF_DISPATCH_LATE_LIMIT_MS 100U
enum {WF_OFF,WF_CONFIGURED,WF_CALIBRATING,WF_INITIAL,WF_AT_PICK,WF_AT_DELIVERY,
      WF_PICKING,WF_DELIVERING,WF_RETURNING,WF_REFERENCE_SAVED,WF_REFERENCE_HOLD,
      WF_MOVING_CARTESIAN,WF_CARTESIAN_HOLD,WF_PAUSED_HOLD,WF_FAULT=0xe2};

enum {WF_CHECKPOSE=106,WF_MOVETO=107,WF_GOHOME=108,WF_RECOVER=109,WF_RESUME=110};
#define WF_CARTESIAN_MAGIC 0x43504f31U
typedef struct {
    uint32_t magic,version,base_frame,rpy_degrees;
    arm_cartesian_pose_mm_deg_t pose;
} workflow_cartesian_input_t;
typedef struct {
    uint32_t magic,version,sequence,error,model_only,plan_valid,frames,duration_ms,solver,solutions;
    arm_cartesian_pose_mm_deg_t pose;
    float seed_joint_rad[6],target_joint_rad[6],target_motor_rad[6];
    float position_error_mm,orientation_error_rad;
} workflow_cartesian_report_t;
enum {WF_BEGIN=1,WF_CAL_AXIS,WF_SAVE_INITIAL,WF_PICK,WF_DELIVER,WF_RETURN,WF_STOP,WF_READ};
enum {WF_BAD_STATE=20,WF_BAD_AXIS,WF_BAD_RECORD,WF_HOST_LOST,WF_REPLAY};
typedef struct {
    uint32_t magic,version,generation,calibrated_mask,initial_valid,reserved;
    path_config_t config;
    float reference_joint_rad[6],captured_motor_rad[6];
    float initial_joint_rad[6],initial_motor_rad[6];
    uint32_t crc32;
} workflow_record_t;
typedef struct {
    uint32_t magic,version,state,error,active_mask,calibrated_mask,initial_valid;
    uint32_t frames_completed,frames_total,sequence,stop_confirmed,fault_cause;
    float position[6],velocity[6],target[6];
} workflow_report_t;
typedef struct {
    uint32_t magic,version,elapsed_ms,ack_mask;
    uint32_t before_count[6],last_count[6],last_status[6],velocity_raw[6];
} workflow_stop_trace_t;
typedef struct {
    uint32_t magic,version,frame_index,elapsed_ms,due_elapsed_ms,lateness_ms;
    uint32_t observe_ms,publish_ms,last_service_ms,max_service_ms;
    uint32_t completed_at_ms,next_due_elapsed_ms,fault_kind,period_policy,sample_ms,dispatch_late_limit_ms;
} workflow_timing_t;
enum {WF_TIME_JOB_LIMIT=1,WF_TIME_FRAME_LATE=2};
typedef struct {
    workflow_record_t record;
    workflow_report_t report;
    const path_io_t *io;
    const pick_candidate_report_t *geometry;
    path_plan_t *plan,*scratch;
    uint32_t hold_sequence,path_sequence,next_poll,epoch,pause,wait_start,wait_next;
    uint32_t frame,arrival_streak,waiting,job_operation;
    workflow_stop_trace_t stop_trace;
    workflow_timing_t timing;
    uint32_t next_frame_due;
} arm_workflow_t;
typedef int (*workflow_yield_fn)(void *context);
typedef struct {uint32_t motor_id,run_mode,zero_state,offset_bits;float position_rad,velocity_rad_s;} workflow_readback_t;
/* A raw motor reference, NOT a calibrated URDF/model-joint pose. */
typedef struct {
    uint32_t magic,version,generation,captured_mask;
    uint32_t zero_state[6],offset_bits[6];
    float position_rad[6],velocity_rad_s[6];
    uint32_t crc32;
} workflow_pose_record_t;
int workflow_pose_valid(const workflow_pose_record_t *record);
int workflow_capture_pose(arm_workflow_t *w,workflow_pose_record_t *record);
int workflow_restore_pose(arm_workflow_t *w,const workflow_pose_record_t *record);
int workflow_hold_pose(arm_workflow_t *w,const workflow_pose_record_t *record);
int workflow_read_parameters(arm_workflow_t *w,workflow_readback_t out[6]);
uint32_t workflow_crc32(const void *data,size_t bytes);
int workflow_record_valid(const workflow_record_t *record);
void workflow_init(arm_workflow_t *w,const path_io_t *io,const pick_candidate_report_t *geometry,path_plan_t *plan,path_plan_t *scratch);
int workflow_configure(arm_workflow_t *w,const path_config_t *config);
int workflow_restore(arm_workflow_t *w,const workflow_record_t *record);
int workflow_command(arm_workflow_t *w,unsigned operation,unsigned axis,float reference_joint_rad);
void workflow_tick(arm_workflow_t *w,int host_alive);
int workflow_cartesian(arm_workflow_t *w,const arm_cartesian_pose_mm_deg_t *pose,
                       workflow_cartesian_report_t *report,int execute);
int workflow_go_home(arm_workflow_t *w);
int workflow_recover(arm_workflow_t *w,int (*transport_recover)(void *),void *context);
int workflow_joint_allowed(const float joint[6]);
int workflow_joint_plan_build(const path_config_t *c,const float current_motor[6],
                             const float target_joint[6],path_plan_t *plan,
                             workflow_yield_fn yield,void *context);
int workflow_plan_build(const path_config_t *c,const pick_candidate_report_t *geometry,unsigned operation,
                        const float current_motor[6],const float initial_motor[6],path_plan_t *plan,
                        workflow_yield_fn yield,void *context);
#endif
