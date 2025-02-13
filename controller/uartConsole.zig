const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
});

const rtos = @cImport(@cInclude("rtos.h"));

const esp = @cImport({
    @cInclude("esp_log.h");
});

const tag = "uart console";
const backspace = 8;

pub const UartConsole = struct {
    const Self = @This();

    var buffer: [128]u8 = undefined;

    pub fn init() Self {
        return .{};
    }

    fn readLine() !usize {
        var index: usize = 0;
        while (index < buffer.len) : (rtos.rtosVTaskDelay(5)) {
            const char: c_int = c.getchar();
            if (char == 0 or char == 0xFF or char == '\r' or char == c.EOF) {
                continue;
            }
            if (char == '\n') {
                _ = c.printf("%c", char);
                buffer[index] = 0;
                break;
            }
            if (char == backspace and index > 0) {
                _ = c.printf("%c", char);
                index -= 1;
                continue;
            }
            if (index >= buffer.len - 1) {
                return error.CommandToLong;
            }
            _ = c.printf("%c", char);
            buffer[index] = @intCast(char);
            index += 1;
        }
        return index;
    }

    pub fn run(_: ?*anyopaque) callconv(.C) void {
        while (true) {
            const length = Self.readLine() catch |err| {
                const buf = std.fmt.bufPrintZ(&buffer, "{s}", .{@errorName(err)}) catch unreachable;
                esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "%s\n", buf.ptr);
                continue;
            };
            _ = c.printf("You entered: %s\n", buffer[0 .. length + 1].ptr);
        }
    }
};
