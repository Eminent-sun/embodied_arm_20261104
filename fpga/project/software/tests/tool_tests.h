#ifndef TOOL_TESTS_H
#define TOOL_TESTS_H
#include <stdint.h>
typedef struct {uint32_t id,passed;float error;} arm_tool_test_record_t;
typedef struct {
    uint32_t magic,version,complete,count,passed,failed,current_control_point_valid,motor_start_allowed;
    arm_tool_test_record_t records[64];
} arm_tool_test_report_t;
void arm_tool_offline_tests(arm_tool_test_report_t *report);
#endif
