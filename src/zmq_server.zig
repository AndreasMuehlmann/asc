const std = @import("std");
const zzmq = @import("zzmq");

pub const ZmqServer = struct {
    allocator: std.mem.Allocator,
    context: *zzmq.ZContext,
    socket: *zzmq.ZSocket,

    pub fn init(allocator: std.mem.Allocator) !ZmqServer {
        std.log.info("Starting the server...", .{});
        {
            const version = zzmq.ZContext.version();
            std.log.info("libzmq version: {}.{}.{}", .{ version.major, version.minor, version.patch });
        }
        var context = try zzmq.ZContext.init(allocator);
        var socket = try zzmq.ZSocket.init(zzmq.ZSocketType.Rep, &context);
        try socket.bind("tcp://*:5555");

        return .{
            .allocator = allocator,
            .context = &context,
            .socket = socket,
        };
    }

    pub fn recv(self: *ZmqServer) !zzmq.ZMessageReceived {
        return try self.socket.receive(.{});
    }

    pub fn send(self: *ZmqServer, string: []const u8) !void {
        var msg = try zzmq.ZMessage.initUnmanaged(string, null);
        defer msg.deinit();

        try self.socket.send(&msg, .{});
    }

    pub fn deinit(self: *ZmqServer) void {
        self.context.deinit();
        self.socket.deinit();
    }
};
