#include "arm_tool.h"
#include <math.h>
#include <stddef.h>
#include <string.h>
static bool valid_pose(const urdf_pose_t *p) {
    if(!p) return false;
    for(unsigned i=0;i<3;++i) {
        if(!isfinite(p->position[i])) return false;
        for(unsigned j=0;j<3;++j) if(!isfinite(p->rotation[i][j])) return false;
    }
    for(unsigned i=0;i<3;++i) for(unsigned j=0;j<3;++j) {
        float dot=0;for(unsigned k=0;k<3;++k) dot+=p->rotation[i][k]*p->rotation[j][k];
        if(fabsf(dot-((i==j)?1.0f:0.0f))>0.0002f) return false;
    }
    const float (*r)[3]=p->rotation;
    float det=r[0][0]*(r[1][1]*r[2][2]-r[1][2]*r[2][1])-
              r[0][1]*(r[1][0]*r[2][2]-r[1][2]*r[2][0])+
              r[0][2]*(r[1][0]*r[2][1]-r[1][1]*r[2][0]);
    return fabsf(det-1.0f)<=0.0002f;
}
bool arm_tool_valid(const arm_tool_t *t) {
    if(!t || !t->tool_id || !t->revision || !valid_pose(&t->link6_from_tcp)) return false;
    if(t->calibration==ARM_TOOL_CALIBRATED) return true;
    if(t->calibration!=ARM_TOOL_LINK6_REFERENCE) return false;
    /* Bare-wrist control point is Link6 by explicit definition, not a measured
     * tool offset. This mode cannot hide an attached, uncalibrated tool. */
    for(unsigned i=0;i<3;++i) {
        if(t->link6_from_tcp.position[i]!=0.0f) return false;
        for(unsigned j=0;j<3;++j) if(t->link6_from_tcp.rotation[i][j]!=((i==j)?1.0f:0.0f)) return false;
    }
    return true;
}
bool arm_tool_tcp_to_link6(const arm_tool_t *t,const urdf_pose_t *tcp,urdf_pose_t *link6) {
    if(!link6 || !arm_tool_valid(t) || !valid_pose(tcp)) return false;
    urdf_pose_t result;
    /* T_B_L = T_B_TCP * inverse(T_L_TCP). Do not subtract tool XYZ in base axes. */
    for(unsigned i=0;i<3;++i) {
        for(unsigned j=0;j<3;++j) {
            result.rotation[i][j]=0;
            for(unsigned k=0;k<3;++k) result.rotation[i][j]+=tcp->rotation[i][k]*t->link6_from_tcp.rotation[j][k];
        }
        result.position[i]=tcp->position[i];
        for(unsigned k=0;k<3;++k) result.position[i]-=result.rotation[i][k]*t->link6_from_tcp.position[k];
    }
    if(!valid_pose(&result)) return false;
    *link6=result;return true;
}
bool arm_tool_link6_to_tcp(const arm_tool_t *t,const urdf_pose_t *link6,urdf_pose_t *tcp) {
    if(!tcp || !arm_tool_valid(t) || !valid_pose(link6)) return false;
    urdf_pose_t result;
    for(unsigned i=0;i<3;++i) {
        for(unsigned j=0;j<3;++j) {
            result.rotation[i][j]=0;
            for(unsigned k=0;k<3;++k) result.rotation[i][j]+=link6->rotation[i][k]*t->link6_from_tcp.rotation[k][j];
        }
        result.position[i]=link6->position[i];
        for(unsigned k=0;k<3;++k) result.position[i]+=link6->rotation[i][k]*t->link6_from_tcp.position[k];
    }
    if(!valid_pose(&result)) return false;
    *tcp=result;return true;
}
bool arm_tool_forward(const arm_tool_t *t,const float q[6],urdf_pose_t *tcp) {
    if(!q || !tcp || !arm_tool_valid(t)) return false;
    for(unsigned i=0;i<6;++i) if(!isfinite(q[i])) return false;
    urdf_pose_t link6;urdf_kinematics_forward(q,&link6);
    return arm_tool_link6_to_tcp(t,&link6,tcp);
}
bool arm_tool_inverse_quat_mm(const arm_tool_t *t,const float xyz[3],const float quat[4],const float seed[6],arm_tool_solution_t *out) {
    if(!out) return false;
    memset(out,0,sizeof(*out));out->status=TOOL_BAD_CONFIG;out->model.status=ARM_KIN_BAD_INPUT;
    if(!arm_tool_valid(t)) return false;
    urdf_pose_t tcp,link6;
    if(!arm_kinematics_pose_from_quat_mm(xyz,quat,&tcp) || !seed) {out->status=TOOL_BAD_INPUT;return false;}
    if(!arm_tool_tcp_to_link6(t,&tcp,&link6)) {out->status=TOOL_BAD_INPUT;return false;}
    arm_ik_solution_t model;
    if(!arm_kinematics_solve_pose_m(&link6,seed,&model)) {out->status=TOOL_IK_FAILED;return false;}
    urdf_pose_t actual;
    if(!arm_tool_forward(t,model.joint_rad,&actual)) {out->status=TOOL_IK_FAILED;return false;}
    float pe,oe;arm_kinematics_residual(&actual,&tcp,&pe,&oe);
    /* Link6 position tolerance alone does not bound a long tool's TCP error. */
    if(!isfinite(pe)||!isfinite(oe)||pe>0.0005f||oe>0.00873f) {out->status=TOOL_TCP_RESIDUAL;return false;}
    out->model=model;out->tcp_position_error_mm=pe*1000.0f;out->tcp_orientation_error_rad=oe;out->status=TOOL_OK;
    return true;
}
bool arm_pick_vertical_sample(const urdf_pose_t *above,float depth,float fraction,urdf_pose_t *out) {
    if(!out || !valid_pose(above) || !isfinite(depth) || depth<=0 || !isfinite(fraction) || fraction<0 || fraction>1) return false;
    urdf_pose_t result=*above;result.position[2]-=depth*0.001f*fraction;
    if(!valid_pose(&result)) return false;
    *out=result;return true;
}
bool arm_pick_geometry(const urdf_pose_t *initial,const urdf_pose_t *above,float depth,arm_pick_geometry_t *out) {
    if(!out || !valid_pose(initial) || !valid_pose(above)) return false;
    arm_pick_geometry_t result;
    if(!arm_pick_vertical_sample(above,depth,1,&result.down_tcp)) return false;
    result.initial_tcp=*initial;result.above_tcp=*above;result.lift_return_tcp=*above;
    *out=result;return true;
}
