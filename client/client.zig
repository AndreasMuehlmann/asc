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
    file: std.fs.File,

    const Self = @This();
    const NetClientT = NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self, serverContract.ServerContract);

    pub fn init(allocator: std.mem.Allocator, netClient: NetClientT) !Self {
        const file = try std.fs.cwd().createFile(
            "measurement.csv",
            .{},
        );

        try file.writeAll("time,yaw,accelerationX,accelerationY,accelerationZ\n");
        const gui = try Gui.init(allocator);

        return .{ .allocator = allocator, .netClient = netClient, .gui = gui, .file = file };
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
        self.file.close();
    }

    pub fn handleMeasurement(self: *Self, measurement: clientContract.Measurement) !void {
        const buffer = try std.fmt.allocPrint(
            self.allocator,
            "{d},{d},{d},{d},{d}\n",
            .{ measurement.time, measurement.heading, measurement.accelerationX, measurement.accelerationY, measurement.accelerationZ },
        );
        try self.file.writeAll(buffer);
        self.allocator.free(buffer);

        //var array = [_]rl.Vector2{rl.Vector2.init(measurement.time, measurement.heading)};
        //try self.gui.addPoints("Yaw", "Heading", &array);

        //array[0] = rl.Vector2.init(measurement.time, measurement.accelerationX);
        //try self.gui.addPoints("Acceleration", "Acceleration x", &array);

        //array[0] = rl.Vector2.init(measurement.time, measurement.accelerationY);
        //try self.gui.addPoints("Acceleration", "Acceleration y", &array);

        //array[0] = rl.Vector2.init(measurement.time, measurement.accelerationZ);
        //try self.gui.addPoints("Acceleration", "Acceleration z", &array);
    }
};
