#ifndef PATH_MAILBOX_H
#define PATH_MAILBOX_H
#include "path_executor.h"
typedef struct {uint32_t command_timeout_ms;} path_mailbox_context_t;
void path_mailbox_initialize_timer(void);
path_io_t path_mailbox_io(path_mailbox_context_t *context);
int path_mailbox_recover(void *context);
#endif
