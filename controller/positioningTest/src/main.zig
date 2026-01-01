const std = @import("std");

const t = @import("track.zig");
const Track = t.Track;
const TrackPoint = t.TrackPoint;
const Position = t.Position;
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

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 720);
    for (0..361) |i| {
        const iF32: f32 = @floatFromInt(i);
        try trackPoints.append(allocator, .{
            .distance = iF32 * 0.01,
            .heading = @mod(std.math.sin(iF32 / 360 * 2 * std.math.pi) * 150 + 360, 360),
        });
    }
   //for (0..181) |i| {
   //    const iF32: f32 = @floatFromInt(i);
   //    try trackPoints.append(allocator, .{
   //        .distance = iF32 * 0.01,
   //        .heading = @mod(quadraticEaseOut(iF32), 360),
   //    });
   //}
   //for (0..181) |i| {
   //    const iF32: f32 = @floatFromInt(i);
   //    try trackPoints.append(allocator, .{
   //        .distance =  1.81 + iF32 * 0.01,
   //        .heading = @mod(trackPoints.items[i].heading + 180, 360),
   //    });
   //}
    var track = try Track.init(allocator, trackPoints);
    defer track.deinit();

    
    var prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(blk: {
        var seed: u64 = undefined;
        try std.posix.getrandom(std.mem.asBytes(&seed));
        break :blk seed;
    });
    var rng: std.Random = prng.random();

    var simulation = Simulation.init(&track, 0.0, 0.5, 0.01, 1.0, 1.2, 0.1, 0.2, &rng);
    var gui = try Gui.init(allocator);

    var positions = try allocator.alloc(rl.Vector2, track.distancePositions.items.len);
    for (track.distancePositions.items, 0..) |distancePosition, i| {
        positions[i] = rl.Vector2.init(distancePosition.position.x, distancePosition.position.y);
    }
    try gui.addPoints("Track", "Track", positions);

    var controller: Controller = Controller.init(&simulation, &track);

    while (true) {
        std.debug.print("update\n", .{});
        simulation.update();
        controller.update();
        std.debug.print("time: {d:.2}, controller: distance: {d:.2}, velocity: {d:.2}, heading: {d:.2}, distance: {d:.2}, heading: {d:.2}, measuredAngularRate: {d:.2}, measuredVelocity: {d:.2}\n", .{simulation.time, controller.distance, controller.velocity, controller.heading, simulation.distance, simulation.heading, simulation.measuredAngularRate, simulation.measuredVelocity});

        const actualCarPosition: Position = track.distanceToPosition(simulation.distance);
        gui.actualCarPositionAndHeading = .{.heading = simulation.heading, .position = rl.Vector2.init(actualCarPosition.x, actualCarPosition.y)};

        const measuredCarPosition: Position = track.distanceToPosition(controller.distance);
        gui.setCarPositionAndHeading(controller.heading, rl.Vector2.init(measuredCarPosition.x, measuredCarPosition.y));
        gui.update() catch |err| switch (err) {
            guiApi.GuiError.Quit => return,
            else => return err,
        };
        std.debug.print("end\n", .{});
        std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
    }
}
