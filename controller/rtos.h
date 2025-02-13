#ifndef __RTOS__
#define __RTOS__

#include <stdint.h>

void rtosTaskYield();
void rtosXTaskCreate(void (*function)(void *), char *const name, const uint32_t stackSize, void *arguments, unsigned int priority);
void rtosVTaskDelay(uint32_t xTicksToDelay);
uint32_t rtosMillisToTicks(uint32_t millis);

#endif
