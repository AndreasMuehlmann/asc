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
        const radiansPerSecond = try icm.readGyro();
        std.debug.print("gyro: {d:.2}, {d:.2}, {d:.2}\n", .{ radiansPerSecond[0], radiansPerSecond[1], radiansPerSecond[2] });

        const meterPerSecondSquared = try icm.readAccel();
        std.debug.print("accl: {d:.2}, {d:.2}, {d:.2}\n", .{ meterPerSecondSquared[0], meterPerSecondSquared[1], meterPerSecondSquared[2] });

        const magneticFluxDensityMicro = try icm.readMag();
        std.debug.print("mag: {d:.2}, {d:.2}, {d:.2}\n", .{ magneticFluxDensityMicro[0], magneticFluxDensityMicro[1], magneticFluxDensityMicro[2] });

        std.time.sleep(10_000_000);
    }
    defer icm.deinit();
}
