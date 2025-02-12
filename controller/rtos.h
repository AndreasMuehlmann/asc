#ifndef __RTOS__
#define __RTOS__

#include <stdint.h>

void rtosVTaskDelay(uint32_t xTicksToDelay);
uint32_t rtosMillisToTicks(uint32_t millis);

#endif
