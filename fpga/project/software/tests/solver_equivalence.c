#include "arm_kinematics_port.h"
#include <stdio.h>
#include <string.h>
bool urdf_original_inverse(const urdf_pose_t *,const float *,urdf_ik_result_t *);
static unsigned callbacks;
static int service(void *unused){(void)unused;++callbacks;return 0;}
int main(void){
    unsigned rng=12345,passed=0;const float seed[6]={0,1.57f,0,0,1.57f,0};
    for(unsigned i=0;i<32;++i){
        float q[6];for(unsigned a=0;a<6;++a){rng=1664525*rng+1013904223;q[a]=(float)(rng>>8)/16777216.f;}
        q[0]=q[0]*2-1;q[1]=.5f+q[1]*2.5f;q[2]=-q[2]*2;
        q[3]=q[3]*4-2;q[4]=q[4]*1.5f;q[5]=q[5]*4-2;
        urdf_pose_t target;urdf_kinematics_forward(q,&target);if(i==31)target.position[0]=100;
        urdf_ik_result_t a={0},b={0};arm_kinematics_set_service(service,0);
        bool ok=urdf_kinematics_inverse(&target,seed,&a);arm_kinematics_set_service(0,0);
        bool original=urdf_original_inverse(&target,seed,&b);
        if(ok!=original||memcmp(&a,&b,sizeof(a))){printf("FAIL solver equivalence %u\n",i);return 1;}
        ++passed;
    }
    if(!callbacks)return 1;
    printf("PASS SOLVER EQUIVALENCE %u TARGETS callbacks=%u (bit-identical outputs)\n",passed,callbacks);return 0;
}
