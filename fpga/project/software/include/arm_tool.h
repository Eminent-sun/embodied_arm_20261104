#ifndef ARM_TOOL_H
#define ARM_TOOL_H
#include <stdint.h>
#include "arm_kinematics_port.h"
#define ARM_TOOL_CALIBRATED 0x54435031U
#define ARM_TOOL_LINK6_REFERENCE 0x4C4E4B36U
typedef struct {
    /* T_Link6_TCP: transforms TCP coordinates into Link6. Metres, rotation. */
    urdf_pose_t link6_from_tcp;
    uint32_t tool_id,revision,calibration;
} arm_tool_t;
typedef enum { TOOL_OK=0,TOOL_BAD_CONFIG=1,TOOL_BAD_INPUT=2,TOOL_IK_FAILED=3,TOOL_TCP_RESIDUAL=4 } arm_tool_status_t;
typedef struct {
    arm_ik_solution_t model;
    float tcp_position_error_mm,tcp_orientation_error_rad;
    arm_tool_status_t status;
} arm_tool_solution_t;
bool arm_tool_valid(const arm_tool_t *tool);
bool arm_tool_tcp_to_link6(const arm_tool_t *tool,const urdf_pose_t *base_from_tcp,urdf_pose_t *base_from_link6);
bool arm_tool_link6_to_tcp(const arm_tool_t *tool,const urdf_pose_t *base_from_link6,urdf_pose_t *base_from_tcp);
bool arm_tool_forward(const arm_tool_t *tool,const float model_joint_rad[6],urdf_pose_t *base_from_tcp);
bool arm_tool_inverse_quat_mm(const arm_tool_t *tool,const float xyz_mm[3],const float quaternion_xyzw[4],
                              const float model_seed_rad[6],arm_tool_solution_t *solution);
/* Pure vertical segment: descent follows base -Z, orientation is unchanged.
 * The caller supplies depth; there is no guessed production depth or speed.
 * These helpers do not assert reachability, collision freedom or permission.
 */
bool arm_pick_vertical_sample(const urdf_pose_t *above_tcp,float depth_mm,float fraction,urdf_pose_t *out);
typedef struct {urdf_pose_t initial_tcp,above_tcp,down_tcp,lift_return_tcp;} arm_pick_geometry_t;
bool arm_pick_geometry(const urdf_pose_t *recorded_initial_tcp,const urdf_pose_t *above_tcp,
                       float depth_mm,arm_pick_geometry_t *geometry);
#endif
