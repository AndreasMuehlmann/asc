#include "pwm.h"

#include "driver/ledc.h"
#include "esp_err.h"

ledc_timer_config_t ledc_timer;
ledc_channel_config_t ledc_channel;

void pwmInit() {
    ledc_timer.speed_mode = LEDC_LOW_SPEED_MODE;
    ledc_timer.timer_num = LEDC_TIMER_0;
    ledc_timer.duty_resolution = LEDC_TIMER_11_BIT;
    ledc_timer.freq_hz = 20000;
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
