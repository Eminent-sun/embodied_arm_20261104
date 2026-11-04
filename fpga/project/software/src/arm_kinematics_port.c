#include "arm_kinematics_port.h"
#include <math.h>
#include <stddef.h>
#include <string.h>

static arm_kinematics_service_fn service_callback;
static void *service_context;
void arm_kinematics_set_service(arm_kinematics_service_fn fn,void *context) {
    service_callback=fn;service_context=context;
}
int arm_kinematics_service(void) {
    return service_callback?service_callback(service_context):0;
}

static bool finite_array(const float *v, unsigned n) {
    if (v == NULL) return false;
    for (unsigned i=0; i<n; ++i) if (!isfinite(v[i])) return false;
    return true;
}
static bool valid_pose(const urdf_pose_t *p) {
    if (p == NULL || !finite_array(p->position,3)) return false;
    for (unsigned i=0;i<3;++i) if (!finite_array(p->rotation[i],3)) return false;
    for (unsigned i=0;i<3;++i) for (unsigned j=0;j<3;++j) {
        float dot=0.0f;
        for (unsigned k=0;k<3;++k) dot+=p->rotation[i][k]*p->rotation[j][k];
        if (fabsf(dot-((i==j)?1.0f:0.0f))>0.0002f) return false;
    }
    const float (*r)[3]=p->rotation;
    float det=r[0][0]*(r[1][1]*r[2][2]-r[1][2]*r[2][1])
             -r[0][1]*(r[1][0]*r[2][2]-r[1][2]*r[2][0])
             +r[0][2]*(r[1][0]*r[2][1]-r[1][1]*r[2][0]);
    return fabsf(det-1.0f)<=0.0002f;
}
static void reject(arm_ik_solution_t *s, arm_kin_status_t status) {
    if (s != NULL) { memset(s,0,sizeof(*s)); s->status=status; }
}
bool arm_kinematics_pose_from_rpy_mm_deg(const arm_cartesian_pose_mm_deg_t *in, urdf_pose_t *p) {
    if (!in || !p || !finite_array(in->xyz_mm,3) || !finite_array(in->rpy_deg,3)) return false;
    float roll=in->rpy_deg[0]*0.01745329252f;
    float pitch=in->rpy_deg[1]*0.01745329252f;
    float yaw=in->rpy_deg[2]*0.01745329252f;
    float cr=cosf(roll),sr=sinf(roll),cp=cosf(pitch),sp=sinf(pitch),cy=cosf(yaw),sy=sinf(yaw);
    p->rotation[0][0]=cy*cp; p->rotation[0][1]=cy*sp*sr-sy*cr; p->rotation[0][2]=cy*sp*cr+sy*sr;
    p->rotation[1][0]=sy*cp; p->rotation[1][1]=sy*sp*sr+cy*cr; p->rotation[1][2]=sy*sp*cr-cy*sr;
    p->rotation[2][0]=-sp; p->rotation[2][1]=cp*sr; p->rotation[2][2]=cp*cr;
    for (unsigned i=0;i<3;++i) p->position[i]=in->xyz_mm[i]*0.001f;
    return valid_pose(p);
}
bool arm_kinematics_pose_from_quat_mm(const float xyz[3], const float v[4], urdf_pose_t *p) {
    if (!p || !finite_array(xyz,3) || !finite_array(v,4)) return false;
    float scale=0.0f;
    for (unsigned i=0;i<4;++i) if (fabsf(v[i])>scale) scale=fabsf(v[i]);
    if (scale==0.0f) return false;
    float q[4],sum=0.0f;
    for (unsigned i=0;i<4;++i) { q[i]=v[i]/scale; sum+=q[i]*q[i]; }
    float inv=1.0f/sqrtf(sum);
    for (unsigned i=0;i<4;++i) q[i]*=inv;
    float x=q[0],y=q[1],z=q[2],w=q[3];
    p->rotation[0][0]=1.0f-2.0f*(y*y+z*z); p->rotation[0][1]=2.0f*(x*y-z*w); p->rotation[0][2]=2.0f*(x*z+y*w);
    p->rotation[1][0]=2.0f*(x*y+z*w); p->rotation[1][1]=1.0f-2.0f*(x*x+z*z); p->rotation[1][2]=2.0f*(y*z-x*w);
    p->rotation[2][0]=2.0f*(x*z-y*w); p->rotation[2][1]=2.0f*(y*z+x*w); p->rotation[2][2]=1.0f-2.0f*(x*x+y*y);
    for (unsigned i=0;i<3;++i) p->position[i]=xyz[i]*0.001f;
    return valid_pose(p);
}
void arm_kinematics_residual(const urdf_pose_t *a,const urdf_pose_t *t,float *pe,float *oe) {
    float r[3][3],sum=0.0f;
    for (unsigned i=0;i<3;++i) {
        float d=a->position[i]-t->position[i]; sum+=d*d;
        for (unsigned j=0;j<3;++j) {
            r[i][j]=0.0f;
            for (unsigned k=0;k<3;++k) r[i][j]+=t->rotation[i][k]*a->rotation[j][k];
        }
    }
    float x=r[2][1]-r[1][2],y=r[0][2]-r[2][0],z=r[1][0]-r[0][1];
    *pe=sqrtf(sum);
    /* atan2 retains the pi case that the vendor skew-only branch cannot see. */
    *oe=atan2f(sqrtf(x*x+y*y+z*z),r[0][0]+r[1][1]+r[2][2]-1.0f);
}
bool arm_kinematics_solve_pose_m(const urdf_pose_t *target,const float seed[6],arm_ik_solution_t *s) {
    reject(s,ARM_KIN_BAD_INPUT);
    if (!s || !valid_pose(target) || !finite_array(seed,6)) return false;
    urdf_ik_result_t original;
    memset(&original,0,sizeof(original));
    if (!urdf_kinematics_inverse(target,seed,&original)) { s->status=ARM_KIN_NO_SOLUTION; return false; }
    urdf_pose_t fk;
    urdf_kinematics_forward(original.joint_rad,&fk);
    float pe,oe;
    arm_kinematics_residual(&fk,target,&pe,&oe);
    if (!finite_array(original.joint_rad,6) || !isfinite(pe) || !isfinite(oe) ||
        pe>0.0005f || oe>0.00873f) { s->status=ARM_KIN_RESIDUAL_REJECTED; return false; }
    memcpy(s->joint_rad,original.joint_rad,sizeof(s->joint_rad));
    s->position_error_mm=pe*1000.0f; s->orientation_error_rad=oe;
    s->original_position_error_m=original.position_error_m;
    s->original_orientation_error_rad=original.orientation_error_rad;
    s->iterations=original.iterations; s->status=ARM_KIN_OK;
    return true;
}
bool arm_kinematics_solve_quat_mm(const float xyz[3],const float q[4],const float seed[6],arm_ik_solution_t *s) {
    urdf_pose_t p;
    reject(s,ARM_KIN_BAD_INPUT);
    if (!arm_kinematics_pose_from_quat_mm(xyz,q,&p)) return false;
    return arm_kinematics_solve_pose_m(&p,seed,s);
}
bool arm_kinematics_solve_rpy_mm_deg(const arm_cartesian_pose_mm_deg_t *t,const float seed[6],arm_ik_solution_t *s) {
    urdf_pose_t p;
    reject(s,ARM_KIN_BAD_INPUT);
    if (!arm_kinematics_pose_from_rpy_mm_deg(t,&p)) return false;
    return arm_kinematics_solve_pose_m(&p,seed,s);
}
bool arm_kinematics_forward_mm(const float q[6],arm_fk_pose_mm_t *p) {
    if (p) memset(p,0,sizeof(*p));
    if (!p || !finite_array(q,6)) return false;
    urdf_pose_t raw;
    urdf_kinematics_forward(q,&raw);
    if (!valid_pose(&raw)) return false;
    for (unsigned i=0;i<3;++i) p->xyz_mm[i]=raw.position[i]*1000.0f;
    memcpy(p->rotation,raw.rotation,sizeof(p->rotation));
    return true;
}
