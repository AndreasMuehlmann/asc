const std = @import("std");
const net = std.net;

const NetClient = @import("netClient.zig").NetClient;
const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const rl = @import("raylib");
const trackMod = @import("track");
const Track = trackMod.Track(false);
const TrackPoint = trackMod.TrackPoint;

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
    trackPoints: std.ArrayList(TrackPoint),
    prevPosition: rl.Vector2,
    track: ?Track,

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
            .trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 10),
            .prevPosition = rl.Vector2.init(0, 0),
            .track = null,
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
                try self.gui.writeToConsole(commandStr);
                try self.gui.writeToConsole("\n");
                var commandParser = commandParserT.init(self.allocator, commandStr);
                defer commandParser.deinit();
                const command = commandParser.parse() catch |err| {
                    if (commandParser.message.len == 0) {
                        const str = try std.fmt.allocPrint(self.allocator, "Error: {s}\n", .{@errorName(err)});
                        try self.gui.console.writeToOutput(str);
                        self.allocator.free(str);
                    } else {
                        const str = try std.fmt.allocPrint(self.allocator, "{s}\n", .{commandParser.message});
                        try self.gui.console.writeToOutput(str);
                        self.allocator.free(str);
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
        try self.trackPoints.append(self.allocator, .{ .distance = trackPoint.distance, .heading = trackPoint.heading});

        if (self.trackPoints.items.len <= 1) {
            const array = [_]rl.Vector2{self.prevPosition};
            try self.gui.addPoints("Track", "Track", &array);
            return;
        }

        const prevTrackPoint = self.trackPoints.items[self.trackPoints.items.len - 2];

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

    pub fn handleCarTrackPoint(self: *Self, trackPoint: clientContract.CarTrackPoint) !void {
        if (self.track) |track| {
            const position = track.distanceToPosition(trackPoint.distance);
            self.gui.carPositionAndHeading = .{ .position = .{ .x = position.x, .y = position.y }, .heading = trackPoint.heading };
        }
    }

    pub fn handleLog(self: *Self, log: clientContract.Log) !void {
        defer self.allocator.free(log.message);
        var text = try std.ArrayList(u8).initCapacity(self.allocator, log.message.len + 20);
        defer text.deinit(self.allocator);
        const prefix = switch (log.level) {
            clientContract.LogLevel.debug => "Debug: ",
            clientContract.LogLevel.info => "Info: ",
            clientContract.LogLevel.warning => "Warning: ",
            clientContract.LogLevel.err => "Error: ",
        };
        try text.appendSlice(self.allocator, prefix);
        try text.appendSlice(self.allocator, log.message);
        try text.append(self.allocator, '\n');
        try self.gui.writeToConsole(text.items);
    }

    pub fn handleCommand(self: *Self, command: clientContract.command) !void {
        switch (command) {
            .endMapping => {
                const trackPoints = try self.trackPoints.toOwnedSlice(self.allocator);
                self.track = try Track.init(self.allocator, trackPoints);
                self.trackPoints = try std.ArrayList(TrackPoint).initCapacity(self.allocator, 10);
                try self.gui.clear("Track", "Track");
                var positions = try self.allocator.alloc(rl.Vector2, self.track.?.distancePositions.len);
                defer self.allocator.free(positions);
                for (self.track.?.distancePositions, 0..) |distancePosition, i| {
                    positions[i] = rl.Vector2.init(distancePosition.position.x, distancePosition.position.y);
                }
                try self.gui.addPoints("Track", "Track", positions);
            },
            .resetMapping => {
                if (self.track) |*track| {
                    track.deinit();
                    self.track = null;
                }
                self.trackPoints.clearAndFree(self.allocator);
                try self.gui.clear("Track", "Track");
            },
        }
    }

    pub fn deinit(self: *Self) void {
        self.netClient.deinit();
        self.gui.deinit();
        self.file.close();
        self.trackPoints.deinit(self.allocator);
        if (self.track) |*track| {
            track.deinit();
        }
    }
};
