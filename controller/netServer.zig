const std = @import("std");
const net = std.net;

const decode = @import("decode");
const encode = @import("encode");

pub fn NetServer(comptime serverContractEnumT: type, comptime serverContractT: type, comptime handlerT: type, comptime clientContractT: type) type {
    return struct {
        allocator: std.mem.Allocator,
        server: std.net.Server,
        connection: std.net.Server.Connection,

        decoder: decode.Decoder(serverContractEnumT, serverContractT, handlerT),

        const Encoder = encode.Encoder(clientContractT);

        const Self = @This();
        var buffer: [256]u8 = undefined;

        pub fn init(allocator: std.mem.Allocator, port: u16, handler: *handlerT) !Self {
            const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, port);
            var server = try address.listen(.{});
            const connection = try server.accept();

            const decoder = decode.Decoder(serverContractEnumT, serverContractT, handlerT).init(allocator, handler);
            return .{ .allocator = allocator, .server = server, .connection = connection, .decoder = decoder };
        }

        pub fn recv(self: *Self) !void {
            const bytesRead = try self.connection.reader().read(&buffer);
            if (bytesRead == 0) {
                return error.ConnectionClosed;
            }
            try self.decoder.decode(buffer[0..bytesRead]);
        }

        pub fn send(self: Self, comptime T: type, message: T) !void {
            const bytes = try Encoder.encode(T, message);
            try self.connection.stream.writeAll(bytes);
        }

        pub fn deinit(self: Self) void {
            self.server.deinit();
            self.connection.stream.close();
        }
    };
}
