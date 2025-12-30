const std = @import("std");

const t = @import("track.zig");
const Track = t.Track;
const TrackPoint = t.TrackPoint;


pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

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

    var distance: f32 = 3.595;
    var estimatedHeading: f32 = track.distanceToHeading(distance);
    std.debug.print("estimatedHeading for distance {d}: {d}\n", .{distance, estimatedHeading});

    distance = 0;
    estimatedHeading = track.distanceToHeading(distance);
    std.debug.print("estimatedHeading for distance {d}: {d}\n", .{distance, estimatedHeading});

    var heading: f32 = 32.5;
    var approximateDistance: f32 = 30.0;
    var estimatedDistance: f32 = track.headingToDistance(heading, approximateDistance);
    std.debug.print("estimatedDistance for heading {d} and approximateDistance {d}: {d}\n", .{heading, approximateDistance, estimatedDistance});

    heading = 440.0 - 360.0;
    approximateDistance = 450.0;
    estimatedDistance = track.headingToDistance(heading, approximateDistance);
    std.debug.print("estimatedDistance for heading {d} and approximateDistance {d}: {d}\n", .{heading, approximateDistance, estimatedDistance});
}
