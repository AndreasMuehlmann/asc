#ifndef __UART_CONSOLE__
#define __UART_CONSOLE__

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define PORT_SERIAL_UART_CONVERTER 0
#define BUF_SIZE 1024

void uart_init(int port);
bool uart_data_available(int port);
int uart_read(int port, uint8_t buf[]);
int uart_write(int port, const uint8_t * const buf, size_t length);

#endif
