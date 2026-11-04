#include "fixed_path.h"
#include "fixed_workflow.h"
fixed_path_report_t g_fixed_path_report;
unsigned g_fixed_workflow_test_checks;
_Static_assert(sizeof(fixed_waypoint_t)==80,"Waypoint ABI");
_Static_assert(sizeof(fixed_path_stage_result_t)==132,"Stage result ABI");
_Static_assert(sizeof(fixed_path_report_t)==1088,"Report ABI");
/* Offline model home seed, never substituted for measured joint feedback. */
void compute_main(void) {
    const float seed[6]={0,1.57f,0,0,1.57f,0};
    (void)fixed_path_preflight(seed,&g_fixed_path_report);
    g_fixed_workflow_test_checks=fixed_workflow_offline_tests();
    __asm__ volatile("dsb sy" ::: "memory");
}
