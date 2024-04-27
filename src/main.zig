const std = @import("std");

const gpio = @cImport({
    @cInclude("pigpio.h");
});

const zmq_server = @import("zmq_server.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        if (gpa.deinit() == .leak)
            @panic("Memory leaked");
    }
    const allocator = gpa.allocator();

    var server = try zmq_server.ZmqServer.init(allocator);
    defer server.deinit();

    while (true) {
        {
            var frame = server.recv() catch |err| {
                std.log.err("{}", .{err});
                continue;
            };
            defer frame.deinit();
            var msg = frame.data() catch |err| {
                std.log.err("{}", .{err});
                continue;
            };
            std.log.info("{s}", .{msg});
        }
        std.time.sleep(std.time.ns_per_s);
        server.send("World") catch |err| {
            std.log.err("{}", .{err});
            continue;
        };
    }
}
