const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const rl = @import("raylib");

const commandParserMod = @import("commandParser");
const CommandParser = commandParserMod.CommandParser;

const descriptions: []const commandParserMod.FieldDescription = &.{
    .{ .fieldName = "ssid", .description = "The name of the wlan to connect to." },
    .{ .fieldName = "password", .description = "The passowrd for the wlan to connect to." },
};

const commandParserT: type = CommandParser(serverContract.command, descriptions);

pub const Client = struct {
    allocator: std.mem.Allocator,
    netClient: NetClientT,
    gui: Gui,
    file: std.fs.File,
    prevTrackPoint: ?clientContract.TrackPoint,
    prevPosition: rl.Vector2,

    const Self = @This();
    const NetClientT = NetClient(clientContract.ClientContractEnum, clientContract.ClientContract, Self, serverContract.ServerContract);

    pub fn init(allocator: std.mem.Allocator, netClient: NetClientT) !Self {
        const file = try std.fs.cwd().createFile(
            "measurement.csv",
            .{},
        );

        try file.writeAll("time,yaw,accelerationX,accelerationY,accelerationZ\n");
        const gui = try Gui.init(allocator);

        return .{ 
            .allocator = allocator,
            .netClient = netClient,
            .gui = gui,
            .file = file,
            .prevTrackPoint = null,
            .prevPosition = rl.Vector2.init(0, 0),
        };
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

            if (self.gui.getCommand()) |commandStr| {
                defer self.gui.resetCommand();
                var commandParser = commandParserT.init(self.allocator, commandStr);
                defer commandParser.deinit();
                const command = commandParser.parse() catch |err| {
                    if (commandParser.message.len == 0) {
                        std.debug.print("Error: {s}\n", .{@errorName(err)});
                    } else {
                        std.debug.print("{s}\n", .{commandParser.message});
                    }
                    continue;
                };
                // TODO: on setMode with maptrack reset the track plot
                try self.netClient.send(serverContract.command, command);
            }
        }
    }

    pub fn deinit(self: *Self) void {
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

        var array = [_]rl.Vector2{rl.Vector2.init(measurement.time, measurement.heading)};
        try self.gui.addPoints("Yaw", "Heading", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationX);
        try self.gui.addPoints("Acceleration", "Acceleration x", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationY);
        try self.gui.addPoints("Acceleration", "Acceleration y", &array);

        array[0] = rl.Vector2.init(measurement.time, measurement.accelerationZ);
        try self.gui.addPoints("Acceleration", "Acceleration z", &array);
    }

    pub fn handleTrackPoint(self: *Self, trackPoint: clientContract.TrackPoint) !void {
        if (self.prevTrackPoint) |prevTrackPoint| {
            const diffDistance = trackPoint.distance - prevTrackPoint.distance;
            const averageHeading = (trackPoint.heading + prevTrackPoint.heading) / 2.0;

            const currentPosition = rl.Vector2{
                .x = self.prevPosition.x + -std.math.cos(averageHeading * std.math.pi / 180.0) * diffDistance,
                .y = self.prevPosition.y + std.math.sin(averageHeading * std.math.pi / 180.0) * diffDistance,
            };
            self.prevPosition = currentPosition;

            const array = [_]rl.Vector2{currentPosition};
            try self.gui.addPoints("Track", "Track", &array);
        } 
        self.prevTrackPoint = trackPoint; 

    }
};
