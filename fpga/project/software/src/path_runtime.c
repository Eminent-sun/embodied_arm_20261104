#include "path_runtime.h"
#include "path_mailbox.h"
#include <string.h>
volatile path_runtime_request_t g_path_request;
path_execution_report_t g_path_execution_report;
pick_candidate_report_t g_approved_path_geometry;
path_plan_t g_path_workspace;
uint32_t g_path_service_rejection;
static uint32_t consumed_request;
static int service_busy;
_Static_assert(sizeof(path_axis_config_t)==52,"Axis configuration ABI");
_Static_assert(sizeof(path_config_t)==344,"Path configuration ABI");
_Static_assert(sizeof(path_runtime_request_t)==352,"Request ABI");
_Static_assert(sizeof(path_execution_report_t)==120,"Execution report ABI");
_Static_assert(sizeof(path_frame_t)==60,"Scheduled frame ABI");
void compute_main(void){
    pick_candidate_preview(&g_approved_path_geometry);
    g_path_execution_report.magic=0x50544831U;g_path_execution_report.version=1;
    g_path_execution_report.phase=10;g_path_execution_report.error=PATH_BAD_CONFIG;
    /* No timer/PL/CAN access at boot. Calibration and GO remain all-zero BSS. */
    __asm__ volatile("dsb sy":::"memory");
}
void path_executor_service(void){
    path_runtime_request_t request;memcpy(&request,(const void *)&g_path_request,sizeof(request));
    if(service_busy){g_path_service_rejection=1;return;}
    if(!request.sequence || request.go!=PATH_HOST_GO){g_path_service_rejection=2;return;}
    if(request.sequence==consumed_request){g_path_service_rejection=3;return;}
    if(consumed_request && (g_path_execution_report.error==PATH_STOP_UNKNOWN ||
       (g_path_execution_report.enabled_mask&&!g_path_execution_report.stop_confirmed))){g_path_service_rejection=4;return;}
    service_busy=1;g_path_service_rejection=0;consumed_request=request.sequence;g_path_request.go=0;
    if(!path_config_valid(&request.config)){
        memset(&g_path_execution_report,0,sizeof(g_path_execution_report));
        g_path_execution_report.magic=0x50544831U;g_path_execution_report.version=1;
        g_path_execution_report.phase=0xe0;g_path_execution_report.error=PATH_BAD_CONFIG;
    }else{
        path_mailbox_context_t context={request.config.command_timeout_ms};path_io_t io=path_mailbox_io(&context);
        path_mailbox_initialize_timer();
        (void)path_execute_once(&request.config,&g_approved_path_geometry,&g_path_workspace,&io,&g_path_execution_report);
    }
    g_path_execution_report.consumed_request=request.sequence;
    service_busy=0;__asm__ volatile("dsb sy":::"memory");
}
