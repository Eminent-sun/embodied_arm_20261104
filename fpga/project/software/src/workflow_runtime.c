#include "workflow_runtime.h"
#include "path_mailbox.h"
#include "gripper.h"
#include <string.h>
volatile workflow_request_t g_arm_request;
volatile uint32_t g_arm_heartbeat,g_arm_stop;
workflow_reply_t g_arm_reply;
workflow_record_t g_arm_calibration;
workflow_report_t g_arm_report;
workflow_stop_trace_t g_arm_stop_trace;
workflow_cartesian_report_t g_arm_cartesian;
workflow_timing_t g_arm_timing;
workflow_readback_t g_arm_readback[6];
workflow_pose_record_t g_initial_pose;
pick_candidate_report_t g_approved_path_geometry;
arm_workflow_t g_arm_workflow;
static path_plan_t workspace;
static path_mailbox_context_t context;
static path_io_t raw_io,guarded_io;
static uint32_t consumed_request,heartbeat_value,heartbeat_time,timer_started;
_Static_assert(sizeof(workflow_record_t)==468,"Calibration record ABI");
_Static_assert(sizeof(workflow_request_t)==836,"Host request ABI");
_Static_assert(sizeof(workflow_report_t)==120,"Status ABI");
_Static_assert(sizeof(workflow_stop_trace_t)==112,"Stop trace ABI");
_Static_assert(sizeof(workflow_timing_t)==64,"Timing trace ABI");
_Static_assert(sizeof(workflow_cartesian_input_t)==40,"Cartesian request payload ABI");
_Static_assert(sizeof(workflow_cartesian_report_t)==144,"Cartesian report ABI");
_Static_assert(sizeof(workflow_pose_record_t)==116,"Raw pose record ABI");
static int host_alive(void){
    uint32_t time=raw_io.now_ms(raw_io.context);
    if(g_arm_heartbeat!=heartbeat_value){heartbeat_value=g_arm_heartbeat;heartbeat_time=time;}
    int alive=time-heartbeat_time<1000 && !g_arm_stop;
    if(g_gripper_report.present)gripper_service(time,alive && g_arm_workflow.report.state!=WF_FAULT);
    return alive;
}
static int healthy(void *unused){(void)unused;return host_alive()&&raw_io.healthy(raw_io.context);}
static uint32_t now(void *unused){(void)unused;return raw_io.now_ms(raw_io.context);}
static int transaction(void *unused,uint32_t word,uint32_t value,uint32_t *out){(void)unused;
    if(!host_alive())return -1;
    return raw_io.transaction(raw_io.context,word,value,out);}
static uint32_t page(void *unused,unsigned axis,unsigned p){(void)unused;return raw_io.feedback_page(raw_io.context,axis,p);}
static void emergency(void *unused){(void)unused;raw_io.emergency_stop(raw_io.context);}
static void initialize_read_io(void){
    if(!timer_started){context.command_timeout_ms=50;raw_io=path_mailbox_io(&context);path_mailbox_initialize_timer();timer_started=1;
        heartbeat_value=g_arm_heartbeat;heartbeat_time=raw_io.now_ms(raw_io.context);}
}
void compute_main(void){
    /* Geometry is now an explicit, inactive-only PREVIEW operation. Recording
     * and holding a raw initial pose needs no IK or Cartesian trajectory. */
    gripper_init();
    g_approved_path_geometry.magic=0x50494331U;g_approved_path_geometry.version=1;
    guarded_io=(path_io_t){0,now,healthy,transaction,page,emergency};
    workflow_init(&g_arm_workflow,&guarded_io,&g_approved_path_geometry,&workspace,0);
    g_arm_report=g_arm_workflow.report;
    g_arm_cartesian.magic=0x43505231U;g_arm_cartesian.version=1;g_arm_cartesian.model_only=1;
    /* BSS request, GO, heartbeat and real calibration all remain zero. No
     * timer, CAN, mailbox, SD, flash or network access during startup. */
}
void workflow_runtime_poll(void){
    if(timer_started&&g_arm_workflow.report.active_mask)workflow_tick(&g_arm_workflow,host_alive());
    if(timer_started&&g_gripper_report.present)(void)host_alive();
    if(g_arm_request.go==WF_GO){
        workflow_request_t request;uint32_t sequence=g_arm_request.sequence;
        __asm__ volatile("dsb sy":::"memory");memcpy(&request,(const void *)&g_arm_request,sizeof(request));
        if(sequence!=g_arm_request.sequence)return;
        g_arm_request.go=0;g_arm_reply.busy=1;int rc;
        if(!sequence||sequence<=consumed_request)rc=WF_REPLAY;
        else{
            consumed_request=sequence;
            if(request.crc32!=workflow_crc32(&request,offsetof(workflow_request_t,crc32)))rc=WF_BAD_RECORD;
            else if(request.operation==WF_GRIPPER){
                gripper_request_t input;memcpy(&input,&request.record,sizeof(input));
                int valid=request.axis==0&&request.reference_joint_rad==0;
                const unsigned char *bytes=(const unsigned char *)&request;
                for(unsigned i=offsetof(workflow_request_t,config);i<offsetof(workflow_request_t,record);++i)if(bytes[i])valid=0;
                for(unsigned i=offsetof(workflow_request_t,record)+sizeof(input);i<offsetof(workflow_request_t,crc32);++i)if(bytes[i])valid=0;
                if(!valid)rc=GRIP_BAD_INPUT;
                else{initialize_read_io();rc=gripper_command(&input,raw_io.now_ms(raw_io.context),host_alive() && g_arm_workflow.report.state!=WF_FAULT);}
                g_gripper_report.sequence=sequence;g_gripper_report.error=(unsigned)rc;
            }
            else if(request.operation==WF_CONFIGURE)rc=workflow_configure(&g_arm_workflow,&request.config);
            else if(request.operation==WF_RESTORE)rc=workflow_restore(&g_arm_workflow,&request.record);
            else if(request.operation==WF_RECOVER){
                const unsigned char *bytes=(const unsigned char *)&request;
                int valid=request.axis==0&&request.reference_joint_rad==0;
                for(unsigned i=offsetof(workflow_request_t,config);i<offsetof(workflow_request_t,crc32);++i)if(bytes[i])valid=0;
                if(!valid)rc=WF_BAD_RECORD;
                else if(!timer_started||g_arm_workflow.report.state!=WF_FAULT)rc=WF_BAD_STATE;
                else{
                    /* This explicit request acknowledges the previous STOP;
                     * a new STOP or stale heartbeat still aborts recovery. */
                    g_arm_stop=0;
                    rc=workflow_recover(&g_arm_workflow,path_mailbox_recover,&context);
                    if(!rc){memset(&g_initial_pose,0,sizeof(g_initial_pose));
                        g_arm_cartesian.plan_valid=0;g_arm_cartesian.frames=0;g_arm_cartesian.duration_ms=0;}
                }
            }
            else if(request.operation==WF_CHECKPOSE||request.operation==WF_MOVETO){
                workflow_cartesian_input_t input;memcpy(&input,&request.record,sizeof(input));
                int valid=input.magic==WF_CARTESIAN_MAGIC&&input.version==1&&input.base_frame==1&&input.rpy_degrees==1&&request.axis==0&&request.reference_joint_rad==0;
                const unsigned char *payload=(const unsigned char *)&request.record;
                const unsigned char *config=(const unsigned char *)&request.config;
                for(unsigned i=sizeof(input);i<sizeof(request.record);++i)if(payload[i])valid=0;
                for(unsigned i=0;i<sizeof(request.config);++i)if(config[i])valid=0;
                if(!valid){memset(&g_arm_cartesian,0,sizeof(g_arm_cartesian));g_arm_cartesian.magic=0x43505231U;g_arm_cartesian.version=1;g_arm_cartesian.model_only=1;rc=WF_BAD_RECORD;}
                else rc=workflow_cartesian(&g_arm_workflow,&input.pose,&g_arm_cartesian,request.operation==WF_MOVETO);
                g_arm_cartesian.sequence=sequence;g_arm_cartesian.error=(unsigned)rc;
            }
            else if(request.operation==WF_GOHOME)rc=workflow_go_home(&g_arm_workflow);
            else if(request.operation==WF_PREVIEW){
                if(g_arm_workflow.report.active_mask||g_arm_workflow.report.state==WF_FAULT)rc=WF_BAD_STATE;
                else{pick_candidate_preview(&g_approved_path_geometry);rc=g_approved_path_geometry.math_passed?0:PATH_BAD_GEOMETRY;}
            }
            else if(request.operation==WF_CAPTURE_POSE){
                initialize_read_io();rc=workflow_capture_pose(&g_arm_workflow,&g_initial_pose);
            }
            else if(request.operation==WF_RESTORE_POSE||request.operation==WF_HOLD_POSE){
                workflow_pose_record_t pose;memcpy(&pose,&request.record,sizeof(pose));
                const unsigned char *bytes=(const unsigned char *)&request.record;int padding_ok=1;
                for(unsigned i=sizeof(pose);i<sizeof(request.record);++i)if(bytes[i])padding_ok=0;
                if(!padding_ok||!workflow_pose_valid(&pose))rc=WF_BAD_RECORD;
                else if(request.operation==WF_RESTORE_POSE){rc=workflow_restore_pose(&g_arm_workflow,&pose);if(!rc)g_initial_pose=pose;}
                else if(memcmp(&pose,&g_initial_pose,sizeof(pose)))rc=WF_BAD_RECORD;
                else{initialize_read_io();rc=workflow_hold_pose(&g_arm_workflow,&pose);}
            }
            else if(request.operation==WF_READ){
                initialize_read_io();
                rc=workflow_read_parameters(&g_arm_workflow,g_arm_readback);
            }
            else if((request.operation==WF_BEGIN||request.operation==WF_RESUME)&&g_arm_workflow.report.state==WF_CONFIGURED){
                initialize_read_io();
                context.command_timeout_ms=g_arm_workflow.record.config.command_timeout_ms;
                rc=workflow_command(&g_arm_workflow,request.operation,0,0);
            }else if(!timer_started)rc=WF_BAD_STATE;
            else rc=workflow_command(&g_arm_workflow,request.operation,request.axis,request.reference_joint_rad);
        }
        g_arm_calibration=g_arm_workflow.record;g_arm_report=g_arm_workflow.report;g_arm_stop_trace=g_arm_workflow.stop_trace;g_arm_timing=g_arm_workflow.timing;
        __asm__ volatile("dsb sy":::"memory");
        g_arm_reply.error=(uint32_t)rc;g_arm_reply.operation=request.operation;g_arm_reply.busy=0;
        g_arm_reply.completed_sequence=sequence;
    }
    g_arm_calibration=g_arm_workflow.record;g_arm_report=g_arm_workflow.report;g_arm_stop_trace=g_arm_workflow.stop_trace;g_arm_timing=g_arm_workflow.timing;
    __asm__ volatile("dsb sy":::"memory");
}
