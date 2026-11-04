#ifndef URDF_KINEMATICS_H
#define URDF_KINEMATICS_H

#include <stdbool.h>

#define URDF_KINEMATICS_JOINT_COUNT (6U)

typedef struct st_urdf_pose
{
    float rotation[3][3];
    float position[3];
} urdf_pose_t;

typedef struct st_urdf_ik_result
{
    float joint_rad[URDF_KINEMATICS_JOINT_COUNT];
    float position_error_m;
    float orientation_error_rad;
    unsigned iterations;
} urdf_ik_result_t;

void urdf_kinematics_forward(const float joint_rad[URDF_KINEMATICS_JOINT_COUNT], urdf_pose_t * pose);
bool urdf_kinematics_inverse(const urdf_pose_t * target,
                             const float current_joint_rad[URDF_KINEMATICS_JOINT_COUNT],
                             urdf_ik_result_t * result);

#endif
