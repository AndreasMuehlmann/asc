const std = @import("std");

const esp = @cImport({
    @cInclude("esp_system.h");
    @cInclude("esp_log.h");
    @cInclude("wifi.h");
    @cInclude("server.h");
});

const c = @cImport({
    @cInclude("stdio.h");
});

const decode = @import("decode");
const encode = @import("encode");

const tag = "net server";

pub fn NetServer(comptime serverContractEnumT: type, comptime serverContractT: type, comptime handlerT: type, comptime clientContractT: type) type {
    return struct {
        allocator: std.mem.Allocator,

        listener: c_int,
        connection: c_int,

        decoder: decode.Decoder(serverContractEnumT, serverContractT, handlerT),

        const Encoder = encode.Encoder(clientContractT);

        const Self = @This();
        var buffer: [128]u8 = undefined;

        pub fn init(allocator: std.mem.Allocator, port: u16, handler: *handlerT) !Self {
            var listenerResult: esp.ListenerResult = .{ .server_fd = 0, .result = 0 };
            esp.create_listening_socket(port, &listenerResult);
            if (listenerResult.result != esp.OK) {
                esp.esp_log_write(esp.ESP_LOG_ERROR, "NetServer", "Listening socket couldn't be created. Error code: %d\n", listenerResult.result);
                @panic("Error when creating listening socket.");
            }
            var connectionResult: esp.ConnectionResult = .{ .connection = 0, .result = 0 };
            esp.wait_for_connection(listenerResult.server_fd, &connectionResult);
            if (listenerResult.result != esp.OK) {
                esp.esp_log_write(esp.ESP_LOG_ERROR, "NetServer", "Connection couldn't be accepted. Error code: %d\n", connectionResult.result);
                @panic("Error when waiting for connection.");
            }

            const decoder = decode.Decoder(serverContractEnumT, serverContractT, handlerT).init(allocator, handler);

            return .{ .allocator = allocator, .listener = listenerResult.server_fd, .connection = connectionResult.connection, .decoder = decoder };
        }

        pub fn recv(self: *Self) !void {
            var recvResult: esp.RecvResult = .{ .buffer = &buffer, .size = buffer.len, .result = 0, .bytesRead = 0 };
            esp.non_blocking_recv(self.connection, &recvResult);
            switch (recvResult.result) {
                esp.WOULD_BLOCK => return,
                esp.CONNECTION_CLOSED => return error.ConnectionClosed,
                esp.UNKNOWN => {
                    return error.RecvFailed;
                },
                esp.OK => try self.decoder.decode(buffer[0..@intCast(recvResult.bytesRead)]),
                else => unreachable,
            }
        }

        pub fn send(self: *Self, comptime T: type, message: T) !void {
            const bytes = try Encoder.encode(T, message);
            const buf: [*c]u8 = bytes.ptr;
            const result: c_int = esp.non_blocking_send(self.connection, buf, bytes.len);
            if (result != esp.OK) {
                return error.SendFailed;
            }
        }

        pub fn deinit(self: Self) void {
            esp.closeSock(self.listener);
            esp.closeSock(self.connection);
        }
    };
}
