#include <stdint.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "rtos.h"
#include "portmacro.h"


void rtosTaskYield() {
    taskYIELD();
}


void rtosXTaskCreate(void (*function)(void *), char *const name, const uint32_t stackSize, void *arguments, unsigned int priority) {
    xTaskCreate(function, name, stackSize, arguments, priority, NULL);
}

void rtosVTaskDelay(uint32_t xTicksToDelay) {
    vTaskDelay(xTicksToDelay);
}

uint32_t rtosMillisToTicks(uint32_t millis) {
    return millis / portTICK_PERIOD_MS;
}
