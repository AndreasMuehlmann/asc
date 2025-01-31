const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const rl = @import("raylib");

pub const Client = struct {
    allocator: std.mem.Allocator,
    netClient: NetClientT,
    gui: Gui,

    const Self = @This();
    const NetClientT = NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self, serverContract.ServerContract);

    pub fn init(allocator: std.mem.Allocator, netClient: NetClientT) !Self {
        const gui = try Gui.init(allocator);

        return .{ .allocator = allocator, .netClient = netClient, .gui = gui };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            self.netClient.recv() catch |err| switch (err) {
                error.ConnectionClosed => return,
                else => return err,
            };

            self.gui.update() catch |err| switch (err) {
                guiApi.GuiError.Quit => return,
                else => return err,
            };
        }
    }

    pub fn deinit(self: Self) void {
        self.netClient.deinit();
        self.gui.deinit();
    }

    pub fn handleMeasurement(self: *Self, measurement: clientContract.Measurement) !void {
        var array = [_]rl.Vector2{rl.Vector2.init(measurement.time, measurement.heading)};
        try self.gui.addPoints("Yaw", "Heading", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationX);
        try self.gui.addPoints("Acceleration", "Acceleration x", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationY);
        try self.gui.addPoints("Acceleration", "Acceleration y", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationZ);
        try self.gui.addPoints("Acceleration", "Acceleration z", &array);
    }
};
