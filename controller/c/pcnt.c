#include "esp_err.h"
#include "driver/pulse_cnt.h"


pcnt_unit_handle_t pcntUnit;

void pcntInit() {
    pcnt_unit_config_t unitConfig = {
        .high_limit = 32767,
        .low_limit = -1,
    };
    ESP_ERROR_CHECK(pcnt_new_unit(&unitConfig, &pcntUnit));

    pcnt_chan_config_t channelConfig = {
        .edge_gpio_num = 9,
        .level_gpio_num = -1,
    };

    pcnt_channel_handle_t pcntChannel;
    ESP_ERROR_CHECK(pcnt_new_channel(pcntUnit, &channelConfig, &pcntChannel));

    ESP_ERROR_CHECK(pcnt_channel_set_edge_action(
        pcntChannel,
        PCNT_CHANNEL_EDGE_ACTION_INCREASE,
        PCNT_CHANNEL_EDGE_ACTION_HOLD
    ));

    ESP_ERROR_CHECK(pcnt_unit_enable(pcntUnit));
}

int pcntGetCount() {
    int pulseCount = 0;
    ESP_ERROR_CHECK(pcnt_unit_get_count(pcntUnit, &pulseCount));
    return pulseCount;
}

void pcntReset() {
    ESP_ERROR_CHECK(pcnt_unit_clear_count(pcntUnit));
}

void pcntStart() {
    ESP_ERROR_CHECK(pcnt_unit_start(pcntUnit));
}
