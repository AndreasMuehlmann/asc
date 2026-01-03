const std = @import("std");
const TrackPoint = @import("trackPoint.zig").TrackPoint;
const kdTreeMod = @import("kdTree");
const KdTree = kdTreeMod.KdTree(TrackPoint, 2);
const icpMod = @import("icp");
const Icp = icpMod.Icp(TrackPoint);

pub const Position = struct {
    x: f32,
    y: f32,
};

pub const DistancePosition = struct {
    distance: f32,
    position: Position,
};

pub const Track = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    trackPoints: std.ArrayList(TrackPoint),
    distancePositions: std.ArrayList(DistancePosition),
    kdTree: KdTree,

    pub fn init(allocator: std.mem.Allocator, trackPoints: std.ArrayList(TrackPoint)) !Self {
        if (trackPoints.items.len < 3) {
            @panic("There must be at least three track points.");
        }
        if (trackPoints.items[0].distance != 0 or trackPoints.items[0].heading != 0) {
            @panic("The first track point must be (0, 0).");
        }
        for (trackPoints.items[0..trackPoints.items.len - 1], trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (trackPoint.distance <= prevTrackPoint.distance) {
                @panic("Distance has to grow strictly monotonic.");
            }
        }
        for (trackPoints.items) |trackPoint| {
            if (trackPoint.heading < 0 or 360.0 <= trackPoint.heading) {
                @panic("Heading must be in the interval [0;360).");
            }
        }
        var self: Self = .{
            .allocator = allocator,
            .trackPoints = trackPoints,
            .distancePositions = try std.ArrayList(DistancePosition).initCapacity(allocator, @divTrunc(trackPoints.items.len, 2) + 5),
            .kdTree = try KdTree.init(allocator, trackPoints.items),
        };
        std.mem.sort(TrackPoint, trackPoints.items, {},  struct {
            fn lessThan(_: void, a: TrackPoint, b: TrackPoint) bool {
                return a.distance < b.distance;
            }
        }.lessThan);
        try self.trackPointsToDistancePositions();
        return self;
    }

    pub fn trackPointsToDistancePositions(self: *Self) !void {
        var prevPosition: Position = .{.x = 0.0, .y = 0.0};
        try self.distancePositions.append(self.allocator, .{.distance = 0.0, .position = prevPosition});


        const countPointsNeedingSeperateHandling = (self.trackPoints.items.len - 1) % 2;
        if (countPointsNeedingSeperateHandling != 0) {
            const prevTrackPoint = self.trackPoints.items[0];
            const trackPoint = self.trackPoints.items[1];
            const diffDistance = trackPoint.distance - prevTrackPoint.distance;
            const averageHeading = (trackPoint.heading + prevTrackPoint.heading) / 2.0;

            const currentPosition: Position = .{
                .x = prevPosition.x + -std.math.cos(averageHeading * std.math.pi / 180.0) * diffDistance,
                .y = prevPosition.y + std.math.sin(averageHeading * std.math.pi / 180.0) * diffDistance,
            };
            try self.distancePositions.append(self.allocator, .{.distance = trackPoint.distance, .position = currentPosition});
            prevPosition = currentPosition;
        }

        for (countPointsNeedingSeperateHandling..self.trackPoints.items.len - 2) |i| {
            const diffDistance = self.trackPoints.items[i + 2].distance - self.trackPoints.items[i].distance;

            const midDistance = self.trackPoints.items[i].distance + self.minDifferenceDistances(self.trackPoints.items[i + 2].distance, self.trackPoints.items[i].distance) / 2;

            var beforeMid: TrackPoint = undefined;
            var afterMid: TrackPoint = undefined;
            if (self.trackPoints.items[i].distance <= midDistance and midDistance <= self.trackPoints.items[i + 1].distance) {
                beforeMid = self.trackPoints.items[i];
                afterMid = self.trackPoints.items[i + 1];

            } else {
                beforeMid = self.trackPoints.items[i + 1];
                afterMid = self.trackPoints.items[i + 2];
            }

            const midHeading = beforeMid.heading + angularDelta(beforeMid.heading, afterMid.heading) * self.minDifferenceDistances(midDistance, beforeMid.distance) / self.minDifferenceDistances(afterMid.distance, beforeMid.distance);
            
            const xFa = -std.math.cos(self.trackPoints.items[i].heading * std.math.pi / 180.0);
            const xFab = -std.math.cos(midHeading * std.math.pi / 180.0);
            const xFb = -std.math.cos(self.trackPoints.items[i + 2].heading * std.math.pi / 180.0);
            const xDiff = diffDistance / 6.0 * (xFa + 4 * xFab + xFb);

            const yFa = std.math.sin(self.trackPoints.items[i].heading * std.math.pi / 180.0);
            const yFab = std.math.sin(midHeading * std.math.pi / 180.0);
            const yFb = std.math.sin(self.trackPoints.items[i + 2].heading * std.math.pi / 180.0);
            const yDiff = diffDistance / 6.0 * (yFa + 4 * yFab + yFb);

            const currentPosition: Position = .{
                .x = prevPosition.x + xDiff,
                .y = prevPosition.y + yDiff,
            };
            try self.distancePositions.append(self.allocator, .{.distance = self.trackPoints.items[i + 2].distance, .position = currentPosition});
            prevPosition = currentPosition;
        }
    }

    pub fn getTrackLength(self: Self) f32 {
        return self.trackPoints.items[self.trackPoints.items.len - 1].distance;
    }

    // TODO: maybe use binary search
    pub fn distanceToHeading(self: Self, distance: f32) f32 {
        const lastPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        if (distance > lastPoint.distance) {
            @panic("distance can never be greater than last point");
        }
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (prevTrackPoint.distance <= distance and distance <= trackPoint.distance) {
                return prevTrackPoint.heading + angularDelta(prevTrackPoint.heading, trackPoint.heading) * self.minDifferenceDistances(distance, prevTrackPoint.distance) / self.minDifferenceDistances(trackPoint.distance, prevTrackPoint.distance);
            }
        }
        @panic("distance could not be converted to heading");
    }

    pub fn distanceToHeadingDerivative(self: Self, distance: f32) f32 {
        const lastPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        if (distance > lastPoint.distance) {
            @panic("distance can never be greater than last point");
        }
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (prevTrackPoint.distance <= distance and distance <= trackPoint.distance) {
                return angularDelta(prevTrackPoint.heading, trackPoint.heading) / self.minDifferenceDistances(trackPoint.distance, prevTrackPoint.distance);
            }
        }
        @panic("distance could not be converted to heading");
    }

    pub fn distanceToPosition(self: Self, distance: f32) Position {
        const lastPoint = self.distancePositions.items[self.distancePositions.items.len - 1];
        if (distance > lastPoint.distance) {
            return lastPoint.position;
        }
        for (self.distancePositions.items[0..self.distancePositions.items.len - 1], self.distancePositions.items[1..]) |prevDistancePosition, distancePosition| {
            if (prevDistancePosition.distance <= distance and distance <= distancePosition.distance) {
                const t = self.minDifferenceDistances(distance, prevDistancePosition.distance) / self.minDifferenceDistances(distancePosition.distance, prevDistancePosition.distance);
                return .{
                    .x = std.math.lerp(prevDistancePosition.position.x, distancePosition.position.x, t),
                    .y = std.math.lerp(prevDistancePosition.position.y, distancePosition.position.y, t),
                };
            }
        }
        @panic("distance could not be converted to position");
    }

    pub fn minDifferenceDistances(self: Self, a: f32, b: f32) f32 {
        const d = @abs(a - b);
        return @min(d, @max(0, self.getTrackLength() - d));
    }

    pub fn angularDistance(a: f32, b: f32) f32 {
        const d = @abs(a - b);
        return @min(d, 360.0 - d);
    }

    pub fn angularDelta(from: f32, to: f32) f32 {
        var d = @mod(to - from, 360.0);
        if (d >= 180.0) d -= 360.0;
        return d;
    }
    
    fn isInSegment(start: f32, end: f32, heading: f32) bool {
        return @abs((angularDistance(start, heading) + angularDistance(heading, end)) - angularDistance(start, end)) < 1e-5;
    }

    pub fn headingToDistance(self: Self, heading: f32, approximateDistance: f32) f32 {
        var closest: ?f32 = null;
        var prevTrackPoint: TrackPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        for (self.trackPoints.items) |trackPoint| {
            if (trackPoint.heading - prevTrackPoint.heading == 0) {
                prevTrackPoint = trackPoint;
                continue;
            }
            if (isInSegment(prevTrackPoint.heading, trackPoint.heading, heading)) {
                const seg = angularDelta(prevTrackPoint.heading, trackPoint.heading);
                const rel = angularDelta(prevTrackPoint.heading, heading);
                const t = rel / seg;

                const distance = prevTrackPoint.distance + t * self.minDifferenceDistances(prevTrackPoint.distance, trackPoint.distance);
                if (closest) |c| {
                    if (self.minDifferenceDistances(approximateDistance, c) > self.minDifferenceDistances(approximateDistance, distance)) {
                        closest = distance;
                    }
                } else {
                    closest = distance;
                }
            }
            prevTrackPoint = trackPoint;
        }
        if (closest == null) {
            @panic("heading could not be converted to distance");
        }
        return closest.?;
    }

    pub fn getClosestPoint(self: Self, point: TrackPoint) TrackPoint {
        return self.kdTree.nearestNeighbor(point).?;
    }

    pub fn getOffsetIcp(self: Self, points: []TrackPoint) f32 {
        const icp = Icp.init(points, &self.kdTree, 3);
        return @floatCast(icp.icp());
    }

    pub fn deinit(self: *Self) void {
        self.trackPoints.deinit(self.allocator);
        self.distancePositions.deinit(self.allocator);
    }
};

test "distanceToHeading" {
    const allocator = std.testing.allocator;

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 360);
    for (0..361) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01,
            .heading = iF32,
        });
    }

    var track = Track.init(allocator, trackPoints);
    defer track.deinit();

    {
        const distance: f32 = 3.595;
        const heading = track.distanceToHeading(distance);
        try std.testing.expectApproxEqAbs(359.5, heading, 1e-4);
    }

    {
        const distance: f32 = 0.0;
        const heading = track.distanceToHeading(distance);
        try std.testing.expectApproxEqAbs(0.0, heading, 1e-6);
    }
    {
        const distance: f32 = 3.5939434;
        const heading = track.distanceToHeading(distance);
        try std.testing.expectApproxEqAbs(3.59, heading, 1e-6);
    }
}

test "headingToDistance" {
    const allocator = std.testing.allocator;

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 360);
    for (0..360) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01,
            .heading = iF32,
        });
    }

    var track = Track.init(allocator, trackPoints);
    defer track.deinit();

    {
        const heading: f32 = 32.5;
        const approximateDistance: f32 = 0.3;
        const distance = track.headingToDistance(heading, approximateDistance);
        try std.testing.expectApproxEqAbs(0.325, distance, 1e-6);
    }

    {
        const heading: f32 = 359.5;
        const approximateDistance: f32 = 3.605;
        const distance = track.headingToDistance(heading, approximateDistance);
        try std.testing.expectApproxEqAbs(3.59, distance, 1e-4);
    }
}

test "headingToDistanceMoreComplicatedTrack" {
    const allocator = std.testing.allocator;

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 720);
    for (0..720) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01,
            .heading = @mod(iF32, 360),
        });
    }

    var track = Track.init(allocator, trackPoints);
    defer track.deinit();

    {
        const heading: f32 = 80.0;
        const approximateDistance: f32 = 4.50;
        const distance = track.headingToDistance(heading, approximateDistance);
        try std.testing.expectApproxEqAbs(4.4, distance, 1e-6);
    }

    {
        const heading: f32 = 359.0;
        const approximateDistance: f32 = 0.30;
        const distance = track.headingToDistance(heading, approximateDistance);
        try std.testing.expectApproxEqAbs(7.19, distance, 1e-4);
    }
}
