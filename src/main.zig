const std = @import("std");
const pigpio = @cImport({
    @cInclude("/home/andi/programming/nlslotter/libs/pigpio/pigpio.h");
});

pub fn main() !void {
    _ = pigpio.gpioInitialise();
    defer pigpio.gpioTerminate();

    _ = pigpio.gpioSetMode(18, pigpio.PI_OUTPUT);
    _ = pigpio.gpioWrite(18, 1);

    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush();
}
