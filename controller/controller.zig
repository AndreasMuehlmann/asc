const std = @import("std");

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const encode = @import("encode");
const NetServer = @import("netServer.zig").NetServer;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
    @cInclude("unistd.h");
});

const esp = @cImport({
    @cInclude("server.h");
    @cInclude("esp_system.h");
    @cInclude("esp_log.h");
});

const rtos = @cImport(@cInclude("rtos.h"));

fn timestampMicros() i64 {
    var now = c.timeval{ .tv_sec = 0, .tv_usec = 0 };
    _ = c.gettimeofday(&now, null);
    const seconds: i64 = @intCast(now.tv_sec);
    const micros: i64 = @intCast(now.tv_usec);
    return seconds * 1000000 + micros;
}

pub const Controller = struct {
    const Self = @This();
    const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    allocator: std.mem.Allocator,
    netServer: NetServerT,

    pub fn init(allocator: std.mem.Allocator, netServer: NetServerT) !Self {
        return .{ .allocator = allocator, .netServer = netServer };
    }

    pub fn run(self: *Self) !void {
        const start = @divTrunc(timestampMicros(), 1000);

        const ticksPerSecond: i64 = 100;
        const microsPerTick: i64 = 1_000_000 / ticksPerSecond;
        var accumulator: i64 = 0;
        var lastUpdate = timestampMicros();
        while (true) : (accumulator -= microsPerTick) {
            var timestamp = timestampMicros();
            while (accumulator + (timestamp - lastUpdate) < 0) {
                const micros = @divTrunc(@abs(accumulator + timestamp - lastUpdate), 2);
                const microsU32: u32 = @intCast(micros);
                if (rtos.rtosMillisToTicks(@divTrunc(microsU32, 1000)) > 1) {
                    rtos.rtosVTaskDelay(rtos.rtosMillisToTicks(@divTrunc(microsU32, 1000)));
                } else {
                    _ = c.usleep(microsU32);
                }
                timestamp = timestampMicros();
            }

            accumulator += timestampMicros() - lastUpdate;
            if (accumulator > 1_000) {
                accumulator = 1_000;
            }
            lastUpdate = timestampMicros();

            //const euler = try self.bno.getEuler();
            //const acceleration = try self.bno.getAcceleration();
            self.netServer.recv() catch |err| switch (err) {
                error.ConnectionClosed => return,
                else => return err,
            };

            const time: f32 = @floatFromInt(@divTrunc(timestampMicros(), 1000) - start);
            const measurement: clientContract.Measurement = .{ .time = time / 1_000.0, .heading = 100, .accelerationX = 2, .accelerationY = -3, .accelerationZ = 1 };
            try self.netServer.send(clientContract.Measurement, measurement);
            rtos.rtosVTaskDelay(10);
        }
    }

    pub fn handleCommand(self: *Self, command: []const u8) !void {
        var array: [250]u8 = undefined;
        const buffer = std.fmt.bufPrintZ(&array, "{s}", .{command}) catch unreachable;
        _ = c.printf("%s\n", buffer.ptr);
        self.allocator.free(command);
    }

    pub fn deinit(_: Self) void {
        //self.bno.deinit() catch return;
    }
};
