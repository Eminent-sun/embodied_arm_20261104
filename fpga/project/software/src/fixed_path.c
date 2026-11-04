#include "fixed_path.h"
#include <math.h>
#include <stddef.h>
#include <string.h>

/* Preserved legacy orientation convention: R_cmd * R_base, not plain URDF RPY.
 * Legacy source PI and input literals deliberately remain unchanged.
 */
static void build_legacy_pose(float rx_deg,float ry_deg,float rz_deg,float x,float y,float z,float pose[4][4]) {
    const float legacy_pi=3.1415926f;
    float rx=rx_deg*(legacy_pi/180.0f),ry=ry_deg*(legacy_pi/180.0f),rz=rz_deg*(legacy_pi/180.0f);
    float cx=cosf(rx),sx=sinf(rx),cy=cosf(ry),sy=sinf(ry),cz=cosf(rz),sz=sinf(rz);
    float cmd[3][3]={{cz*cy,cz*sy*sx-sz*cx,cz*sy*cx+sz*sx},
                     {sz*cy,sz*sy*sx+cz*cx,sz*sy*cx-cz*sx},{-sy,cy*sx,cy*cx}};
    const float base[3][3]={{0,0,1},{0,-1,0},{1,0,0}};
    memset(pose,0,sizeof(float)*16);
    for(unsigned i=0;i<3;++i) for(unsigned j=0;j<3;++j)
        pose[i][j]=cmd[i][0]*base[0][j]+cmd[i][1]*base[1][j]+cmd[i][2]*base[2][j];
    pose[0][3]=x;pose[1][3]=y;pose[2][3]=z;pose[3][3]=1;
}
bool fixed_path_get_waypoint(unsigned index,fixed_waypoint_t *out) {
    if(!out || index>=FIXED_PATH_STAGE_COUNT) return false;
    memset(out,0,sizeof(*out));
    switch(index) {
    case 0: /* MOVE_PRESET */
        build_legacy_pose(0,0,0,200,0,100,out->legacy_matrix_mm);out->original_gate_ms=3000;break;
    case 1: /* MOVE_POS1; bypass original visual stage, keep uncorrected nominal */
        build_legacy_pose(0,90,0,120,280,200,out->legacy_matrix_mm);out->original_gate_ms=2000;break;
    case 2: /* GRAB_DESCEND; source constant=160, despite comment saying 100 */
        build_legacy_pose(0,90,0,120,280,200,out->legacy_matrix_mm);
        out->legacy_matrix_mm[2][3]-=160.0f;out->hold_after_arrival_ms=2000;out->original_arrival_timeout_ms=3000;break;
    case 3: /* GRAB_LIFT_UP */
        build_legacy_pose(0,90,0,120,280,200,out->legacy_matrix_mm);
        out->hold_after_arrival_ms=2000;out->original_arrival_timeout_ms=3000;break;
    case 4: /* MOVE_POS2; bypass original visual stage */
        build_legacy_pose(0,0,0,250,0,100,out->legacy_matrix_mm);out->original_gate_ms=5000;break;
    case 5: /* X_FORWARD; source constant=100, despite comment saying 50 */
        build_legacy_pose(0,0,0,250,0,100,out->legacy_matrix_mm);
        out->legacy_matrix_mm[0][3]+=100.0f;out->original_gate_ms=5000;break;
    case 6: /* X_BACKWARD */
        build_legacy_pose(0,0,0,250,0,100,out->legacy_matrix_mm);out->original_gate_ms=3000;break;
    default: /* Original AppRequestZeroPose requests motor targets [0,...,0]. */
        out->kind=FIXED_LEGACY_MOTOR_ZERO;out->original_arrival_timeout_ms=3000;break;
    }
    return true;
}
bool fixed_path_can_start(const fixed_path_report_t *r) {
    return r && r->magic==0x46505431U && r->version==1 && r->complete==1 &&
        r->count==FIXED_PATH_STAGE_COUNT && r->valid_pose_mask==0x7f &&
        r->failed_pose_mask==0 && r->blockers==0 && r->execution_allowed==1;
}
bool fixed_path_preflight(const float model_seed[6],fixed_path_report_t *r) {
    if(!r) return false;
    memset(r,0,sizeof(*r));r->magic=0x46505431U;r->version=1;r->count=FIXED_PATH_STAGE_COUNT;
    /* No calibration supplied: immutable diagnostic blockers, never bypassed. */
    r->blockers=FIXED_BLOCK_FRAME_UNCONFIRMED|FIXED_BLOCK_ZERO_UNCONFIRMED;
    if(!model_seed) {r->blockers|=FIXED_BLOCK_IK;r->complete=1;return false;}
    float seed[6];memcpy(seed,model_seed,sizeof(seed));
    for(unsigned index=0;index<FIXED_PATH_STAGE_COUNT;++index) {
        fixed_path_stage_result_t *s=&r->stages[index];s->stage_index=index;
        (void)fixed_path_get_waypoint(index,&s->waypoint);
        if(s->waypoint.kind==FIXED_LEGACY_MOTOR_ZERO) {s->model_solution.status=ARM_KIN_BAD_INPUT;continue;}
        urdf_pose_t target;
        for(unsigned i=0;i<3;++i) {
            target.position[i]=s->waypoint.legacy_matrix_mm[i][3]*0.001f;
            for(unsigned j=0;j<3;++j) target.rotation[i][j]=s->waypoint.legacy_matrix_mm[i][j];
        }
        if(arm_kinematics_solve_pose_m(&target,seed,&s->model_solution)) {
            r->valid_pose_mask|=1U<<index;memcpy(seed,s->model_solution.joint_rad,sizeof(seed));
        } else {r->failed_pose_mask|=1U<<index;r->blockers|=FIXED_BLOCK_IK;}
    }
    r->execution_allowed=0;r->complete=1;
    return false;
}
