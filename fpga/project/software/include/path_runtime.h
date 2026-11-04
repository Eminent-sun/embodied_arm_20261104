#ifndef PATH_RUNTIME_H
#define PATH_RUNTIME_H
#include "path_executor.h"
typedef struct {uint32_t sequence,go;path_config_t config;} path_runtime_request_t;
extern volatile path_runtime_request_t g_path_request;
extern path_execution_report_t g_path_execution_report;
extern uint32_t g_path_service_rejection;
/* Explicit, one call per new request. Startup never invokes this service. */
void path_executor_service(void);
#endif
