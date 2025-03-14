const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
});

const rtos = @cImport(@cInclude("rtos.h"));

const esp = @cImport({
    @cInclude("nvs.h");
    @cInclude("nvs_flash.h");
    @cInclude("esp_log.h");
    @cInclude("esp_system.h");
});

const commandParserMod = @import("commandParser");
const CommandParser = commandParserMod.CommandParser;

const tag = "uart console";
const backspace = 8;

const CommandsEnum = enum {
    set,
    restart,
};

const commands = union(CommandsEnum) {
    set: set,
    restart: restart,
};

const restart = struct {};

const set = struct {
    ssid: []const u8,
    password: []const u8,
};

pub const UartConsole = struct {
    const Self = @This();

    var buffer: [256]u8 = undefined;

    pub fn init() Self {
        return .{};
    }

    fn readLine() !usize {
        var index: usize = 0;
        while (index < buffer.len) : (rtos.rtosVTaskDelay(1)) {
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

    // TODO: get allocator from anyopaque pointer
    pub fn run(_: ?*anyopaque) callconv(.C) void {
        const descriptions: []const commandParserMod.FieldDescription = &.{
            .{ .fieldName = "ssid", .description = "The name of the wlan to connect to." },
            .{ .fieldName = "password", .description = "The passowrd for the wlan to connect to." },
        };

        var nvsHandle: esp.nvs_handle_t = undefined;
        const nvs_err = esp.nvs_open("storage", esp.NVS_READWRITE, &nvsHandle);
        if (nvs_err != esp.ESP_OK) {
            esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Error opening flash memory handle: %s", esp.esp_err_to_name(nvs_err));
            @panic("Error while opening handle for flash memory in uart console.");
        }
        defer esp.nvs_close(nvsHandle);

        const commandParserT: type = CommandParser(commands, descriptions);
        while (true) {
            const length = Self.readLine() catch |err| {
                const buf = std.fmt.bufPrintZ(&buffer, "{s}", .{@errorName(err)}) catch unreachable;
                esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "%s\n", buf.ptr);
                continue;
            };

            var commandParser = commandParserT.init(std.heap.raw_c_allocator, buffer[0..length]);
            const command = commandParser.parse() catch |err| {
                var message: []const u8 = undefined;
                if (commandParser.message.len == 0) {
                    message = std.fmt.allocPrintZ(std.heap.raw_c_allocator, "{s}\n", .{@errorName(err)}) catch unreachable;
                } else {
                    message = std.fmt.allocPrintZ(std.heap.raw_c_allocator, "{s}\n", .{commandParser.message}) catch unreachable;
                }
                _ = c.printf(message.ptr);
                std.heap.raw_c_allocator.free(message);
                continue;
            };

            switch (command) {
                CommandsEnum.set => |setCmd| {
                    const nullTerminatedSsid = std.fmt.bufPrintZ(&buffer, "{s}", .{setCmd.ssid}) catch unreachable;
                    const nullTerminatedPassword = std.fmt.bufPrintZ(buffer[@divTrunc(buffer.len, 2)..], "{s}", .{setCmd.password}) catch unreachable;
                    _ = c.printf("Set ssid to %s and password to %s\n", nullTerminatedSsid.ptr, nullTerminatedPassword.ptr);

                    var err = esp.nvs_set_str(nvsHandle, "ssid", nullTerminatedSsid);
                    if (err != esp.ESP_OK) {
                        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Error setting ssid: %s", esp.esp_err_to_name(err));
                        continue;
                    }
                    err = esp.nvs_set_str(nvsHandle, "password", nullTerminatedPassword);
                    if (err != esp.ESP_OK) {
                        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Error setting password: %s", esp.esp_err_to_name(err));
                        continue;
                    }
                    err = esp.nvs_commit(nvsHandle);
                    if (err != esp.ESP_OK) {
                        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Error commiting ssid and password to flash memory: %s", esp.esp_err_to_name(err));
                    }
                },
                CommandsEnum.restart => |_| {
                    esp.esp_restart();
                },
            }
        }
    }
};
