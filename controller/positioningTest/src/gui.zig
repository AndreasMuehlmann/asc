const std = @import("std");

const rl = @import("raylib");

const p = @import("plot.zig");
const Plot = p.Plot;
const DataSet = p.DataSet;
const TrackMapPlot = @import("trackMapPlot.zig").TrackMapPlot;

pub const GuiError = error{
    UnkownDataSetName,
    UnkownPlotName,
    Quit,
};

pub const PositionAndHeading = struct {
    heading: f32,
    position: rl.Vector2,
};

pub const Gui = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    plots: []Plot,
    trackMapPlot: TrackMapPlot,
    carPositionAndHeading: ?PositionAndHeading,
    // only simulation
    actualCarPositionAndHeading: ?PositionAndHeading,

    pub fn init(allocator: std.mem.Allocator) !Self {
        const windowWidth = rl.getScreenWidth();
        const windowHeight = rl.getScreenHeight();
        const windowWidthF: f32 = @floatFromInt(windowWidth);
        const windowHeightF: f32 = @floatFromInt(windowHeight);

        rl.setTraceLogLevel(.warning);
        rl.setConfigFlags(.{
            .window_resizable = true,
            .msaa_4x_hint = true,
        });
        rl.initWindow(windowWidth, windowHeight, "simulation");
        rl.setTargetFPS(60);
        rl.setWindowMinSize(800, 800);

        var dataSetsYaw = try allocator.alloc(DataSet, 1);
        dataSetsYaw[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Heading", .color = rl.Color.dark_blue, .lineWidth = 3.0 };

        var dataSetsVelocity = try allocator.alloc(DataSet, 1);
        dataSetsVelocity[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Velocity", .color = rl.Color.dark_purple, .lineWidth = 2.0 };

        var dataSetsTrack = try allocator.alloc(DataSet, 1);
        dataSetsTrack[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Track", .color = rl.Color.pink, .lineWidth = 3.0 };

        const plots = try allocator.alloc(Plot, 2);
       //plots[0] = Plot.init(allocator, "Heading", "Time in s", rl.Color.black, true, rl.Vector2.init(0.0, 0.0), rl.Vector2.init(0.5, 0.5), rl.Vector2.init(0, 0.0), rl.Vector2.init(5.0, 360.0), 30, windowWidthF, windowHeightF, dataSetsYaw);
       //plots[1] = Plot.init(allocator, "Velocity", "Time in s", rl.Color.black, true, rl.Vector2.init(0.0, 0.5), rl.Vector2.init(0.5, 0.5), rl.Vector2.init(0, -15.0), rl.Vector2.init(5.0, 15.0), 30, windowWidthF, windowHeightF, dataSetsVelocity);

        const trackMapPlot = try TrackMapPlot.init(Plot.init(allocator, "Track", "x in m", rl.Color.black, false, rl.Vector2.init(0.0, 0.0), rl.Vector2.init(1.0, 1.0), rl.Vector2.init(-0.1, -0.1), rl.Vector2.init(0.1, 0.1), 30, windowWidthF, windowHeightF, dataSetsTrack));

        return .{ .allocator = allocator, .plots = plots, .trackMapPlot = trackMapPlot, .carPositionAndHeading = null, .actualCarPositionAndHeading = null };
    }

    pub fn update(self: *Self) !void {
        const windowWidth: f32 = @floatFromInt(rl.getRenderWidth());
        const windowHeight: f32 = @floatFromInt(rl.getRenderHeight());
        if (rl.windowShouldClose()) {
            return GuiError.Quit;
        }
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.white);

       //for (0..self.plots.len) |i| {
       //    self.plots[i].resize(windowWidth, windowHeight);
       //    try self.plots[i].draw();
       //}

        self.trackMapPlot.resize(windowWidth, windowHeight);
        try self.trackMapPlot.draw();
        if (self.carPositionAndHeading) |carPositionAndHeading| {
            self.trackMapPlot.drawCar(carPositionAndHeading.heading, carPositionAndHeading.position);
        }
        // only simulation
        if (self.actualCarPositionAndHeading) |carPositionAndHeading| {
            const positionInPlot = self.trackMapPlot.plot.toGlobal(carPositionAndHeading.position);
            drawOrientedRectOutline(
                positionInPlot,
                39.0,
                49.0,
                .{ .x = 39.0 / 2.0, .y = 0.0 },
                carPositionAndHeading.heading - 90.0,
                rl.Color.red,
            );
        }
    }
    // only simulation
    pub fn drawOrientedRectOutline(
        position: rl.Vector2,
        width: f32,
        height: f32,
        origin: rl.Vector2,
        rotationDeg: f32,
        color: rl.Color,
    ) void {
        const angle = std.math.degreesToRadians(rotationDeg);

        const local = [_]rl.Vector2{
            .{ .x = -origin.x, .y = -origin.y }, // top-left
            .{ .x = width - origin.x, .y = -origin.y }, // top-right
            .{ .x = width - origin.x, .y = height - origin.y }, // bottom-right
            .{ .x = -origin.x, .y = height - origin.y }, // bottom-left
        };

        var world: [4]rl.Vector2 = undefined;

        for (local, 0..) |po, i| {
            const x = po.x;
            const y = po.y;

            world[i] = .{
                .x = position.x + x * @cos(angle) - y * @sin(angle),
                .y = position.y + x * @sin(angle) + y * @cos(angle),
            };
        }

        inline for (0..4) |i| {
            rl.drawLineV(
                world[i],
                world[(i + 1) % 4],
                color,
            );
        }
    }

    pub fn addPoints(self: *Self, plotName: []const u8, dataSetName: []const u8, points: []const rl.Vector2) !void {
        for (0..self.plots.len) |i| {
            if (std.mem.eql(u8, plotName, self.plots[i].name)) {
                try self.plots[i].addPoints(dataSetName, points);
                return;
            }
        }
        if (std.mem.eql(u8, plotName, self.trackMapPlot.plot.name)) {
            try self.trackMapPlot.addPoints(dataSetName, points);
            return;
        }
        return GuiError.UnkownPlotName;
    }

    pub fn setCarPositionAndHeading(self: *Self, heading: f32, position: rl.Vector2) void {
        self.carPositionAndHeading = .{ .heading = heading, .position = position };
    }

    pub fn deinit(self: *Self) void {
        for (self.plots) |*plot| {
            plot.deinit();
        }
        self.trackMapPlot.deinit();
        self.allocator.free(self.plots);

        rl.closeWindow();
    }
};
