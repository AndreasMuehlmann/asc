#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_log.h"

#include "driver/rmt_rx.h"


#define RMT_RX_GPIO        6
#define RMT_RESOLUTION_HZ  10000   // 2 MHz → 0.5 µs / tick

#define RX_SYMBOLS        64


static const char *TAG = "RMT_PERIOD";

static rmt_channel_handle_t rx_chan = NULL;
static rmt_symbol_word_t rx_symbols[RX_SYMBOLS];

static QueueHandle_t rx_queue;


typedef struct {
    size_t num_symbols;
} rmt_rx_event_t;


static bool rmt_rx_done_cb(rmt_channel_handle_t channel,
                           const rmt_rx_done_event_data_t *edata,
                           void *user_data)
{
    BaseType_t high_task_wakeup = pdFALSE;

    rmt_rx_event_t evt = {
        .num_symbols = edata->num_symbols,
    };

    xQueueSendFromISR(rx_queue, &evt, &high_task_wakeup);

    return high_task_wakeup == pdTRUE;
}

void rmt_rx_init(void)
{
    rx_queue = xQueueCreate(4, sizeof(rmt_rx_event_t));

    rmt_rx_channel_config_t rx_cfg = {
        .gpio_num = RMT_RX_GPIO,
        .clk_src = RMT_CLK_SRC_DEFAULT,
        .resolution_hz = RMT_RESOLUTION_HZ,
        .mem_block_symbols = RX_SYMBOLS,
        .flags.invert_in = false,
        .flags.with_dma = false,
    };

    ESP_ERROR_CHECK(rmt_new_rx_channel(&rx_cfg, &rx_chan));

    rmt_rx_event_callbacks_t cbs = {
        .on_recv_done = rmt_rx_done_cb,
    };

    ESP_ERROR_CHECK(rmt_rx_register_event_callbacks(rx_chan, &cbs, NULL));
    ESP_ERROR_CHECK(rmt_enable(rx_chan));

    ESP_LOGI(TAG, "RMT RX initialized");
}

void rmt_rx_start(void)
{
    rmt_receive_config_t cfg = {
        .signal_range_min_ns = 1000,
        .signal_range_max_ns = 100 * 1000 * 1000,
    };

    ESP_ERROR_CHECK(
        rmt_receive(rx_chan,
                    rx_symbols,
                    sizeof(rx_symbols),
                    &cfg)
    );
}

void process_symbols(size_t num_symbols)
{
    const float tick_us = 1e6f / RMT_RESOLUTION_HZ;

    for (size_t i = 0; i < num_symbols; i++) {
        uint32_t t0 = rx_symbols[i].duration0;
        uint32_t t1 = rx_symbols[i].duration1;

        if (t0 == 0 || t1 == 0) {
            continue;
        }

        float period_us = (t0 + t1) * tick_us;

        ESP_LOGI(TAG,
                 "Period: %.2f us (lvl0=%d lvl1=%d), num_symbols: %zu",
                 period_us,
                 rx_symbols[i].level0,
                 rx_symbols[i].level1,
                 num_symbols);
    }
}

void rmt_rx_task(void *arg)
{
    rmt_rx_event_t evt;

    while (1) {
        rmt_rx_start();

        if (xQueueReceive(rx_queue, &evt, portMAX_DELAY)) {
            process_symbols(evt.num_symbols);
        }
    }
}
