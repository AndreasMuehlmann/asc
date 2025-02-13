const uart = @cImport(@cInclude("uart.h"));

const esp = @cImport({
    @cInclude("esp_log.h");
});

const tag = "uart console";

pub const UartConsole = struct {
    const Self = @This();

    var buffer: [uart.BUF_SIZE]u8 = undefined;

    pub fn init() Self {
        uart.uart_init(uart.PORT_SERIAL_UART_CONVERTER);
        return .{};
    }

    pub fn run(_: ?*anyopaque) callconv(.C) void {
        while (true) {
            if (!uart.uart_data_available(uart.PORT_SERIAL_UART_CONVERTER)) {}
            const string = "Hello from esp32 uart console!!\n";
            @memcpy(buffer[0..string.len], string);
            const result = uart.uart_write(uart.PORT_SERIAL_UART_CONVERTER, &buffer, string.len);
            if (result < 0) {
                esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Uart write failed\n");
            }
            if (result < string.len) {
                esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Less bytes written: only %d not %d\n", result, string.len);
            }
        }
    }
};
