const std = @import("std");
const zigpio = @import("zigpio").GPIO;

// use LED attached to BCM pin #17
const LED_PIN: zigpio.Pin = zigpio.Pin.fromBCM(17);

pub fn main() !void {
    const gpio = try zigpio.init();
    defer gpio.deinit();

    try gpio.setMode(LED_PIN, zigpio.Mode.Output);

    // Blink!
    while (true) {
        std.debug.print("Blink on\n", .{});
        try gpio.write(LED_PIN, zigpio.Level.High);
        std.time.sleep(std.time.ns_per_s * 1);

        std.debug.print("Blink off\n", .{});
        try gpio.write(LED_PIN, zigpio.Level.Low);
        std.time.sleep(std.time.ns_per_s * 1);
    }
}
