#include "pwm.h"

#include "driver/ledc.h"
#include "esp_err.h"
#include "hal/ledc_types.h"

ledc_timer_config_t ledc_timer;
ledc_channel_config_t ledc_channel;

void pwmInit() {
    ledc_timer.speed_mode = LEDC_LOW_SPEED_MODE; // HIGH SPEED MODE not available, so low freq and resolution
    ledc_timer.timer_num = LEDC_TIMER_0;
    ledc_timer.duty_resolution = LEDC_TIMER_10_BIT;
    ledc_timer.freq_hz = 1000;
    ledc_timer.clk_cfg = LEDC_AUTO_CLK;
    ESP_ERROR_CHECK(ledc_timer_config(&ledc_timer));

    ledc_channel.gpio_num = 3;
    ledc_channel.speed_mode = LEDC_LOW_SPEED_MODE;
    ledc_channel.channel = LEDC_CHANNEL_0;
    ledc_channel.timer_sel = LEDC_TIMER_0;
    ledc_channel.duty = 0;
    ledc_channel.hpoint = 0;
    ledc_channel.intr_type = LEDC_INTR_DISABLE;
    ESP_ERROR_CHECK(ledc_channel_config(&ledc_channel));
}

void setDuty(uint32_t duty) {
    ESP_ERROR_CHECK(ledc_set_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0, duty));
    ESP_ERROR_CHECK(ledc_update_duty(LEDC_LOW_SPEED_MODE, LEDC_CHANNEL_0));
}
