const std = @import("std");

const t = @import("track.zig");
const Track = t.Track;
const TrackPoint = t.TrackPoint;
const Position = t.Position;
const Simulation = @import("simulation.zig").Simulation;

const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const rl = @import("raylib");

const DistancePosition = struct {
    distance: f32,
    position: rl.Vector2
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 720);
    for (0..360) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01,
            .heading = @mod(iF32, 360),
        });
    }
    var track = try Track.init(allocator, trackPoints);
    defer track.deinit();

    
    var prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var rng: std.Random = prng.random();

    var simulation = Simulation.init(&track, 0.0, 0.5, 0.01, 0.1, 0.1, 0.01, -0.01, &rng);
    var gui = try Gui.init(allocator);

    var positions = try allocator.alloc(rl.Vector2, track.distancePositions.items.len);
    for (track.distancePositions.items, 0..) |distancePosition, i| {
        positions[i] = rl.Vector2.init(distancePosition.position.x, distancePosition.position.y);
    }
    try gui.addPoints("Track", "Track", positions);

    while (true) {

        gui.update() catch |err| switch (err) {
            guiApi.GuiError.Quit => return,
            else => return err,
        };
        const carPosition: Position = track.distanceToPosition(simulation.distance);
        gui.setCarPositionAndHeading(simulation.heading, rl.Vector2.init(carPosition.x, carPosition.y));
        std.debug.print("time: {d:.2}, distance: {d:.2}, heading: {d:.2}, measuredAngularRate: {d:.2}, measuredVelocity: {d:.2}\n", .{simulation.time, simulation.distance, simulation.heading, simulation.measuredAngularRate, simulation.measuredVelocity});
        simulation.update();
        std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
    }
}
