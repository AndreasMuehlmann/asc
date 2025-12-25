const std = @import("std");

const rl = @import("raylib");

pub const PlotError = error{
    UnkownDataSetName,
};

pub const DataSet = struct {
    points: std.ArrayList(rl.Vector2),
    color: rl.Color,
    name: [:0]const u8,
    lineWidth: f32,
};

pub const Plot = struct {
    allocator: std.mem.Allocator,
    name: [:0]const u8,
    nameXAxis: [:0]const u8,
    color: rl.Color,
    moving: bool,

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

    pub fn init(allocator: std.mem.Allocator, name: [:0]const u8, nameXAxis: [:0]const u8, color: rl.Color, moving: bool, relativeTopLeft: rl.Vector2, relativeSize: rl.Vector2, minCoord: rl.Vector2, maxCoord: rl.Vector2, margin: f32, windowWidth: f32, windowHeight: f32, dataSets: []DataSet) Self {
        var self: Self = .{
            .allocator = allocator,
            .name = name,
            .nameXAxis = nameXAxis,
            .color = color,
            .moving = moving,

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
        if (self.moving) {
            for (dataSet.points.items) |point| {
                if (point.x >= self.minCoord.x) {
                    break;
                }
                indexFirstPoint += 1;
            }
            if (indexFirstPoint >= dataSet.points.items.len) {
                return;
            }
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
        if (self.moving) {
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
                    self.dataSets[i].points.clearRetainingCapacity();
                    try self.dataSets[i].points.appendSlice(self.allocator, &buffer);
                }
            }
        }

        for (points) |point| {
            if (point.y > self.maxCoord.y) {
                self.maxCoord.y = point.y;
            } else if (point.y < self.minCoord.y) {
                self.minCoord.y = point.y;
            } 
            if (!self.moving and point.x > self.maxCoord.x) {
                self.maxCoord.x = point.x;
            } else if (!self.moving and point.x < self.minCoord.x) {
                self.minCoord.x = point.x;
            }
        }

        for (0..self.dataSets.len) |i| {
            if (std.mem.eql(u8, dataSetName, self.dataSets[i].name)) {
                try self.dataSets[i].points.appendSlice(self.allocator, points);
                return;
            }
        }
        return PlotError.UnkownDataSetName;
    }

    pub fn deinit(self: *Self) void {
        for (self.dataSets) |*dataSet| {
            dataSet.points.deinit(self.allocator);
        }
        self.allocator.free(self.dataSets);
    }
};
