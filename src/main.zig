const std = @import("std");
const gpio = @cImport({
    @cInclude("/home/andi/programming/nlslotter/libs/pigpio/pigpio.h");
});

fn button_callback(gpio_pin: c_int, level: c_int, ticks: u32) callconv(.C) void {
    const stdout = std.io.getStdOut().writer();
    stdout.print("interrupt gpio_pin {} level {} ticks {}", .{ gpio_pin, level, ticks }) catch return;
}

pub fn main() !void {
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
    std.time.sleep(30_000_000_000);
}
