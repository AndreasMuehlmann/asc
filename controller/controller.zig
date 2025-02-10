const std = @import("std");

//const Bno = @import("bno.zig").Bno;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
//const NetServer = @import("netServer.zig").NetServer;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
    @cInclude("unistd.h");
});

const rtos = @cImport({
    @cInclude("freertos/FreeRTOS.h");
    @cInclude("freertos/task.h");
});

const encode = @import("encode");

fn timestampMicros() f64 {
    var now = c.timeval{ .tv_sec = 0, .tv_usec = 0 };
    _ = c.gettimeofday(&now, null);
    return @floatFromInt(now.tv_sec * 1000000 + now.tv_usec);
}

pub const Controller = struct {
    const Self = @This();
    //const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    allocator: std.mem.Allocator,
    //bno: Bno,
    //netServer: NetServerT,

    pub fn init(allocator: std.mem.Allocator) !Self { //, netServer: NetServerT) !Self {
        //const bno = try Bno.init(allocator);
        return .{ .allocator = allocator }; //, .bno = bno, .netServer = netServer };
    }

    pub fn run(_: *Self) !void {
        //const start = std.time.milliTimestamp();

        const ticksPerSecond: f64 = 2.0;
        const microsPerTick: f64 = 1_000_000.0 / ticksPerSecond;
        var accumulator: f64 = 0.0;
        var lastUpdate = timestampMicros();
        while (true) : (accumulator -= microsPerTick) {
            while (accumulator + timestampMicros() - lastUpdate < 0) {
                const micros: c.useconds_t = @intFromFloat(-(accumulator + timestampMicros() - lastUpdate) / 100);
                //_ = c.printf("micros: %d\n", micros);
                if (micros < 1000) {
                    continue;
                }
                rtos.vTaskDelay((micros / 1000) / rtos.portTICK_PERIOD_MS);
                //std.time.sleep((microsPerTick / 100.0) * 1_000);
            }
            accumulator += timestampMicros() - lastUpdate;
            if (accumulator > 1_000.0) {
                accumulator = 1_000.0;
            }
            lastUpdate = timestampMicros();

            _ = c.printf("Hello Controller!\n");
            //const euler = try self.bno.getEuler();
            //const acceleration = try self.bno.getAcceleration();
            //self.netServer.recv() catch |err| switch (err) {
            //    error.ConnectionClosed => return,
            //    else => return err,
            //};
            //const time: f32 = @floatFromInt(std.time.milliTimestamp() - start);
            //const measurement: clientContract.Measurement = .{ .time = time / 1_000.0, .heading = euler.heading, .accelerationX = acceleration.x, .accelerationY = acceleration.y, .accelerationZ = acceleration.z };
            //try self.netServer.send(clientContract.Measurement, measurement);
            rtos.vTaskDelay(1 / rtos.portTICK_PERIOD_MS);
        }
    }

    pub fn handleCommand(self: *Self, command: []const u8) !void {
        //std.debug.print("{s}\n", .{command});
        self.allocator.free(command);
    }

    pub fn deinit(_: Self) void {
        //self.bno.deinit() catch return;
    }
};
