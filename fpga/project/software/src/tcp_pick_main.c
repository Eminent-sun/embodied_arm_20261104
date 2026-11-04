#include "fixed_path.h"
#include "fixed_workflow.h"
#include "tool_tests.h"
#include "physical_config.h"
#include "pick_candidate.h"
fixed_path_report_t g_fixed_path_report;
arm_tool_test_report_t g_tool_report;
pick_candidate_report_t g_pick_candidate_report;
pick_candidate_report_t g_rejected_rpy90_report;
unsigned g_fixed_workflow_test_checks;
_Static_assert(sizeof(fixed_path_report_t)==1088,"Fixed path ABI");
_Static_assert(sizeof(arm_tool_test_report_t)==800,"Tool test ABI");
void compute_main(void) {
    const float seed[6]={0,1.57f,0,0,1.57f,0};
    (void)fixed_path_preflight(seed,&g_fixed_path_report);
    g_fixed_workflow_test_checks=fixed_workflow_offline_tests();
    arm_tool_offline_tests(&g_tool_report);
    pick_candidate_preview(&g_pick_candidate_report);
    const float rejected_orientation[3]={90,0,0};
    pick_candidate_preview_rpy(rejected_orientation,&g_rejected_rpy90_report);
    __asm__ volatile("dsb sy" ::: "memory");
}
