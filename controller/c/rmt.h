#ifndef __RMT__
#define __RMT__

#include <stddef.h>


void rmt_rx_init(void);
void rmt_rx_start(void);
void process_symbols(size_t num_symbols);
void rmt_rx_task(void *arg);

#endif
