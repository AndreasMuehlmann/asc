#include <stdint.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include "rtos.h"
#include "portmacro.h"


void rtosVTaskDelay(uint32_t xTicksToDelay) {
    vTaskDelay(xTicksToDelay);
}

uint32_t rtosMillisToTicks(uint32_t millis) {
    return millis / portTICK_PERIOD_MS;
}
