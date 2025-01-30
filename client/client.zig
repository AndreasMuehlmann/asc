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

    pub fn handleOrientation(self: *Self, orientation: clientContract.Orientation) !void {
        var array = [_]rl.Vector2{rl.Vector2.init(@floatFromInt(orientation.time), orientation.heading)};
        try self.gui.addPoints("Yaw", "Heading", &array);
    }
};
