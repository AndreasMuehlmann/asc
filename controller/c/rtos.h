#ifndef __RTOS__
#define __RTOS__

#include <stdint.h>


void rtosVTaskDelayUntil(uint32_t *lastWake, uint32_t delay);
uint32_t rtosXTaskGetTickCount();
void rtosTaskYield();
void rtosXTaskCreate(void (*function)(void *), char *const name, const uint32_t stackSize, void *arguments, unsigned int priority);
void rtosVTaskDelay(uint32_t xTicksToDelay);
uint32_t rtosMillisToTicks(uint32_t millis);

#endif
