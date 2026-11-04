#ifndef MOTION_MAILBOX_H
#define MOTION_MAILBOX_H
#include <stdint.h>
#include "mailbox_address.h"

enum {
    MB_ID=0x00, MB_VERSION=0x04, MB_CONTROL=0x08,
    MB_STAGE_WORD=0x10, MB_STAGE_LO=0x14, MB_STAGE_HI=0x18,
    MB_QUERY_SELECT=0x1c, MB_COMMAND_STATUS=0x20, MB_RESULT=0x24,
    MB_HEALTH=0x28, MB_FEEDBACK=0x2c, MB_RX_ERRORS=0x30,
    MB_RX_COUNT=0x34, MB_TX_STATUS=0x38, MB_ACCEPTED_COUNT=0x3c,
    MB_COMPLETED_COUNT=0x40, MB_REJECTED_COUNT=0x44,
    MB_RX_ISR=0x48, MB_RX_OVERFLOW=0x4c, MB_RECOVER=0x50
};
enum { MB_OK=0, MB_NOT_READY=-1, MB_BUSY=-2, MB_REJECTED=-3,
       MB_COMMAND_FAILED=-4, MB_WAIT_TIMEOUT=-5, MB_BAD_INPUT=-6 };
typedef struct { uint32_t status; uint32_t value; } motion_mailbox_result;

/* This library has no main(), startup hook, enable loop or automatic retry.
 * Caller must serialize all accesses and map this region as Device memory.
 * Probe/feedback reads do not issue CAN requests. submit_raw() explicitly does.
 */
uint32_t motion_mailbox_read(unsigned offset);
int motion_mailbox_probe(uint32_t *health);
int motion_mailbox_submit_raw(uint32_t word, uint32_t value_bits,
                              unsigned max_polls, motion_mailbox_result *out);
int motion_mailbox_select_feedback(unsigned axis, unsigned page);
void motion_mailbox_request_stop(void);
#endif
