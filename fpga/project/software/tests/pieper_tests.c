#include "pieper_kinematics.h"
#include "arm_kinematics_port.h"
#include <math.h>
#include <stdio.h>
#include <string.h>
#include "../build/urdf_model_parameters.h"
int main(void){
    unsigned rng=87321,passed=0,singular=0;float seed[6]={0,1.57f,0,0,1.57f,0};
    double worstp=0,worsto=0;
    for(unsigned i=0;i<1012;++i){
        float q[6];for(unsigned a=0;a<6;++a){rng=1664525*rng+1013904223;
            q[a]=pieper_joint_min[a]+(pieper_joint_max[a]-pieper_joint_min[a])*(float)(rng>>8)/16777216.f;}
        if(i<12){q[4]=(int)(i%3)-1;q[4]*=i<6?1e-6f:0.f;++singular;}
        urdf_pose_t target,fk;urdf_kinematics_forward(q,&target);urdf_ik_result_t out;unsigned branches;
        if(!pieper_kinematics_inverse(&target,seed,0,0,&out,&branches)){
            printf("FAIL PIEPER sample=%u q=[%g,%g,%g,%g,%g,%g]\n",i,q[0],q[1],q[2],q[3],q[4],q[5]);return 1;}
        urdf_kinematics_forward(out.joint_rad,&fk);float pe,oe;arm_kinematics_residual(&fk,&target,&pe,&oe);
        if(pe>.0005f||oe>.00873f||!branches)return 1;
        for(unsigned a=0;a<6;++a)if(out.joint_rad[a]<pieper_joint_min[a]-1e-6f||out.joint_rad[a]>pieper_joint_max[a]+1e-6f)return 1;
        if(pe>worstp)worstp=pe;
        if(oe>worsto)worsto=oe;
        memcpy(seed,out.joint_rad,sizeof(seed));++passed;
    }
    urdf_pose_t target;urdf_kinematics_forward(seed,&target);target.position[0]=100;
    urdf_ik_result_t out;unsigned branches;
    if(pieper_kinematics_inverse(&target,seed,0,0,&out,&branches))return 1;
    target.position[0]=NAN;if(pieper_kinematics_inverse(&target,seed,0,0,&out,&branches))return 1;
    /* Exact seed at a regular pose should be selected over a farther branch. */
    const float known[6]={.3f,1.8f,-.8f,.4f,1.f,.2f};urdf_kinematics_forward(known,&target);
    if(!pieper_kinematics_inverse(&target,known,0,0,&out,&branches))return 1;
    for(unsigned a=0;a<6;++a)if(fabsf(out.joint_rad[a]-known[a])>.001f)return 1;
    printf("PASS PIEPER %u FK_IK TARGETS including %u near-singular; unreachable/nonfinite/branch checks; max_position_mm=%.9g max_orientation_rad=%.9g\n",passed,singular,worstp*1000,worsto);return 0;
}
