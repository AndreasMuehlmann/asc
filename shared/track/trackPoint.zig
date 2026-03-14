const Track = @import("track.zig").Track(false);

pub var trackLength: f32 = 0.0;

pub const TrackPoint = struct {
    distance: f32,
    heading: f32,

    const Self = @This();

    pub fn init(distance: f64, heading: f64) Self {
        return .{
            .distance = @floatCast(distance),
            .heading = @floatCast(heading),
        };
    }

    pub fn getX(self: Self) f64 {
        return @floatCast(self.distance);
    }

    pub fn getY(self: Self) f64 {
        return @floatCast(self.heading);
    }

    pub fn minDifferenceDistances(a: f32, b: f32) f32 {
        if (trackLength == 0.0) {
            @panic("trackLength is 0");
        }
        const d = @abs(a - b);
        return @min(d, @max(0, trackLength - d));
    }

    pub fn distanceNoRoot(self: Self, point: Self) f64 {
        const distanceDiff = minDifferenceDistances(point.distance, self.distance);
        var headingDiff = Track.minDifferenceAngle(point.heading, self.heading);
        headingDiff *= 0.01;
        return distanceDiff * distanceDiff + headingDiff * headingDiff;
    }

    pub fn getDimension(self: Self, dimension: usize) f64 {
        if (dimension == 0) {
            return self.distance;
        } else if (dimension == 1) {
            return self.heading;
        }
        unreachable;
    }
};
