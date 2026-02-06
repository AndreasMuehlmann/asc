const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const rl = @import("raylib");
const Track = @import("track").Track;

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

        try file.writeAll("time,heading,accelerationX,accelerationY,accelerationZ,velocity,distance\n");
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

                try self.netClient.send(serverContract.command, command);
            }

            const deadzone: f32 = 0.05;
            if (rl.isGamepadAvailable(0)) {
                var stick = .{
                    .x = rl.getGamepadAxisMovement(0, rl.GamepadAxis.left_x),
                    .y = rl.getGamepadAxisMovement(0, rl.GamepadAxis.left_y),
                };
                stick.y *= -1.0;

                var magnitude = @sqrt(stick.x * stick.x + stick.y * stick.y);

                if (magnitude < deadzone) {
                    stick.x = 0.0;
                    stick.y = 0.0;
                    magnitude = 0.0;
                } else {
                    const scaled: f32 = (magnitude - deadzone) / (1.0 - deadzone);
                    stick.x = (stick.x / magnitude) * scaled;
                    stick.y = (stick.y / magnitude) * scaled;
                    magnitude = scaled;
                    stick.x = if (stick.x > 1.0) 1.0 else stick.x;
                    stick.x = if (stick.x < -1.0) -1.0 else stick.x;
                    stick.y = if (stick.y > 1.0) 1.0 else stick.y;
                    stick.y = if (stick.y < -1.0) -1.0 else stick.y;


                }
                const command: serverContract.command = serverContract.command{ .setSpeed = serverContract.setSpeed{
                    .speed = (stick.y + 1.0) / 2.0,
                } };
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
            "{d},{d},{d},{d},{d},{d},{d}\n",
            .{ measurement.time, measurement.heading, measurement.accelerationX, measurement.accelerationY, measurement.accelerationZ, measurement.velocity, measurement.distance },
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
            const delta = Track.angularDelta(prevTrackPoint.heading, trackPoint.heading);
            const averageHeading = prevTrackPoint.heading + delta * 0.5;

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
