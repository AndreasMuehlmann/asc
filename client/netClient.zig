const std = @import("std");
const builtin = @import("builtin");
const net = std.net;
const posix = std.posix;

const decode = @import("decode");
const encode = @import("encode");

pub fn NetClient(comptime clientContractEnumT: type, comptime clientContractT: type, comptime handlerT: type, comptime serverContract: type) type {
    return struct {
        allocator: std.mem.Allocator,
        socket: posix.socket_t,
        stream: std.net.Stream,
        decoder: decode.Decoder(clientContractEnumT, clientContractT, handlerT),

        const Encoder = encode.Encoder(serverContract);

        const Self = @This();
        var buffer: [128]u8 = undefined;

        pub fn init(allocator: std.mem.Allocator, hostname: []const u8, port: u16, handler: *handlerT) !Self {
            const addressList = try net.getAddressList(allocator, hostname, port);
            defer addressList.deinit();

            if (addressList.addrs.len == 0) return error.UnknownHostName;

            var socket: posix.socket_t = undefined;
            const tpe: u32 = posix.SOCK.STREAM | posix.SOCK.NONBLOCK;
            const protocol = posix.IPPROTO.TCP;

            var validSocket: bool = false;
            for (addressList.addrs) |address| {
                socket = try posix.socket(address.any.family, tpe, protocol);
                try posix.setsockopt(socket, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));

                posix.connect(socket, &address.any, address.getOsSockLen()) catch |err| switch (err) {
                    error.WouldBlock => {
                        if (builtin.os.tag == .windows) {
                            const pfd = std.os.windows.ws2_32.pollfd{
                                .fd = socket,
                                .events = posix.POLL.OUT,
                                .revents = 0,
                            };
                            var pfdArray = [1]posix.pollfd{pfd};

                            const manyPtr: [*]std.os.windows.ws2_32.pollfd = &pfdArray;
                            const pollResult = std.os.windows.poll(manyPtr, 1, 5000);
                            if (pollResult <= 0) {
                                return error.PollFailed;
                            }

                            if (pfdArray[0].revents & posix.POLL.OUT == 0) {
                                return error.ConnectionFailed;
                            }

                            std.posix.getsockoptError(socket) catch continue;
                            validSocket = true;
                        } else {
                            const pfd = posix.pollfd{
                                .fd = socket,
                                .events = posix.POLL.OUT,
                                .revents = 0,
                            };
                            var pfdArray = [1]posix.pollfd{pfd};
                            const pfdSlice: []posix.pollfd = &pfdArray;
                            const pollResult = try posix.poll(pfdSlice, 5000);
                            if (pollResult <= 0) {
                                return error.PollFailed;
                            }
                            if (pfdSlice[0].revents & posix.POLL.OUT == 0) {
                                return error.ConnectionFailed;
                            }

                            std.posix.getsockoptError(socket) catch |sockOptErr| switch (sockOptErr) {
                                error.ConnectionRefused => continue,
                                else => return sockOptErr,
                            };
                            validSocket = true;
                        }
                        break;
                    },
                    error.ConnectionRefused => {
                        posix.close(socket);
                        continue;
                    },
                    else => return err,
                };
            }

            if (!validSocket) {
                std.log.err("All hosts refused connection.\n", .{});
                return error.ConnectionRefused;
            }

            const stream = std.net.Stream{ .handle = socket };

            const decoder = decode.Decoder(clientContractEnumT, clientContractT, handlerT).init(allocator, handler);
            return .{ .allocator = allocator, .socket = socket, .stream = stream, .decoder = decoder };
        }

        pub fn recv(self: *Self) !void {
            const bytesRead = self.stream.read(&buffer) catch |err| switch (err) {
                error.WouldBlock => return,
                else => return err,
            };
            if (bytesRead == 0) {
                return error.ConnectionClosed;
            }
            try self.decoder.decode(buffer[0..bytesRead]);
        }

        pub fn send(self: Self, comptime T: type, message: T) !void {
            const bytes = try Encoder.encode(T, message);
            var index: usize = 0;
            while (index < bytes.len) {
                index += self.stream.write(bytes[index..]) catch |err| switch (err) {
                    error.WouldBlock => continue,
                    else => return err,
                };
            }
        }

        pub fn deinit(self: Self) void {
            self.stream.close();
        }
    };
}
