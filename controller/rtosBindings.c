#include "portmacro.h"
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>


void vTaskDelayMillis() {
    vTaskDelay(portTICK_PERIOD_MS())
}
