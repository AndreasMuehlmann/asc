const std = @import("std");

const Controller = @import("controller.zig").Controller;
const UartConsole = @import("uartConsole.zig").UartConsole;

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");


const Config = @import("config.zig").Config;
const Bmi = @import("bmi.zig").Bmi;
const DistanceMeter = @import("distanceMeter.zig").DistanceMeter;
const NetServer = @import("netServer.zig").NetServer;

const rtos = @cImport(@cInclude("rtos.h"));
const utils = @cImport(@cInclude("utils.h"));
const i2c = @cImport(@cInclude("i2c.h"));
const pt = @cImport(@cInclude("pt.h"));

const c = @cImport({
    @cInclude("stdio.h");
});

const esp = @cImport({
    @cInclude("esp_system.h");
    @cInclude("esp_log.h");
    @cInclude("wifi.h");
    @cInclude("server.h");
    @cInclude("nvs_flash.h");
    @cInclude("driver/i2c_master.h");
    @cInclude("driver/ledc.h");
});

const pwm = @cImport(@cInclude("pwm.h"));
const tag = "app main";
var array: [250]u8 = undefined;

pub fn panic(msg: []const u8, _: ?*@import("std").builtin.StackTrace, _: ?usize) noreturn {
    utils.espLog(esp.ESP_LOG_ERROR, "panic handler", "PANIC: caused by: \"%s\" - timestamp: %ul\n", msg.ptr, esp.esp_log_timestamp());

    while (true) {
        asm volatile ("" ::: .{ .memory = true });
    }
}

export fn app_main() callconv(.c) void {
    const allocator = std.heap.raw_c_allocator;

    utils.espErrorCheck(esp.nvs_flash_init());

    var name = [_]u8{ 'u', 'a', 'r', 't', ' ', 'c', 'o', 'n', 's', 'o', 'l', 'e', 0 };
    rtos.rtosXTaskCreate(UartConsole.run, &name, 5000, null, 1);

    esp.wifi_init();

    var config = Config.init();

    pwm.pwmInit();
    utils.espLog(esp.ESP_LOG_INFO, tag, "Initialized motor control successfully");

    pt.ptInit();
    utils.espLog(esp.ESP_LOG_INFO, tag, "Initialized timer for measuring rotations successfully");

    var i2cBusHandle: esp.i2c_master_bus_handle_t = null;
    i2c.i2c_bus_init(&i2cBusHandle);
    const bmi = Bmi.init(&i2cBusHandle) catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Initializing bmi failed with error: %s", buffer.ptr);
        return;
    };
    utils.espLog(esp.ESP_LOG_INFO, tag, "Initialized IMU successfully");

    const distanceMeter = DistanceMeter.init(&config);

    var controller: Controller = undefined;

    const port: u16 = 8080;

    utils.espLog(esp.ESP_LOG_INFO, tag, "Waiting for connection...");
    const netServer = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
        allocator,
        port,
        &controller,
    ) catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Initializing controller failed with error: %s", buffer.ptr);
        return;
    };
    defer netServer.deinit();
    utils.espLog(esp.ESP_LOG_INFO, tag, "Client connected");

    controller = Controller.init(allocator, &config, bmi, distanceMeter, netServer) catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Initializing controller failed with error: %s", buffer.ptr);
        return;
    };
    controller.afterInit();
    defer controller.deinit();

    controller.run() catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Running controller failed with error: %s", buffer.ptr);
    };

    esp.esp_restart();
}
