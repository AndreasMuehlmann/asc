const std = @import("std");

pub fn main() !void {
    std.debug.print("Hello World!\n", .{});
}

test "simpleTest" {
    try std.testing.expect(true);
}
