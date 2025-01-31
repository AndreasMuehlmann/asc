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
    name: [:0]const u8,
    lineWidth: f32,
};

const Plot = struct {
    allocator: std.mem.Allocator,
    name: [:0]const u8,
    nameXAxis: [:0]const u8,
    color: rl.Color,

    relativeTopLeft: rl.Vector2,
    relativeSize: rl.Vector2,
    margin: f32,

    minCoord: rl.Vector2,
    maxCoord: rl.Vector2,

    topLeftPlot: rl.Vector2,
    sizePlot: rl.Vector2,
    topLeft: rl.Vector2,
    size: rl.Vector2,

    scaling: rl.Vector2,

    dataSets: []DataSet,

    const Self = @This();

    const lineThickness: f32 = 3.0;
    const marginCoords = rl.Vector2.init(40.0, 30.0);
    const marginNameXAxis = 20.0;
    const marginTitle = 30.0;
    const marginBetweenCoords = 100.0;
    const fontSizeTitle: i32 = 18;
    const fontSizeNameAxis: i32 = 15;
    const fontSizeCoords: i32 = 12;
    const marginLineCoords: f32 = 5.0;
    var array: [20]u8 = undefined;

    pub fn init(allocator: std.mem.Allocator, name: [:0]const u8, nameXAxis: [:0]const u8, color: rl.Color, relativeTopLeft: rl.Vector2, relativeSize: rl.Vector2, minCoord: rl.Vector2, maxCoord: rl.Vector2, margin: f32, windowWidth: f32, windowHeight: f32, dataSets: []DataSet) Self {
        var self: Self = .{
            .allocator = allocator,
            .name = name,
            .nameXAxis = nameXAxis,
            .color = color,

            .relativeTopLeft = relativeTopLeft,
            .relativeSize = relativeSize,
            .margin = margin,

            .minCoord = minCoord,
            .maxCoord = maxCoord,

            .topLeft = rl.Vector2.zero(),
            .size = rl.Vector2.zero(),

            .topLeftPlot = rl.Vector2.zero(),
            .sizePlot = rl.Vector2.zero(),

            .scaling = rl.Vector2.zero(),

            .dataSets = dataSets,
        };
        self.resize(windowWidth, windowHeight);
        return self;
    }

    pub fn resize(self: *Self, windowWidth: f32, windowHeight: f32) void {
        self.topLeft = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeTopLeft).addValue(self.margin);
        self.topLeftPlot = rl.Vector2.init(self.topLeft.x + marginCoords.x, self.topLeft.y + marginTitle);

        self.size = rl.Vector2.init(windowWidth, windowHeight).multiply(self.relativeSize).addValue(-2 * self.margin);
        self.sizePlot = rl.Vector2.init(self.size.x - marginCoords.x, self.size.y - marginTitle - marginCoords.y - marginNameXAxis);

        self.scaling = .{ .x = self.sizePlot.x / (self.maxCoord.x - self.minCoord.x), .y = self.sizePlot.y / (self.maxCoord.y - self.minCoord.y) };
    }

    fn toGlobal(self: Self, point: rl.Vector2) rl.Vector2 {
        return .{
            .x = self.topLeftPlot.x + (point.x - self.minCoord.x) * self.scaling.x,
            .y = self.topLeftPlot.y + self.sizePlot.y - (point.y - self.minCoord.y) * self.scaling.y,
        };
    }

    pub fn draw(self: Self) !void {
        const coordSysOrigin = rl.Vector2.init(self.topLeftPlot.x, self.topLeftPlot.y + self.sizePlot.y);
        const horizontalLineSize = rl.Vector2.init(self.sizePlot.x + lineThickness, lineThickness);

        rl.drawRectangleV(coordSysOrigin, horizontalLineSize, self.color);

        const countCoordinatesToShowX: usize = @intFromFloat(horizontalLineSize.x / marginBetweenCoords);
        const countCoordinatesToShowXF: f32 = @floatFromInt(countCoordinatesToShowX);
        for (0..countCoordinatesToShowX + 1) |i| {
            const iF: f32 = @floatFromInt(i);
            const coordTextPosX: f32 = coordSysOrigin.x + horizontalLineSize.x * iF / countCoordinatesToShowXF;
            const buffer = std.fmt.bufPrintZ(&array, "{d:.1}", .{self.minCoord.x + (self.maxCoord.x - self.minCoord.x) * iF / countCoordinatesToShowXF}) catch unreachable;
            const coordWidth: f32 = @floatFromInt(rl.measureText(buffer, fontSizeCoords));
            rl.drawText(buffer, @intFromFloat(coordTextPosX - coordWidth / 2.0), @intFromFloat(coordSysOrigin.y + lineThickness + marginLineCoords), fontSizeCoords, self.color);
        }
        const nameXAxisWidth: f32 = @floatFromInt(rl.measureText(self.nameXAxis, fontSizeNameAxis));
        rl.drawText(self.nameXAxis, @intFromFloat(self.topLeftPlot.x + self.sizePlot.x / 2.0 - nameXAxisWidth / 2.0), @intFromFloat(self.topLeft.y + self.size.y - marginNameXAxis), fontSizeNameAxis, self.color);

        const verticalLineSize = rl.Vector2.init(lineThickness, self.sizePlot.y + lineThickness);
        rl.drawRectangleV(self.topLeftPlot, verticalLineSize, self.color);

        const countCoordinatesToShowY: usize = @intFromFloat(verticalLineSize.y / marginBetweenCoords);
        const countCoordinatesToShowYF: f32 = @floatFromInt(countCoordinatesToShowY);
        for (0..countCoordinatesToShowY + 1) |i| {
            const iF: f32 = @floatFromInt(i);
            const coordTextPosY: f32 = coordSysOrigin.y - verticalLineSize.y * iF / countCoordinatesToShowYF;
            const buffer = std.fmt.bufPrintZ(&array, "{d:.1}", .{self.minCoord.y + (self.maxCoord.y - self.minCoord.y) * iF / countCoordinatesToShowYF}) catch unreachable;

            const coordWidth: f32 = @floatFromInt(rl.measureText(buffer, fontSizeCoords));
            rl.drawText(buffer, @intFromFloat(coordSysOrigin.x - lineThickness - coordWidth), @intFromFloat(coordTextPosY - 10.0), fontSizeCoords, self.color);
        }

        const titlePosX: i32 = @intFromFloat(self.topLeftPlot.x + self.sizePlot.x / 2.0);
        const titlePosY: i32 = @intFromFloat(self.topLeft.y);
        const titleWidth = rl.measureText(self.name, fontSizeTitle);
        rl.drawText(self.name, titlePosX - @divTrunc(titleWidth, 2), titlePosY, fontSizeTitle, self.color);

        for (0..self.dataSets.len, self.dataSets) |i, dataSet| {
            self.drawDataSet(dataSet);
            const iF: f32 = @floatFromInt(i);

            rl.drawText(dataSet.name, @intFromFloat(self.topLeftPlot.x + 10.0), @intFromFloat(self.topLeftPlot.y + iF * 15.0), fontSizeNameAxis, dataSet.color);
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
        rl.setWindowMinSize(800, 800);

        var dataSetsYaw = try allocator.alloc(DataSet, 1);
        dataSetsYaw[0] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Heading", .color = rl.Color.dark_blue, .lineWidth = 3.0 };

        var dataSetsAcceleration = try allocator.alloc(DataSet, 3);
        dataSetsAcceleration[0] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration x", .color = rl.Color.dark_purple, .lineWidth = 2.0 };
        dataSetsAcceleration[1] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration y", .color = rl.Color.gold, .lineWidth = 2.0 };
        dataSetsAcceleration[2] = .{ .points = std.ArrayList(rl.Vector2).init(allocator), .name = "Acceleration z", .color = rl.Color.red, .lineWidth = 2.0 };

        var plots = try allocator.alloc(Plot, 2);
        plots[0] = Plot.init(allocator, "Yaw", "Time in s", rl.Color.black, rl.Vector2.init(0.0, 0.0), rl.Vector2.init(1.0, 0.5), rl.Vector2.init(0, 0.0), rl.Vector2.init(5.0, 360.0), 30, windowWidthF, windowHeightF, dataSetsYaw);
        plots[1] = Plot.init(allocator, "Acceleration", "Time in s", rl.Color.black, rl.Vector2.init(0.0, 0.5), rl.Vector2.init(1.0, 0.5), rl.Vector2.init(0, -5.0), rl.Vector2.init(5.0, 5.0), 30, windowWidthF, windowHeightF, dataSetsAcceleration);
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
            try self.plots[i].draw();
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
