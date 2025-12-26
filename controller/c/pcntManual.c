#include "driver/gpio.h"
#include "esp_attr.h"
#include "esp_err.h"
#include <stdio.h>

static volatile int pulseCount = 0;

static void IRAM_ATTR pulse_isr(void *arg) {
    pulseCount++;
}

void pcntInit() {
    gpio_config_t cfg = {
        .pin_bit_mask = 1ULL << 6,
        .mode = GPIO_MODE_INPUT,
        .intr_type = GPIO_INTR_POSEDGE,
        .pull_up_en = GPIO_PULLUP_ENABLE,
    };

    ESP_ERROR_CHECK(gpio_config(&cfg));

    ESP_ERROR_CHECK(gpio_install_isr_service(ESP_INTR_FLAG_IRAM));
    ESP_ERROR_CHECK(gpio_isr_handler_add(6, pulse_isr, NULL));
}

void pcntStart() {}

int pcntGetCount() {
    return pulseCount;
}

void pcntReset() {
    pulseCount = 0;
}
