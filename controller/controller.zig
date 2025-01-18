const std = @import("std");

const Bno = @import("bno.zig").Bno;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const NetServer = @import("netServer.zig").NetServer;

const encode = @import("encode");

pub const Controller = struct {
    const Self = @This();
    const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    bno: Bno,
    netServer: NetServerT,

    pub fn init(allocator: std.mem.Allocator, netServer: NetServerT) !Self {
        const bno = try Bno.init(allocator);
        return .{ .bno = bno, .netServer = netServer };
    }

    pub fn run(self: Self) !void {
        const start = std.time.milliTimestamp();
        while (true) {
            const euler = try self.bno.getEuler();
            const orientation: clientContract.Orientation = .{ .time = std.time.milliTimestamp() - start, .heading = euler.heading, .roll = euler.roll, .pitch = euler.pitch };
            try self.netServer.send(clientContract.Orientation, orientation);
            std.time.sleep(200_000_000);
        }
    }

    pub fn deinit(self: Self) void {
        self.bno.deinit() catch return;
    }
};
