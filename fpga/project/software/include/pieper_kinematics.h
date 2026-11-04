#ifndef PIEPER_KINEMATICS_H
#define PIEPER_KINEMATICS_H
#include "urdf_kinematics.h"
/* Exact stored geometry: parallel J2/J3 and intersecting J4/J5/J6.
 * Analytic shoulder/elbow branches followed by general spherical-wrist
 * branches. Every accepted candidate is checked using original URDF FK.
 * Additional bounds may only narrow the original model limits. */
bool pieper_kinematics_inverse(const urdf_pose_t *target,const float seed[6],
 const float extra_min[6],const float extra_max[6],urdf_ik_result_t *result,
 unsigned *solutions);
#endif
