const std = @import("std");
const os = std.os;

const pigpio = @cImport(@cInclude("pigpio.h"));

const icmApi = @import("icm.zig");

pub fn sigIntHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});

    pigpio.gpioTerminate();

    std.process.exit(1);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    if (pigpio.gpioInitialise() < 0) {
        std.log.err("Failure in gpioInitialise.\n", .{});
        return error.PigpioInitialization;
    }

    const act = os.linux.Sigaction{
        .handler = .{ .handler = sigIntHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerCreation;
    }

    var icm = try icmApi.Icm.init(gpa.allocator(), icmApi.ADDR_L);
    while (true) {
        const angularVelocity = try icm.readGyro();
        std.debug.print("{d:.2}, {d:.2}, {d:.2}\n", .{ angularVelocity[0], angularVelocity[1], angularVelocity[2] });
        std.time.sleep(10_000_000);
    }
    defer icm.deinit();
}
