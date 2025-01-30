const std = @import("std");

const rl = @import("raylib");

pub const GuiError = error{
    UnkownDataSetName,
    UnkownPlotName,
    Quit,
};

const DataSet = struct {
    points: std.ArrayList(rl.Vector2),
    color: rl.Color,
    name: []const u8,
    lineWidth: f32,
};

const Plot = struct {
    allocator: std.mem.Allocator,
    name: []const u8,
    color: rl.Color,

    relativeTopLeft: rl.Vector2,
    relativeSize: rl.Vector2,
    margin: f32,

    minCoord: rl.Vector2,
    maxCoord: rl.Vector2,

    topLeft: rl.Vector2,
    size: rl.Vector2,

    scaling: rl.Vector2,

    dataSets: []DataSet,

    const Self = @This();
    const lineThickness: u8 = 3;

    pub fn init(allocator: std.mem.Allocator, name: []const u8, color: rl.Color, relativeTopLeft: rl.Vector2, relativeSize: rl.Vector2, minCoord: rl.Vector2, maxCoord: rl.Vector2, margin: f32, windowWidth: f32, windowHeight: f32, dataSets: []DataSet) Self {
        var self: Self = .{
            .allocator = allocator,
            .name = name,
            .color = color,

            .relativeTopLeft = relativeTopLeft,
            .relativeSize = relativeSize,
            .margin = margin,

            .minCoord = minCoord,
            .maxCoord = maxCoord,

            .topLeft = rl.Vector2.zero(),
            .size = rl.Vector2.zero(),

            .scaling = rl.Vector2.zero(),

            .dataSets = dataSets,
        };
        self.resize(windowWidth, windowHeight);
        return self;
    }

    pub fn resize(self: *Self, windowWidth: f32, windowHeight: f32) void {
        self.topLeft = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeTopLeft).addValue(self.margin);
        self.size = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeSize).addValue(-2 * self.margin);

        self.scaling = .{ .x = self.size.x / (self.maxCoord.x - self.minCoord.x), .y = self.size.y / (self.maxCoord.y - self.minCoord.y) };
    }

    fn toGlobal(self: Self, point: rl.Vector2) rl.Vector2 {
        return .{
            .x = self.topLeft.x + (point.x - self.minCoord.x) * self.scaling.x,
            .y = self.topLeft.y + self.size.y - (point.y - self.minCoord.y) * self.scaling.y,
        };
    }

    pub fn draw(self: Self) void {
        for (self.dataSets) |dataSet| {
            self.drawDataSet(dataSet);
        }
    }

    fn drawDataSet(self: Self, dataSet: DataSet) void {
        if (dataSet.points.items.len == 0) {
            return;
        }
        var indexFirstPoint: usize = 0;
        for (dataSet.points.items) |point| {
            if (point.x >= self.minCoord.x) {
                break;
            }
            indexFirstPoint += 1;
        }
        var prevPoint = self.toGlobal(dataSet.points.items[indexFirstPoint]);
        for (indexFirstPoint + 1..dataSet.points.items.len) |i| {
            if (dataSet.points.items[i].x > self.maxCoord.x) {
                break;
            }
            const nextPoint = self.toGlobal(dataSet.points.items[i]);
            rl.drawLineEx(prevPoint, nextPoint, dataSet.lineWidth, dataSet.color);

            prevPoint = nextPoint;
        }
    }

    pub fn addPoints(self: *Self, dataSetName: []const u8, points: []const rl.Vector2) !void {
        if (points[points.len - 1].x > self.maxCoord.x) {
            self.minCoord.x += points[points.len - 1].x - self.maxCoord.x;
            self.maxCoord.x = points[points.len - 1].x;
        }

        var maxPointCount: usize = 0;
        for (self.dataSets) |dataSet| {
            maxPointCount = @max(maxPointCount, dataSet.points.items.len);
        }
        if (maxPointCount > 2000) {
            const restoredPoints: usize = 500;
            var buffer: [restoredPoints]rl.Vector2 = undefined;
            for (0..self.dataSets.len) |i| {
                @memcpy(&buffer, self.dataSets[i].points.items[self.dataSets[i].points.items.len - restoredPoints ..]);
                self.dataSets[i].points.clearAndFree();
                try self.dataSets[i].points.ensureTotalCapacity(restoredPoints);
                try self.dataSets[i].points.appendSlice(&buffer);
            }
        }

        for (points) |point| {
            if (point.y > self.maxCoord.y) {
                self.maxCoord.y = point.y;
            } else if (point.y < self.minCoord.y) {
                self.minCoord.y = point.y;
            }
        }

        for (0..self.dataSets.len) |i| {
            if (std.mem.eql(u8, dataSetName, self.dataSets[i].name)) {
                try self.dataSets[i].points.appendSlice(points);
                return;
            }
        }
        return GuiError.UnkownDataSetName;
    }

    pub fn deinit(self: Self) void {
        for (self.dataSets) |dataSet| {
            dataSet.points.deinit();
        }
        self.allocator.free(self.dataSets);
    }
};

pub const Gui = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    plots: []Plot,

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

        var dataSetsYaw = try allocator.alloc(DataSet, 1);
        dataSetsYaw[0] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Heading", .color = rl.Color.dark_blue, .lineWidth = 3.0 };

        var dataSetsAcceleration = try allocator.alloc(DataSet, 3);
        dataSetsAcceleration[0] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration x", .color = rl.Color.dark_purple, .lineWidth = 2.0 };
        dataSetsAcceleration[1] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration y", .color = rl.Color.gold, .lineWidth = 2.0 };
        dataSetsAcceleration[2] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration z", .color = rl.Color.red, .lineWidth = 2.0 };

        var plots = try allocator.alloc(Plot, 2);
        plots[0] = Plot.init(allocator, "Yaw", rl.Color.black, rl.Vector2.init(0.0, 0.0), rl.Vector2.init(1.0, 0.5), rl.Vector2.init(0, 0.0), rl.Vector2.init(10_000.0, 360.0), 30, windowWidthF, windowHeightF, dataSetsYaw);
        plots[1] = Plot.init(allocator, "Acceleration", rl.Color.black, rl.Vector2.init(0.0, 0.5), rl.Vector2.init(1.0, 0.5), rl.Vector2.init(0, -5.0), rl.Vector2.init(10_000.0, 5.0), 30, windowWidthF, windowHeightF, dataSetsAcceleration);
        return .{ .allocator = allocator, .plots = plots };
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

        for (0..self.plots.len) |i| {
            self.plots[i].resize(windowWidth, windowHeight);
            self.plots[i].draw();
        }
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

    pub fn deinit(self: Self) void {
        for (self.plots) |plot| {
            plot.deinit();
        }
        self.allocator.free(self.plots);

        rl.closeWindow();
    }
};
