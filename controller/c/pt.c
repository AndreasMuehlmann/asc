#include "driver/gpio.h"
#include "driver/gptimer.h"
#include "esp_attr.h"
#include "esp_err.h"
#include <stdio.h>

static volatile uint64_t startPeriod = 0;
static volatile uint64_t endPeriod = 0;
gptimer_handle_t timerHandle;


static void IRAM_ATTR pulse_isr(void *arg) {
    startPeriod = endPeriod;
    gptimer_get_raw_count(timerHandle, &endPeriod);
}

void ptInit() {
    gpio_config_t gpioConfig = {
        .pin_bit_mask = 1ULL << 6,
        .mode = GPIO_MODE_INPUT,
        .intr_type = GPIO_INTR_POSEDGE,
        .pull_up_en = GPIO_PULLUP_ENABLE,
    };

    ESP_ERROR_CHECK(gpio_config(&gpioConfig));

    ESP_ERROR_CHECK(gpio_install_isr_service(ESP_INTR_FLAG_IRAM));
    ESP_ERROR_CHECK(gpio_isr_handler_add(6, pulse_isr, NULL));

    gptimer_config_t timerConfig = {
        .clk_src = GPTIMER_CLK_SRC_DEFAULT,
        .direction = GPTIMER_COUNT_UP,
        .resolution_hz = 1 * 1000 * 1000,
    };
    ESP_ERROR_CHECK(gptimer_new_timer(&timerConfig, &timerHandle));
    ESP_ERROR_CHECK(gptimer_start(timerHandle));
}

float ptGetPeriod() {
    if (startPeriod == 0) {
        return 0.0;
    }
    
    return (float)(endPeriod - startPeriod) / 1e6;
}
