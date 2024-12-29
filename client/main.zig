const std = @import("std");
const net = std.net;

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const stream = try net.tcpConnectToHost(allocator, "raspberrypi.fritz.box", 8080);
    defer stream.close();
    var reader = stream.reader();

    const file = try std.fs.cwd().createFile("measurements.csv", .{ .truncate = true });
    defer file.close();

    try file.writeAll("time,heading,roll,pitch\n");

    var buffer: [256]u8 = undefined;
    while (true) {
        const line = try reader.readUntilDelimiterOrEof(&buffer, '\n');
        if (line == null or line.?.len == 0) break;

        try file.writeAll(line.?);
        try file.writeAll("\n");
    }
}
