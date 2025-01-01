const std = @import("std");
const os = std.os;
const net = std.net;

const pigpio = @cImport(@cInclude("pigpio.h"));

const PigpioError = error{
    InitializationError,
};

const Bno = @import("bno.zig").Bno;

pub fn signalForcingExitHandler(sig: c_int) callconv(.C) void {
    _ = sig;

    std.log.warn("Received signal to exit.\n", .{});
    pigpio.gpioTerminate();
    std.process.exit(1);
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    if (pigpio.gpioInitialise() < 0) {
        std.log.err("Failure in gpioInitialise.\n", .{});
        return PigpioError.InitializationError;
    }
    defer pigpio.gpioTerminate();

    const act = os.linux.Sigaction{
        .handler = .{ .handler = signalForcingExitHandler },
        .mask = os.linux.empty_sigset,
        .flags = 0,
    };

    if (os.linux.sigaction(os.linux.SIG.INT, &act, null) != 0) {
        return error.SignalHandlerError;
    }

    const bno = try Bno.init(allocator);

    const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8080);
    var server = try address.listen(.{});
    defer server.deinit();

    const start = std.time.milliTimestamp();
    while (true) {
        const connection = try server.accept();
        while (true) {
            const euler = try bno.getEuler();
            const buffer = try std.fmt.allocPrint(allocator, "{d},{d:.2},{d:.2},{d:.2}\n", .{ std.time.milliTimestamp() - start, euler.heading, euler.roll, euler.pitch });
            try connection.stream.writeAll(buffer);
            allocator.free(buffer);
        }
        std.time.sleep(200_000_000);
    }
}
