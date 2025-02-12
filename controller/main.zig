const std = @import("std");

const Controller = @import("controller.zig").Controller;

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
    esp.esp_log_write(esp.esp_log_get_default_level(), "panic_handler", "PANIC: caused by: \"%s\" - timestamp: %ul\n", msg.ptr, esp.esp_log_timestamp());

    while (true) {
        asm volatile ("" ::: "memory");
    }
}

export fn app_main() callconv(.C) void {
    const allocator = std.heap.raw_c_allocator;

    esp.wifi_init();

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
        const cString: [*c]const u8 = @ptrCast(buffer);
        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Initializing controller failed with error: %s", cString);
        return;
    };
    defer controller.deinit();

    controller.run() catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        const cString: [*c]const u8 = @ptrCast(buffer);
        esp.esp_log_write(esp.ESP_LOG_ERROR, tag, "Running controller failed with error: %s", cString);
    };

    esp.esp_restart();
}
