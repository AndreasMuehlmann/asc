const std = @import("std");

const rl = @import("raylib");

const p = @import("plot.zig");
const Plot = p.Plot;
const DataSet = p.DataSet;
const c = @import("console.zig");
const Console = c.Console;

pub const GuiError = error{
    UnkownDataSetName,
    UnkownPlotName,
    Quit,
};

pub const Gui = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    plots: []Plot,
    console: Console,

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
        rl.initWindow(windowWidth, windowHeight, "asc");
        rl.setTargetFPS(60);
        rl.setWindowMinSize(800, 800);

        var dataSetsYaw = try allocator.alloc(DataSet, 1);
        dataSetsYaw[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Heading", .color = rl.Color.dark_blue, .lineWidth = 3.0 };

        var dataSetsAcceleration = try allocator.alloc(DataSet, 3);
        dataSetsAcceleration[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Acceleration x", .color = rl.Color.dark_purple, .lineWidth = 2.0 };
        dataSetsAcceleration[1] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Acceleration y", .color = rl.Color.gold, .lineWidth = 2.0 };
        dataSetsAcceleration[2] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Acceleration z", .color = rl.Color.red, .lineWidth = 2.0 };

        var dataSetsTrack = try allocator.alloc(DataSet, 1);
        dataSetsTrack[0] = .{ .points = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10), .name = "Track", .color = rl.Color.pink, .lineWidth = 3.0 };

        var plots = try allocator.alloc(Plot, 3);
        plots[0] = Plot.init(allocator, "Yaw", "Time in s", rl.Color.black, true, rl.Vector2.init(0.0, 0.0), rl.Vector2.init(0.5, 0.5), rl.Vector2.init(0, 0.0), rl.Vector2.init(5.0, 360.0), 30, windowWidthF, windowHeightF, dataSetsYaw);
        // Min coord doesnt make sense
        plots[1] = Plot.init(allocator, "Track", "x in m", rl.Color.black, false, rl.Vector2.init(0.5, 0.0), rl.Vector2.init(0.5, 0.5), rl.Vector2.init(-0.1, -0.1), rl.Vector2.init(0.1, 0.1), 30, windowWidthF, windowHeightF, dataSetsTrack);
        plots[2] = Plot.init(allocator, "Acceleration", "Time in s", rl.Color.black, true, rl.Vector2.init(0.0, 0.5), rl.Vector2.init(0.5, 0.5), rl.Vector2.init(0, -15.0), rl.Vector2.init(5.0, 15.0), 30, windowWidthF, windowHeightF, dataSetsAcceleration);

        const console = try Console.init(allocator, rl.Vector2.init(0.5, 0.5), rl.Vector2.init(0.5, 0.5), 20, windowWidthF, windowHeightF);

        return .{ .allocator = allocator, .plots = plots, .console = console };
    }

    pub fn update(self: *Self) !void {
        const windowWidth: f32 = @floatFromInt(rl.getRenderWidth());
        const windowHeight: f32 = @floatFromInt(rl.getRenderHeight());
        if (rl.windowShouldClose()) {
            return GuiError.Quit;
        }
        rl.beginDrawing();
        defer rl.endDrawing();

        //if (rl.isKeyPressed(.s)) {
        //    rl.takeScreenshot("screenshot.png");
        //}
        rl.clearBackground(rl.Color.white);

        for (0..self.plots.len) |i| {
            self.plots[i].resize(windowWidth, windowHeight);
            try self.plots[i].draw();
        }

        self.console.resize(windowWidth, windowHeight);
        try self.console.update();
    }

    pub fn addPoints(self: *Self, plotName: []const u8, dataSetName: []const u8, points: []const rl.Vector2) !void {
        for (0..self.plots.len) |i| {
            if (std.mem.eql(u8, plotName, self.plots[i].name)) {
                try self.plots[i].addPoints(dataSetName, points);
                return;
            }
        }
        return GuiError.UnkownPlotName;
    }

    pub fn getCommand(self: *Self) ?[]const u8 {
        return self.console.getCommand();
    }

    pub fn resetCommand(self: *Self) void {
        self.console.resetCommand();
    }

    pub fn deinit(self: *Self) void {
        for (self.plots) |*plot| {
            plot.deinit();
        }
        self.console.deinit();
        self.allocator.free(self.plots);

        rl.closeWindow();
    }
};
