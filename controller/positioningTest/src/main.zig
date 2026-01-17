const std = @import("std");

const Track = @import("track.zig").Track;
const TrackPoint = @import("trackPoint.zig").TrackPoint;
const Position = @import("track.zig").Position;
const Simulation = @import("simulation.zig").Simulation;
const Controller = @import("controller.zig").Controller;

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

    const pointCount: usize = 721;
    const density: f32 = 10.0;
    const densityUsize: usize = @intFromFloat(density);
    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, pointCount * densityUsize + 1);
    for (0..pointCount * densityUsize + 1) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01 / density,
            .heading = @mod(std.math.sin(iF32 / density / 360 * 2 * std.math.pi) * 150 + 360, 360),
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

    var simulation = Simulation.init(&track, 0.0, 1.0, 0.01, 0.01, 0.01, 0.001, 0.1, &rng);
    var gui = try Gui.init(allocator);

    var positions = try allocator.alloc(rl.Vector2, track.distancePositions.items.len);
    for (track.distancePositions.items, 0..) |distancePosition, i| {
        positions[i] = rl.Vector2.init(distancePosition.position.x, distancePosition.position.y);
    }
    try gui.addPoints("Track", "Track", positions);

    var trackPointsGui = try allocator.alloc(rl.Vector2, track.trackPoints.items.len);
    for (track.trackPoints.items, 0..) |trackPoint, i| {
        trackPointsGui[i] = rl.Vector2.init(trackPoint.distance, trackPoint.heading);
    }
    try gui.addPoints("TrackDistance", "TrackDistance", trackPointsGui);

    var controller: Controller = try Controller.init(allocator, &simulation, &track);

    var distanceWithHeadings = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10);
    defer distanceWithHeadings.deinit(allocator);

    var headingError: f32 = 0.0;

    while (true) {
        gui.update() catch |err| switch (err) {
            guiApi.GuiError.Quit => return,
            else => return err,
        };
        if (gui.paused) {
            std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
            continue;
        }
        const prevHeading = simulation.heading;
        simulation.update();
        controller.update();

        //const decay = 1 - (factor1 * velocity / (10 * maxVelocity) + factor2 * pwm / (10 * maxPwm)) + factor3
        const decay = 0.95;
        headingError = (headingError + Track.angularDelta(prevHeading, simulation.heading)) * decay;
        distanceWithHeadings.clearRetainingCapacity();
        for (controller.icpSource[0..controller.icpSourceLen]) |trackPoint| {
            try distanceWithHeadings.append(allocator, rl.Vector2.init(trackPoint.distance, trackPoint.heading));
        }
        gui.prevPointsIcp = distanceWithHeadings.items;
        
        const actualCarPosition: Position = track.distanceToPosition(simulation.distance);
        gui.actualCarPositionAndHeading = .{ .heading = simulation.heading + headingError, .position = rl.Vector2.init(actualCarPosition.x, actualCarPosition.y)};

        gui.carDistanceAndHeading = .{ .x =  controller.distance, .y = controller.heading };
        const measuredCarPosition: Position = track.distanceToPosition(controller.distance);
        gui.setCarPositionAndHeading(controller.heading, rl.Vector2.init(measuredCarPosition.x, measuredCarPosition.y));
        std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
    }
}
