#ifndef PATH_EXECUTOR_H
#define PATH_EXECUTOR_H
#include <stdint.h>
#include "pick_candidate.h"
#define PATH_CAL_CONFIRMED 0x43414C31U
#define PATH_STOP_POLICY_CONFIRMED 0x53544F31U
#define PATH_HOST_GO 0x52554E31U
#define PATH_MAX_FRAMES 2048U
typedef struct {
    uint32_t motor_id,expected_zero_state,expected_offset_bits;
    float gain,motor_zero_rad,safe_min_rad,safe_max_rad;
    float speed_rad_s,accel_rad_s2,velocity_trip_rad_s,following_error_rad;
    float arrival_position_rad,arrival_velocity_rad_s;
} path_axis_config_t;
typedef struct {
    uint32_t calibration,stop_policy,sample_ms,command_timeout_ms,arrival_timeout_ms,max_job_ms;
    float start_joint_tolerance_rad,max_cartesian_error_mm;
    path_axis_config_t axis[6];
} path_config_t;
typedef struct {
    uint32_t time_ms,stage,last_in_stage;
    float model_joint_rad[6],motor_rad[6];
} path_frame_t;
typedef struct {uint32_t count,duration_ms;path_frame_t frames[PATH_MAX_FRAMES];} path_plan_t;
enum { PATH_OK=0,PATH_BAD_CONFIG=1,PATH_BAD_GEOMETRY=2,PATH_START_MISMATCH=3,
       PATH_INFEASIBLE=4,PATH_IO_ERROR=5,PATH_NOT_STOPPED=6,PATH_PREPARE_ERROR=7,
       PATH_FRAME_LATE=8,PATH_TRACK_ERROR=9,PATH_ARRIVAL_ERROR=10,PATH_STOP_UNKNOWN=11 };
typedef struct {
    uint32_t magic,version,phase,error,axis,frames_completed,last_sequence,elapsed_ms;
    uint32_t enabled_mask,stop_confirmed,commands,consumed_request;
    float initial_motor_rad[6],final_motor_rad[6],final_velocity_rad_s[6];
} path_execution_report_t;
typedef struct {
    void *context;
    uint32_t (*now_ms)(void *);
    int (*healthy)(void *);
    int (*transaction)(void *,uint32_t word,uint32_t value,uint32_t *result);
    uint32_t (*feedback_page)(void *,unsigned axis,unsigned page);
    void (*emergency_stop)(void *);
} path_io_t;
/* Caller supplies measured/verified mechanical configuration. All defaults are
 * invalid. Model radians and motor load-side radians are separate quantities.
 */
int path_config_valid(const path_config_t *config);
int path_plan_compile(const path_config_t *config,const pick_candidate_report_t *geometry,
                       const float measured_initial_motor_rad[6],path_plan_t *plan);
int path_execute_once(const path_config_t *config,const pick_candidate_report_t *geometry,
                       path_plan_t *workspace,const path_io_t *io,path_execution_report_t *report);
#endif
