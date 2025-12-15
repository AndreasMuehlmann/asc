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

const utils = @cImport(@cInclude("utils.h"));

const bmi = @cImport({
    @cInclude("bmi.h");
    @cInclude("bmi2.h");
    @cInclude("bmi270.h");
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


    utils.espLog(esp.ESP_LOG_INFO, "controller", "Initing pwm");
    pwm.pwmInit();
    utils.espLog(esp.ESP_LOG_INFO, "controller", "setting duty");
    utils.espErrorCheck(esp.ledc_set_duty(esp.LEDC_LOW_SPEED_MODE, esp.LEDC_CHANNEL_0, 500));
    utils.espErrorCheck(esp.ledc_update_duty(esp.LEDC_LOW_SPEED_MODE, esp.LEDC_CHANNEL_0));
    utils.espLog(esp.ESP_LOG_INFO, "controller", "set dutj");
    

    var controller: Controller = undefined;

    const port: u16 = 8080;

    utils.espLog(esp.ESP_LOG_INFO, "main", "Starting server...");
    const netServer = try NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
        allocator,
        port,
        &controller,
    );
    defer netServer.deinit();
    utils.espLog(esp.ESP_LOG_INFO, "main", "Client connected");

    controller = Controller.init(allocator, netServer) catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Initializing controller failed with error: %s", buffer.ptr);
        return;
    };
    defer controller.deinit();

    controller.run() catch |err| {
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{@errorName(err)}) catch unreachable;
        utils.espLog(esp.ESP_LOG_ERROR, tag, "Running controller failed with error: %s", buffer.ptr);
    };

    esp.esp_restart();
}
