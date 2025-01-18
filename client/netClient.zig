const std = @import("std");
const net = std.net;

const decode = @import("decode");
const encode = @import("encode");

pub fn NetClient(comptime contractEnumT: type, comptime contractT: type, comptime handlerT: type) type {
    return struct {
        allocator: std.mem.Allocator,
        stream: std.net.Stream,
        decoder: decode.Decoder(contractEnumT, contractT, handlerT),

        const encoder = encode.Encoder(contractT);

        const Self = @This();
        var buffer: [256]u8 = undefined;

        pub fn init(allocator: std.mem.Allocator, host: []const u8, port: u16, handler: *handlerT) !Self {
            const stream = try net.tcpConnectToHost(allocator, host, port);
            const decoder = decode.Decoder(contractEnumT, contractT, handlerT).init(allocator, handler);
            return .{ .allocator = allocator, .stream = stream, .decoder = decoder };
        }

        pub fn recv(self: *Self) !void {
            const bytesRead = try self.stream.reader().read(&buffer);
            if (bytesRead == 0) {
                return error.ConnectionClosed;
            }
            try self.decoder.decode(buffer[0..bytesRead]);
        }

        pub fn send(self: Self, comptime T: type, message: T) !void {
            const bytes = try self.Encoder.encode(T, message);
            self.stream.writeAll(bytes);
        }

        pub fn deinit(self: Self) void {
            self.stream.close();
        }
    };
}
