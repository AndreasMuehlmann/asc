const std = @import("std");
const net = std.net;
const posix = std.posix;

const decode = @import("decode");
const encode = @import("encode");

pub fn NetServer(comptime serverContractEnumT: type, comptime serverContractT: type, comptime handlerT: type, comptime clientContractT: type) type {
    return struct {
        allocator: std.mem.Allocator,

        listener: posix.socket_t,
        stream: net.Stream,

        decoder: decode.Decoder(serverContractEnumT, serverContractT, handlerT),

        const Encoder = encode.Encoder(clientContractT);

        const Self = @This();
        var buffer: [128]u8 = undefined;

        pub fn init(allocator: std.mem.Allocator, port: u16, handler: *handlerT) !Self {
            const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, port);

            // Create a non-blocking socket
            const sock = try posix.socket(address.any.family, posix.SOCK.STREAM | posix.SOCK.NONBLOCK, posix.IPPROTO.TCP);
            defer posix.close(sock);

            const tpe: u32 = posix.SOCK.STREAM | posix.SOCK.NONBLOCK;
            const protocol = posix.IPPROTO.TCP;
            const listener = try posix.socket(address.any.family, tpe, protocol);

            try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
            try posix.bind(listener, &address.any, address.getOsSockLen());
            try posix.listen(listener, 128);

            var socket: i32 = undefined;
            while (true) {
                socket = posix.accept(listener, null, null, posix.SOCK.NONBLOCK) catch |err| {
                    if (err == error.WouldBlock) {
                        std.time.sleep(1_000_000);
                        continue;
                    }
                    return err;
                };
                break;
            }

            const stream = std.net.Stream{ .handle = socket };

            const decoder = decode.Decoder(serverContractEnumT, serverContractT, handlerT).init(allocator, handler);

            return .{ .allocator = allocator, .listener = listener, .stream = stream, .decoder = decoder };
        }

        pub fn recv(self: *Self) !void {
            const bytesRead = try self.stream.read(&buffer) catch |err| {
                if (err == error.WouldBlock) {
                    return;
                }
                return err;
            };
            if (bytesRead == 0) {
                return;
            }
            try self.decoder.decode(buffer[0..bytesRead]);
        }

        pub fn send(self: Self, comptime T: type, message: T) !void {
            const bytes = try Encoder.encode(T, message);
            try self.stream.writeAll(bytes);
        }

        pub fn deinit(self: Self) void {
            self.stream.close();
            posix.close(self.listener);
        }
    };
}
