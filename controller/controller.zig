const std = @import("std");

const Bno = @import("bno.zig").Bno;
const clientContract = @import("clientContract");
const encode = @import("encode");

pub const Controller = struct {
    const Self = @This();

    bno: Bno,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const bno = try Bno.init(allocator);
        return .{ .bno = bno };
    }

    pub fn run(self: Self) !void {
        const address = std.net.Address.initIp4(.{ 0, 0, 0, 0 }, 8080);
        var server = try address.listen(.{});
        defer server.deinit();

        const Encoder = encode.Encoder(clientContract.ClientContract);

        const start = std.time.milliTimestamp();
        while (true) {
            const connection = try server.accept();
            while (true) {
                const euler = try self.bno.getEuler();
                const orientation: clientContract.Orientation = .{ .time = std.time.milliTimestamp() - start, .heading = euler.heading, .roll = euler.roll, .pitch = euler.pitch };
                const buffer = try Encoder.encode(clientContract.Orientation, orientation);
                try connection.stream.writeAll(buffer);
            }
            std.time.sleep(200_000_000);
        }
    }

    pub fn deinit(self: Self) void {
        self.bno.deinit() catch return;
    }
};
