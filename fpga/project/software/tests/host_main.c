#include "fixed_path.h"
#include "fixed_workflow.h"
#include <math.h>
#include <stdio.h>
static fixed_path_report_t report;
int main(int argc,char **argv) {
    if(argc!=2) return 2;
    const float seed[6]={0,1.57f,0,0,1.57f,0};
    bool ready=fixed_path_preflight(seed,&report);
    if(ready || fixed_path_can_start(&report) || report.complete!=1 || report.execution_allowed!=0) return 1;
    /* Acceptance here is correct refusal, NOT success of the original route. */
    if(report.valid_pose_mask!=0x51 || report.failed_pose_mask!=0x2e || report.blockers!=7) return 1;
    if(fixed_workflow_offline_tests()!=31) return 1;
    fixed_waypoint_t point;
    if(fixed_path_get_waypoint(8,&point)||fixed_path_get_waypoint(0,NULL)||fixed_path_can_start(NULL)) return 1;
    FILE *f=fopen(argv[1],"wb");if(!f) return 2;
    bool saved=fwrite(&report,sizeof(report),1,f)==1;if(fclose(f)!=0) saved=false;
    printf("PREFLIGHT_GUARD_PASS; ORIGINAL_PATH_BLOCKED valid=0x%02X failed=0x%02X blockers=0x%X\n",
           report.valid_pose_mask,report.failed_pose_mask,report.blockers);
    return saved?0:2;
}
