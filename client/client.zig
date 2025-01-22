const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");

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
            try self.netClient.recv();
            self.gui.update() catch |err| {
                if (err == Gui.GuiError.Quit) {
                    return;
                }
                return err;
            };
        }
    }

    pub fn deinit(self: Self) void {
        self.netClient.deinit();
        self.gui.deinit();
    }

    pub fn handleOrientation(self: *Self, orientation: clientContract.Orientation) !void {
        var array = [_]guiApi.Vec2D{.{ .x = @floatFromInt(orientation.time), .y = @as(f64, orientation.heading) }};
        try self.gui.addPoints("Orientation", "Heading", &array);
    }
};
