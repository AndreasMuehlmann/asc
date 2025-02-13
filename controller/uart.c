#include "uart.h"

#include <stdbool.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_log.h>
#include <esp_system.h>
#include <driver/uart.h>

#define BAUDRATE 9600

void uart_init(int port) {
    uart_config_t uart_config = {
        .baud_rate  = BAUDRATE,
        .data_bits  = UART_DATA_8_BITS,
        .parity     = UART_PARITY_DISABLE,
        .stop_bits  = UART_STOP_BITS_1,
        .flow_ctrl  = UART_HW_FLOWCTRL_DISABLE,
        .source_clk = UART_SCLK_DEFAULT,
    };
    ESP_ERROR_CHECK(uart_driver_install(port, BUF_SIZE * 2, 0, 0, NULL, 0));
    ESP_ERROR_CHECK(uart_param_config(port, &uart_config));
    ESP_ERROR_CHECK(uart_set_pin(port, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE));
}

bool uart_data_available(int port) {
    size_t size = 0;
    uart_get_buffered_data_len(port, &size);
    return size > 0;
}

int uart_read(int port, uint8_t buf[BUF_SIZE]) {
    int len = uart_read_bytes(port, buf, (BUF_SIZE - 1), 1);
    return len;
}

int uart_write(int port, const uint8_t *buf, size_t length) {
    return uart_write_bytes(port, buf, length);
}
