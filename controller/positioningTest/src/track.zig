const std = @import("std");

pub const TrackPoint = struct {
    distance: f32,
    heading: f32,
};

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

    pub fn init(allocator: std.mem.Allocator, trackPoints: std.ArrayList(TrackPoint)) !Self {
        if (trackPoints.items.len < 2) {
            @panic("There must be at least two track points.");
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
            .distancePositions = try std.ArrayList(DistancePosition).initCapacity(allocator, 720),
        };
        try self.trackPointsToDistancePositions();
        return self;
    }

    pub fn trackPointsToDistancePositions(self: *Self) !void {
        var prevPosition: Position = .{.x = 0.0, .y = 0.0};
        try self.distancePositions.append(self.allocator, .{.distance = 0.0, .position = prevPosition});
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            const diffDistance = trackPoint.distance - prevTrackPoint.distance;
            const averageHeading = (trackPoint.heading + prevTrackPoint.heading) / 2.0;

            const currentPosition: Position = .{
                .x = prevPosition.x + -std.math.cos(averageHeading * std.math.pi / 180.0) * diffDistance,
                .y = prevPosition.y + std.math.sin(averageHeading * std.math.pi / 180.0) * diffDistance,
            };
            try self.distancePositions.append(self.allocator, .{.distance = trackPoint.distance, .position = currentPosition});
            prevPosition = currentPosition;
        }
    }

    pub fn getTrackLength(self: Self) f32 {
        return self.trackPoints.items[self.trackPoints.items.len - 1].distance;
    }

    pub fn distanceToHeading(self: Self, distance: f32) f32 {
        const lastPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        if (distance > lastPoint.distance) {
            @panic("distance can never be greater than last point");
           //const heading: f32 = lastPoint.heading * distance / lastPoint.distance;
           //return @mod(heading, 360.0);
        }
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (prevTrackPoint.distance <= distance and distance <= trackPoint.distance) {
                return std.math.lerp(prevTrackPoint.heading, trackPoint.heading, (distance - prevTrackPoint.distance) / (trackPoint.distance - prevTrackPoint.distance));
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
                return angularDelta(prevTrackPoint.heading, trackPoint.heading) / (trackPoint.distance - prevTrackPoint.distance);
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
                const t = (distance - prevDistancePosition.distance) / (distancePosition.distance - prevDistancePosition.distance);
                return .{
                    .x = std.math.lerp(prevDistancePosition.position.x, distancePosition.position.x, t),
                    .y = std.math.lerp(prevDistancePosition.position.y, distancePosition.position.y, t),
                };
            }
        }
        @panic("distance could not be converted to position");
    }

    fn minDifferenceDistances(self: Self, a: f32, b: f32) f32 {
        const d = @abs(a - b);
        return @min(d, @max(0, self.getTrackLength() - d));
    }

    fn angularDistance(a: f32, b: f32) f32 {
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

    pub fn deinit(self: *Self) void {
        self.trackPoints.deinit(self.allocator);
        self.distancePositions.deinit(self.allocator);
    }
};

test "distanceToHeading" {
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
        const distance: f32 = 3.595;
        const heading = track.distanceToHeading(distance);
        try std.testing.expectApproxEqAbs(359.5, heading, 1e-4);
    }

    {
        const distance: f32 = 0.0;
        const heading = track.distanceToHeading(distance);
        try std.testing.expectApproxEqAbs(0.0, heading, 1e-6);
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
