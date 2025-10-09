const std = @import("std");

const Controller = @import("controller.zig").Controller;
const UartConsole = @import("uartConsole.zig").UartConsole;

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const NetServer = @import("netServer.zig").NetServer;

const c = @cImport({
    @cInclude("stdio.h");
});

const rtos = @cImport(@cInclude("rtos.h"));

const esp = @cImport({
    @cInclude("esp_system.h");
    @cInclude("esp_log.h");
    @cInclude("wifi.h");
    @cInclude("server.h");
});

const tag = "app main";
var array: [250]u8 = undefined;

pub fn panic(msg: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    esp.esp_log_write(esp.ESP_LOG_ERROR, "panic handler", "PANIC: caused by: \"%s\" - timestamp: %ul\n", msg.ptr, esp.esp_log_timestamp());

    while (true) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

export fn app_main() callconv(.c) void {
    const allocator = std.heap.raw_c_allocator;

    esp.wifi_init();

    var name = [_]u8{ 'u', 'a', 'r', 't', ' ', 'c', 'o', 'n', 's', 'o', 'l', 'e', 0 };
    rtos.rtosXTaskCreate(UartConsole.run, &name, 5000, null, 1);

    var controller: Controller = undefined;

    const port: u16 = 8080;
    const netServer = try NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
        allocator,
        port,
        &controller,
    );
    defer netServer.deinit();

    controller = Controller.init(allocator, netServer) catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Initializing controller failed with error: %s", buffer.ptr);
        return;
    };
    defer controller.deinit();

    controller.run() catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Running controller failed with error: %s", buffer.ptr);
    };

    esp.esp_restart();
}
