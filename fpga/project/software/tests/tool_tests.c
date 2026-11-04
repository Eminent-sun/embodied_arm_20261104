#include "tool_tests.h"
#include "arm_tool.h"
#include "physical_config.h"
#include <math.h>
#include <string.h>
static void check(arm_tool_test_report_t *r,unsigned id,bool pass,float error) {
    if(r->count>=64) {r->failed++;return;}
    r->records[r->count++]=(arm_tool_test_record_t){id,pass?1U:0U,error};
    if(pass) r->passed++;else r->failed++;
}
static urdf_pose_t identity(void) {urdf_pose_t p={.rotation={{1,0,0},{0,1,0},{0,0,1}},.position={0,0,0}};return p;}
static float diff(const urdf_pose_t *a,const urdf_pose_t *b) {
    float e=0;
    for(unsigned i=0;i<3;++i) {
        float v=fabsf(a->position[i]-b->position[i]);if(v>e) e=v;
        for(unsigned j=0;j<3;++j) {v=fabsf(a->rotation[i][j]-b->rotation[i][j]);if(v>e) e=v;}
    }
    return e;
}
static void quaternion(const float r[3][3],float q[4]) {
    float trace=r[0][0]+r[1][1]+r[2][2];
    if(trace>0) {
        float s=2*sqrtf(trace+1);q[3]=s*.25f;q[0]=(r[2][1]-r[1][2])/s;q[1]=(r[0][2]-r[2][0])/s;q[2]=(r[1][0]-r[0][1])/s;
    } else {
        unsigned i=0;for(unsigned a=1;a<3;++a) if(r[a][a]>r[i][i]) i=a;
        unsigned j=(i+1)%3,k=(i+2)%3;
        float s=2*sqrtf(1+r[i][i]-r[j][j]-r[k][k]);q[i]=s*.25f;q[j]=(r[j][i]+r[i][j])/s;q[k]=(r[k][i]+r[i][k])/s;q[3]=(r[k][j]-r[j][k])/s;
    }
}
void arm_tool_offline_tests(arm_tool_test_report_t *r) {
    memset(r,0,sizeof(*r));r->magic=0x54504331U;r->version=1;
    r->current_control_point_valid=arm_tool_valid(&g_current_control_point)?1U:0U;
    r->motor_start_allowed=g_motor_calibration_confirmed;
    check(r,1,r->current_control_point_valid==1&&r->motor_start_allowed==0,0);
    const float home[6]={0,1.57f,0,0,1.57f,0};urdf_pose_t raw,tcp,roundtrip;
    urdf_kinematics_forward(home,&raw);
    bool ok=arm_tool_forward(&g_current_control_point,home,&tcp);
    check(r,2,ok&&diff(&raw,&tcp)==0,diff(&raw,&tcp));
    arm_tool_t unknown={0};unknown.link6_from_tcp=identity();
    check(r,3,!arm_tool_valid(&unknown),0);
    /* Explicit synthetic 120mm tool fixture, NOT the real end-tool config. */
    arm_tool_t synthetic={.link6_from_tcp={.rotation={{0,-1,0},{1,0,0},{0,0,1}},.position={.01f,-.02f,.12f}},.tool_id=99,.revision=1,.calibration=ARM_TOOL_CALIBRATED};
    urdf_pose_t wrist={.rotation={{0,-1,0},{1,0,0},{0,0,1}},.position={.2f,-.1f,.3f}};
    urdf_pose_t expected={.rotation={{-1,0,0},{0,-1,0},{0,0,1}},.position={.22f,-.09f,.42f}};
    ok=arm_tool_link6_to_tcp(&synthetic,&wrist,&tcp);
    check(r,4,ok&&diff(&tcp,&expected)<1e-6f,diff(&tcp,&expected));
    ok=arm_tool_tcp_to_link6(&synthetic,&tcp,&roundtrip);
    check(r,5,ok&&diff(&wrist,&roundtrip)<1e-6f,diff(&wrist,&roundtrip));
    roundtrip=tcp;ok=arm_tool_tcp_to_link6(&synthetic,&roundtrip,&roundtrip);
    check(r,6,ok&&diff(&wrist,&roundtrip)<1e-6f,diff(&wrist,&roundtrip));
    arm_tool_t bad=synthetic;bad.calibration=ARM_TOOL_LINK6_REFERENCE;
    check(r,7,!arm_tool_valid(&bad),0);
    bad=synthetic;bad.link6_from_tcp.rotation[0][1]=1;
    check(r,8,!arm_tool_valid(&bad),0);
    bad=synthetic;bad.link6_from_tcp.position[0]=NAN;
    check(r,9,!arm_tool_valid(&bad),0);
    float q[4]={0,0,0,1},xyz[3]={50,150,250};arm_tool_solution_t solution;
    ok=arm_tool_inverse_quat_mm(&unknown,xyz,q,home,&solution);
    check(r,10,!ok&&solution.status==TOOL_BAD_CONFIG&&solution.model.status==ARM_KIN_BAD_INPUT,0);
    float zeroq[4]={0,0,0,0};ok=arm_tool_inverse_quat_mm(&synthetic,xyz,zeroq,home,&solution);
    check(r,11,!ok&&solution.status==TOOL_BAD_INPUT,0);
    urdf_pose_t above=identity();above.position[0]=.05f;above.position[1]=.15f;above.position[2]=.25f;
    above.rotation[1][1]=0;above.rotation[1][2]=-1;above.rotation[2][1]=1;above.rotation[2][2]=0;
    ok=arm_pick_vertical_sample(&above,40,.5f,&tcp);
    expected=above;expected.position[2]=.23f;
    check(r,12,ok&&diff(&tcp,&expected)<1e-6f,diff(&tcp,&expected));
    check(r,13,!arm_pick_vertical_sample(&above,40,1.1f,&tcp),0);
    check(r,14,!arm_pick_vertical_sample(&above,-1,.5f,&tcp),0);
    urdf_pose_t initial=above;initial.position[0]=-.04f;arm_pick_geometry_t geometry;
    ok=arm_pick_geometry(&initial,&above,40,&geometry);
    check(r,15,ok&&diff(&geometry.lift_return_tcp,&above)==0&&diff(&geometry.initial_tcp,&initial)==0&&
          fabsf(geometry.down_tcp.position[2]-.21f)<1e-6f,0);
    for(unsigned n=0;n<16;++n) {
        float joints[6]={-.8f+.1f*n,1.2f+.03f*n,-.9f-.02f*n,.2f,.5f,-.4f};
        ok=arm_tool_forward(&synthetic,joints,&tcp);quaternion(tcp.rotation,q);
        for(unsigned i=0;i<3;++i) xyz[i]=tcp.position[i]*1000;
        ok=ok&&arm_tool_inverse_quat_mm(&synthetic,xyz,q,joints,&solution);
        float error=0;
        if(ok) for(unsigned i=0;i<6;++i) {float d=fabsf(solution.model.joint_rad[i]-joints[i]);if(d>error) error=d;}
        check(r,100+n,ok&&solution.tcp_position_error_mm<=.5f&&solution.tcp_orientation_error_rad<=.00873f&&error<.002f,error);
    }
    r->complete=1;
}
