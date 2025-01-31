const std = @import("std");

const Bno = @import("bno.zig").Bno;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const NetServer = @import("netServer.zig").NetServer;

const encode = @import("encode");

fn timestampMicros() f64 {
    return @floatFromInt(std.time.microTimestamp());
}

pub const Controller = struct {
    const Self = @This();
    const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    allocator: std.mem.Allocator,
    bno: Bno,
    netServer: NetServerT,

    pub fn init(allocator: std.mem.Allocator, netServer: NetServerT) !Self {
        const bno = try Bno.init(allocator);
        return .{ .allocator = allocator, .bno = bno, .netServer = netServer };
    }

    pub fn run(self: *Self) !void {
        const start = std.time.milliTimestamp();

        const ticksPerSecond: f64 = 40.0;
        const microsPerTick: f64 = 1_000_000.0 / ticksPerSecond;
        var accumulator: f64 = 0.0;
        var lastUpdate = timestampMicros();
        while (true) : (accumulator -= microsPerTick) {
            while (accumulator + timestampMicros() - lastUpdate < 0) {
                std.time.sleep((microsPerTick / 100.0) * 1_000);
            }
            accumulator += timestampMicros() - lastUpdate;
            if (accumulator > 1_000.0) {
                accumulator = 1_000.0;
            }
            lastUpdate = timestampMicros();

            const euler = try self.bno.getEuler();
            const acceleration = try self.bno.getAcceleration();
            self.netServer.recv() catch |err| switch (err) {
                error.ConnectionClosed => return,
                else => return err,
            };
            const time: f32 = @floatFromInt(std.time.milliTimestamp() - start);
            const measurement: clientContract.Measurement = .{ .time = time / 1_000.0, .heading = euler.heading, .accelerationX = acceleration.x, .accelerationY = acceleration.y, .accelerationZ = acceleration.z };
            try self.netServer.send(clientContract.Measurement, measurement);
        }
    }

    pub fn handleCommand(self: *Self, command: []const u8) !void {
        std.debug.print("{s}\n", .{command});
        self.allocator.free(command);
    }

    pub fn deinit(self: Self) void {
        self.bno.deinit() catch return;
    }
};
