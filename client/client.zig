const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const Gui = @import("gui.zig").Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");

pub const Client = struct {
    allocator: std.mem.Allocator,
    file: std.fs.File,
    netClient: NetClientT,
    gui: Gui,

    const Self = @This();
    const NetClientT = NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self, serverContract.ServerContract);

    pub fn init(allocator: std.mem.Allocator, netClient: NetClientT) !Self {
        const file = try std.fs.cwd().createFile("measurements.csv", .{ .truncate = true });
        try file.writeAll("time,heading,roll,pitch\n");

        const gui = try Gui.init();

        return .{ .allocator = allocator, .file = file, .netClient = netClient, .gui = gui };
    }

    pub fn run(self: *Self) !void {
        while (true) {
            self.gui.update() catch |err| {
                if (err == Gui.GuiError.Quit) {
                    return;
                }
                return err;
            };
            try self.netClient.recv();
        }
    }

    pub fn deinit(self: Self) void {
        self.netClient.deinit();
        self.file.close();
        self.gui.deinit();
    }

    pub fn handleOrientation(self: *Self, orientation: clientContract.Orientation) !void {
        std.debug.print("{d},{d},{d},{d}\n", .{ orientation.time, orientation.heading, orientation.roll, orientation.pitch });
        const message = try std.fmt.allocPrint(self.allocator, "{d},{d},{d},{d}\n", .{ orientation.time, orientation.heading, orientation.roll, orientation.pitch });
        try self.file.writeAll(message);
        self.allocator.free(message);
    }
};
