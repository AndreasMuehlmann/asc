const std = @import("std");
const net = std.net;

const decode = @import("decode");
const clientContract = @import("clientContract");

const allocator = std.heap.page_allocator;

const Handler = struct {
    file: std.fs.File,

    const Self = @This();

    pub fn handleOrientation(self: *Self, orientation: clientContract.Orientation) !void {
        const message = try std.fmt.allocPrint(allocator, "{d},{d},{d},{d}\n", .{ orientation.time, orientation.heading, orientation.roll, orientation.pitch });
        try self.file.writeAll(message);
        allocator.free(message);
    }
};

pub fn main() !void {
    const stream = try net.tcpConnectToHost(allocator, "raspberrypi.fritz.box", 8080);
    defer stream.close();
    var reader = stream.reader();

    const file = try std.fs.cwd().createFile("measurements.csv", .{ .truncate = true });
    defer file.close();

    try file.writeAll("time,heading,roll,pitch\n");

    var decoder = decode.Decoder(clientContract.ClientContractEnum, clientContract.ClientContract, Handler).init(allocator, .{ .file = file });
    var buffer: [256]u8 = undefined;
    while (true) {
        const bytesRead = try reader.read(&buffer);
        if (bytesRead == 0) {
            std.log.warn("connection closed", .{});
            return;
        }
        try decoder.decode(buffer[0..bytesRead]);
    }
}
