const std = @import("std");
const os = std.os;

const pigpio = @cImport(@cInclude("pigpio.h"));
const Controller = @import("controller.zig").Controller;
const NetServer = @import("netServer.zig").NetServer;

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");

var controller: Controller = undefined;
var isControllerCreated: bool = false;

pub fn sigIntHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});

    if (isControllerCreated) {
        controller.deinit();
    }
    pigpio.gpioTerminate();

    std.process.exit(1);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    if (pigpio.gpioInitialise() < 0) {
        std.log.err("Failure in gpioInitialise.\n", .{});
        return error.PigpioInitialization;
    }
    defer pigpio.gpioTerminate();

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }

    const netServer = try NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract).init(
        allocator,
        8080,
        &controller,
    );

    controller = try Controller.init(allocator, netServer);
    isControllerCreated = true;
    defer controller.deinit();

    try controller.run();
}
