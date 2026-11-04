#ifndef ARM_KINEMATICS_PORT_H
#define ARM_KINEMATICS_PORT_H
#include "urdf_kinematics.h"

/* Single PS main-loop owner; callback must not recursively run IK. */
typedef int (*arm_kinematics_service_fn)(void *context);
void arm_kinematics_set_service(arm_kinematics_service_fn service,void *context);
int arm_kinematics_service(void);

typedef enum {
    ARM_KIN_OK = 0,
    ARM_KIN_BAD_INPUT = 1,
    ARM_KIN_NO_SOLUTION = 2,
    ARM_KIN_RESIDUAL_REJECTED = 3
} arm_kin_status_t;

typedef struct {
    float joint_rad[6]; /* Model joints, never motor targets. */
    float position_error_mm;
    float orientation_error_rad; /* Independently measured from FK. */
    float original_position_error_m;
    float original_orientation_error_rad;
    unsigned iterations;
    arm_kin_status_t status;
} arm_ik_solution_t;

typedef struct { float xyz_mm[3]; float rotation[3][3]; } arm_fk_pose_mm_t;
typedef struct { float xyz_mm[3]; float rpy_deg[3]; } arm_cartesian_pose_mm_deg_t;

/* R maps Link6 vectors into the original base frame; no extra TCP transform.
 * Public mm interfaces change length units only. RPY is Rz(yaw)Ry(pitch)Rx(roll)
 * as in the original arm_calibration.c. Quaternion is explicitly (x,y,z,w),
 * right-handed Hamilton convention, normalized here; q and -q are equivalent.
 * This is a local API, not an assertion about the absent AIPC wire protocol.
 * Seed must already be expressed in model joint radians. No global state/MMIO.
 * Output is cleared on failure; joint_rad may only be used when return==true.
 */
bool arm_kinematics_solve_pose_m(const urdf_pose_t *target,
                               const float current_joint_rad[6], arm_ik_solution_t *solution);
bool arm_kinematics_solve_quat_mm(const float xyz_mm[3], const float quaternion_xyzw[4],
                                const float current_joint_rad[6], arm_ik_solution_t *solution);
bool arm_kinematics_solve_rpy_mm_deg(const arm_cartesian_pose_mm_deg_t *target,
                                   const float current_joint_rad[6], arm_ik_solution_t *solution);
bool arm_kinematics_forward_mm(const float joint_rad[6], arm_fk_pose_mm_t *pose);
bool arm_kinematics_pose_from_quat_mm(const float xyz_mm[3], const float xyzw[4], urdf_pose_t *pose);
bool arm_kinematics_pose_from_rpy_mm_deg(const arm_cartesian_pose_mm_deg_t *input, urdf_pose_t *pose);
void arm_kinematics_residual(const urdf_pose_t *actual, const urdf_pose_t *target,
                             float *position_error_m, float *orientation_error_rad);
#endif
