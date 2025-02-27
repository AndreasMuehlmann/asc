const std = @import("std");

const c = @cImport({
    @cInclude("stdio.h");
});

const rtos = @cImport(@cInclude("rtos.h"));

const esp = @cImport({
    @cInclude("esp_log.h");
});

const commandParserMod = @import("commandParser");
const CommandParser = commandParserMod.CommandParser;

const tag = "uart console";
const backspace = 8;

const CommandsEnum = enum {
    set,
    someCommand,
};

const commands = union(CommandsEnum) {
    set: set,
    someCommand: someCommand,
};

const someCommand = struct {};

const set = struct {
    ssid: []const u8,
    password: []const u8,
};

pub const UartConsole = struct {
    const Self = @This();

    var buffer: [128]u8 = undefined;

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
                    const nullTerminatedSsid = std.fmt.allocPrintZ(std.heap.raw_c_allocator, "{s}", .{setCmd.ssid}) catch unreachable;
                    defer std.heap.raw_c_allocator.free(nullTerminatedSsid);
                    const nullTerminatedPassword = std.fmt.allocPrintZ(std.heap.raw_c_allocator, "{s}", .{setCmd.password}) catch unreachable;
                    defer std.heap.raw_c_allocator.free(nullTerminatedPassword);
                    _ = c.printf("Set ssid to %s and password to %s\n", nullTerminatedSsid.ptr, nullTerminatedPassword.ptr);
                },
                CommandsEnum.someCommand => |_| {
                    _ = c.printf("Doing something\n");
                },
            }
        }
    }
};
