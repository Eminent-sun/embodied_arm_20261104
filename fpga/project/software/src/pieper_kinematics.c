#include "pieper_kinematics.h"
#include "arm_kinematics_port.h"
#include "../build/urdf_model_parameters.h"
#include <float.h>
#include <math.h>
#include <string.h>
#define PI 3.14159265358979323846
typedef double mat[3][3];
static void mul(const mat a,const mat b,mat out){mat t={{0}};
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)for(unsigned k=0;k<3;++k)t[i][j]+=a[i][k]*b[k][j];
    memcpy(out,t,sizeof(t));}
static void trans(const mat a,mat b){for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)b[i][j]=a[j][i];}
static void rz(double q,mat r){memset(r,0,sizeof(mat));r[0][0]=r[1][1]=cos(q);r[0][1]=-sin(q);r[1][0]=sin(q);r[2][2]=1;}
static void rotation(const float q[3],mat r){double cr=cos(q[0]),sr=sin(q[0]),cp=cos(q[1]),sp=sin(q[1]),cy=cos(q[2]),sy=sin(q[2]);
    r[0][0]=cy*cp;r[0][1]=cy*sp*sr-sy*cr;r[0][2]=cy*sp*cr+sy*sr;
    r[1][0]=sy*cp;r[1][1]=sy*sp*sr+cy*cr;r[1][2]=sy*sp*cr-cy*sr;
    r[2][0]=-sp;r[2][1]=cp*sr;r[2][2]=cp*cr;}
static int roots(double a,double b,double c,double preferred,double out[2]){
    double rho=hypot(a,b);if(rho<1e-12){if(fabs(c)>1e-9)return 0;out[0]=preferred;return 1;}
    double ratio=c/rho;if(ratio>1+2e-6||ratio<-1-2e-6)return 0;
    ratio=fmax(-1,fmin(1,ratio));double angle=atan2(b,a),delta=acos(ratio);
    out[0]=angle+delta;out[1]=angle-delta;return delta<1e-10?1:2;
}
static int bounded(double angle,unsigned i,const float low[6],const float high[6],float *out){
    if(!isfinite(angle))return 0;
    double lo=pieper_joint_min[i],hi=pieper_joint_max[i];
    if(low)lo=fmax(lo,low[i]);
    if(high)hi=fmin(hi,high[i]);
    double turns=ceil((lo-angle-1e-6)/(2*PI));angle+=turns*2*PI;
    if(angle<lo-1e-6||angle>hi+1e-6)return 0;
    *out=(float)fmax(lo,fmin(hi,angle));return 1;
}
static int geometry_supported(void){
    for(unsigned i=0;i<3;++i)if(pieper_origin_xyz[0][i]||pieper_origin_xyz[4][i]||pieper_origin_xyz[5][i]||pieper_origin_rpy[0][i])return 0;
    return pieper_origin_rpy[2][0]==0&&pieper_origin_rpy[2][1]==0;
}
bool pieper_kinematics_inverse(const urdf_pose_t *target,const float seed[6],
 const float low[6],const float high[6],urdf_ik_result_t *result,unsigned *solutions){
    if(solutions)*solutions=0;
    if(!target||!seed||!result)return false;
    memset(result,0,sizeof(*result));
    if(!geometry_supported())return false;
    for(unsigned i=0;i<6;++i)if(!isfinite(seed[i])||(low&&!isfinite(low[i]))||(high&&!isfinite(high[i])))return false;
    for(unsigned i=0;i<3;++i){if(!isfinite(target->position[i]))return false;
        for(unsigned j=0;j<3;++j)if(!isfinite(target->rotation[i][j]))return false;}
    mat o2,o4,b,c,tr;rotation(pieper_origin_rpy[1],o2);rotation(pieper_origin_rpy[3],o4);
    rotation(pieper_origin_rpy[4],b);rotation(pieper_origin_rpy[5],c);
    for(unsigned i=0;i<3;++i)for(unsigned j=0;j<3;++j)tr[i][j]=target->rotation[i][j];
    /* p = Rz(q1) [p2 + O2 (Rz(q2)p3 + Rz(q2+q3+beta)p4)].
     * Projecting onto O2*z removes q2 and q3, giving two q1 roots. */
    double v[3]={target->position[0],target->position[1],target->position[2]};
    double n[3]={o2[0][2],o2[1][2],o2[2][2]};
    double constant=pieper_origin_xyz[2][2]+pieper_origin_xyz[3][2];
    for(unsigned i=0;i<3;++i)constant+=n[i]*pieper_origin_xyz[1][i];
    double shoulder[2];int ns=roots(n[0]*v[0]+n[1]*v[1],n[0]*v[1]-n[1]*v[0],constant-n[2]*v[2],seed[0],shoulder);
    double l1=hypot(pieper_origin_xyz[2][0],pieper_origin_xyz[2][1]);
    double l2=hypot(pieper_origin_xyz[3][0],pieper_origin_xyz[3][1]);
    double phi1=atan2(pieper_origin_xyz[2][1],pieper_origin_xyz[2][0]);
    double phi2=atan2(pieper_origin_xyz[3][1],pieper_origin_xyz[3][0]);
    if(l1<1e-9||l2<1e-9)return false;
    double best=DBL_MAX;unsigned accepted=0;
    for(int s=0;s<ns;++s){
        if(arm_kinematics_service())return false;
        float q[6]={0};if(!bounded(shoulder[s],0,low,high,&q[0]))continue;
        double cs=cos(q[0]),sn=sin(q[0]);
        double local[3]={cs*v[0]+sn*v[1]-pieper_origin_xyz[1][0],-sn*v[0]+cs*v[1]-pieper_origin_xyz[1][1],v[2]-pieper_origin_xyz[1][2]};
        double u[3]={0};for(unsigned i=0;i<3;++i)for(unsigned k=0;k<3;++k)u[i]+=o2[k][i]*local[k];
        double cosine=(u[0]*u[0]+u[1]*u[1]-l1*l1-l2*l2)/(2*l1*l2);
        if(cosine>1+2e-6||cosine<-1-2e-6)continue;
        double elbow=acos(fmax(-1,fmin(1,cosine)));
        for(int e=0;e<2;++e){double t=e?-elbow:elbow;
            if(!bounded(t-pieper_origin_rpy[2][2]-phi2+phi1,2,low,high,&q[2])||
               !bounded(atan2(u[1],u[0])-phi1-atan2(l2*sin(t),l1+l2*cos(t)),1,low,high,&q[1]))continue;
            mat r,z,rt,m;rz(q[0],r);mul(r,o2,r);rz(q[1]+q[2]+pieper_origin_rpy[2][2],z);mul(r,z,r);mul(r,o4,r);
            trans(r,rt);mul(rt,tr,m);
            double aa[3]={b[2][0],b[2][1],b[2][2]},bb[3]={c[0][2],c[1][2],c[2][2]},wrist[2];
            int nw=roots(aa[0]*bb[0]+aa[1]*bb[1],-aa[0]*bb[1]+aa[1]*bb[0],m[2][2]-aa[2]*bb[2],seed[4],wrist);
            for(int w=0;w<nw;++w){
                if(!bounded(wrist[w],4,low,high,&q[4]))continue;
                mat mid,z5;rz(q[4],z5);mul(b,z5,mid);mul(mid,c,mid);
                double horizontal=hypot(mid[0][2],mid[1][2]);
                /* Near the wrist singularity the redundant split is selected
                 * close to the seed, then revalidated by original FK. */
                for(int variant=0;variant<(horizontal<1e-5?3:1);++variant){
                    double angle4=variant==0?atan2(m[1][2],m[0][2])-atan2(mid[1][2],mid[0][2]):seed[3];
                    if(variant==2){mat z6t,mt,trial;rz(-seed[5],z6t);trans(mid,mt);mul(m,z6t,trial);mul(trial,mt,trial);angle4=atan2(trial[1][0],trial[0][0]);}
                    if(!bounded(angle4,3,low,high,&q[3]))continue;
                    mat z4,partial,pt,last;rz(q[3],z4);mul(z4,mid,partial);trans(partial,pt);mul(pt,m,last);
                    if(!bounded(atan2(last[1][0],last[0][0]),5,low,high,&q[5]))continue;
                    urdf_pose_t fk;urdf_kinematics_forward(q,&fk);float pe,oe;arm_kinematics_residual(&fk,target,&pe,&oe);
                    if(!isfinite(pe)||!isfinite(oe)||pe>.0005f||oe>.00873f)continue;
                    ++accepted;double cost=0;for(unsigned a=0;a<6;++a)cost+=fabs((double)q[a]-seed[a]);
                    if(cost<best){best=cost;memcpy(result->joint_rad,q,sizeof(q));result->position_error_m=pe;result->orientation_error_rad=oe;result->iterations=0;}
                }
            }
        }
    }
    if(solutions)*solutions=accepted;
    return accepted!=0;
}
