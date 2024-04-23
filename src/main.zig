const std = @import("std");
const gpio = @cImport({
    @cInclude("pigpio.h");
});
const zmq = @cImport({
    @cInclude("czmq.h");
});

fn button_callback(gpio_pin: c_int, level: c_int, ticks: u32) callconv(.C) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("interrupt gpio_pin {} level {} ticks {}", .{ gpio_pin, level, ticks }) catch return;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("program running", .{}) catch return;

    _ = zmq.zsock_new_push("inproc://example");

    _ = gpio.gpioInitialise();
    defer gpio.gpioTerminate();

    _ = gpio.gpioSetMode(3, gpio.PI_OUTPUT);
    _ = gpio.gpioWrite(3, 1);
    std.time.sleep(1_000_000_000);
    _ = gpio.gpioWrite(3, 0);
    std.time.sleep(1_000_000_000);
    _ = gpio.gpioWrite(3, 1);
    std.time.sleep(1_000_000_000);
    _ = gpio.gpioWrite(3, 0);

    _ = gpio.gpioSetMode(2, gpio.PI_INPUT);
    _ = gpio.gpioSetISRFunc(2, gpio.FALLING_EDGE, 0, button_callback);
    //std.time.sleep(20_000_000_000);

}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
