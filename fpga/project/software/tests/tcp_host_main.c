#include "fixed_path.h"
#include "fixed_workflow.h"
#include "tool_tests.h"
#include "pick_candidate.h"
#include <stdio.h>
static fixed_path_report_t path;
static arm_tool_test_report_t tool;
static pick_candidate_report_t candidate;
static pick_candidate_report_t rejected;
int main(int argc,char **argv) {
    if(argc!=4) return 2;
    const float seed[6]={0,1.57f,0,0,1.57f,0};
    (void)fixed_path_preflight(seed,&path);arm_tool_offline_tests(&tool);
    pick_candidate_preview(&candidate);
    const float rejected_rpy[3]={90,0,0};pick_candidate_preview_rpy(rejected_rpy,&rejected);
    if(path.execution_allowed||path.valid_pose_mask!=0x51||path.failed_pose_mask!=0x2e||path.blockers!=7) return 1;
    if(fixed_workflow_offline_tests()!=31||tool.failed||tool.count!=31||tool.motor_start_allowed) return 1;
    if(!candidate.math_passed||candidate.count!=232||candidate.execution_allowed||candidate.applied_to_original||rejected.math_passed||rejected.failed_stage!=1) return 1;
    FILE *f=fopen(argv[1],"wb");if(!f) return 2;
    bool saved=fwrite(&path,sizeof(path),1,f)==1;if(fclose(f)!=0) saved=false;
    f=fopen(argv[2],"wb");if(!f) return 2;
    saved=(fwrite(&tool,sizeof(tool),1,f)==1)&&saved;if(fclose(f)!=0) saved=false;
    f=fopen(argv[3],"wb");if(!f) return 2;
    saved=(fwrite(&candidate,sizeof(candidate),1,f)==1)&&saved;if(fclose(f)!=0) saved=false;
    printf("TCP_TESTS: %u passed, %u failed; bare Link6 reference valid; motor start LOCKED\n",tool.passed,tool.failed);
    printf("CANDIDATE_ONLY: samples=%u math_passed=%u original_applied=%u execution_allowed=%u\n",candidate.count,candidate.math_passed,candidate.applied_to_original,candidate.execution_allowed);
    return saved?0:2;
}
