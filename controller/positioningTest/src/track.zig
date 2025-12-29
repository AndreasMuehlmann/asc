const std = @import("std");

pub const TrackPoint = struct {
    distance: f32,
    heading: f32,
};

pub const Track = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    trackPoints: std.ArrayList(TrackPoint),

    pub fn init(allocator: std.mem.Allocator, trackPoints: std.ArrayList(TrackPoint)) Self {
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
        return .{
            .allocator = allocator,
            .trackPoints = trackPoints,
        };
    }

    pub fn distanceToHeading(self: Self, distance: f32) f32 {
        const lastPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        if (distance > lastPoint.distance) {
            const heading: f32 = lastPoint.heading * distance / lastPoint.distance;
            return @mod(heading, 360.0);
        }
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (prevTrackPoint.distance <= distance and distance <= trackPoint.distance) {
                return std.math.lerp(prevTrackPoint.heading, trackPoint.heading, (distance - prevTrackPoint.distance) / (trackPoint.distance - prevTrackPoint.distance));
            }
        }
        @panic("distance could not be converted to heading");
    }

    pub fn headingToDistance(self: Self, heading: f32, approximateDistance: f32) f32 {
        var closest: ?f32 = null;
        const lastPoint = self.trackPoints.items[self.trackPoints.items.len - 1];
        if (heading > lastPoint.heading) {
            closest = lastPoint.distance * heading / lastPoint.heading;
        }
        for (self.trackPoints.items[0..self.trackPoints.items.len - 1], self.trackPoints.items[1..]) |prevTrackPoint, trackPoint| {
            if (prevTrackPoint.heading <= heading and heading <= trackPoint.heading) {
                const distance: f32 = std.math.lerp(prevTrackPoint.distance, trackPoint.distance, (heading - prevTrackPoint.heading) / (trackPoint.heading - prevTrackPoint.heading));
                if (closest) |c| {
                    if (@abs(approximateDistance - c) > @abs(approximateDistance - distance)) {
                        closest = distance;
                    }
                } else {
                    closest = distance;
                }
            }
        }

        if (closest == null) {
            @panic("heading could not be converted to distance");
        }
        return closest.?;
    }

    pub fn deinit(self: *Self) void {
        self.trackPoints.deinit(self.allocator);
    }
};
