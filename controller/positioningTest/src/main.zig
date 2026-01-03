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

    var simulation = Simulation.init(&track, 0.0, 0.5, 0.01, 0.01, 0.01, 0.001, 0.1, &rng);
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

    var positionsWithHeadings = try std.ArrayList(guiApi.PositionAndHeading).initCapacity(allocator, 10);
    defer positionsWithHeadings.deinit(allocator);

    var positionsWithHeadingsIcp = try std.ArrayList(guiApi.PositionAndHeading).initCapacity(allocator, 10);
    defer positionsWithHeadingsIcp.deinit(allocator);

    var distanceWithHeadings = try std.ArrayList(rl.Vector2).initCapacity(allocator, 10);
    defer distanceWithHeadings.deinit(allocator);

   //var movedTrackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 10);
   //defer movedTrackPoints.deinit(allocator);

    while (true) {
        std.debug.print("trackLength: {d}\n", .{track.getTrackLength()});
        gui.update() catch |err| switch (err) {
            guiApi.GuiError.Quit => return,
            else => return err,
        };
        if (gui.paused) {
            std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
            continue;
        }
        simulation.update();
        controller.update();
        positionsWithHeadings.clearRetainingCapacity();
        for (controller.icpSource[0..controller.icpSourceLen]) |trackPoint| {
            const position = track.distanceToPosition(trackPoint.distance);
            try positionsWithHeadings.append(allocator, .{ .position = rl.Vector2.init(position.x, position.y), .heading = trackPoint.heading });
        }
        gui.tangents = positionsWithHeadings.items;

        positionsWithHeadingsIcp.clearRetainingCapacity();
        for (controller.icpSource[0..controller.icpSourceLen]) |trackPoint| {
            const position = track.distanceToPosition(@mod(trackPoint.distance + controller.icpOffset, track.getTrackLength()));
            try positionsWithHeadingsIcp.append(allocator, .{ .position = rl.Vector2.init(position.x, position.y), .heading = trackPoint.heading });
        }
        gui.tangentsIcp = positionsWithHeadingsIcp.items;

        distanceWithHeadings.clearRetainingCapacity();
        for (controller.icpSource[0..controller.icpSourceLen]) |trackPoint| {
            try distanceWithHeadings.append(allocator, rl.Vector2.init(trackPoint.distance + controller.icpOffset, trackPoint.heading));
        }
        gui.prevPointsIcp = distanceWithHeadings.items;
        
        //Raw ICP test
       //movedTrackPoints.clearRetainingCapacity();
       //for (track.trackPoints.items) |trackPoint| {
       //    try movedTrackPoints.append(allocator, .{ .distance = trackPoint.distance + 10.0, .heading = trackPoint.heading });
       //}
       //const offset = track.getOffsetIcp(movedTrackPoints.items);
       //
       //distanceWithHeadings.clearRetainingCapacity();
       //for (movedTrackPoints.items) |trackPoint| {
       //    try distanceWithHeadings.append(allocator, rl.Vector2.init(trackPoint.distance + offset, trackPoint.heading));
       //}
       //gui.prevPointsIcp = distanceWithHeadings.items;
        
        //std.debug.print("time: {d:.2}, controller: distance: {d}, velocity: {d:.2}, heading: {d:.2}, distance: {d:.2}, heading: {d:.2}, measuredAngularRate: {d:.2}, measuredVelocity: {d:.2}\n", .{simulation.time, controller.distance, controller.velocity, controller.heading, simulation.distance, simulation.heading, simulation.measuredAngularRate, simulation.measuredVelocity});

        const actualCarPosition: Position = track.distanceToPosition(simulation.distance);
        gui.actualCarPositionAndHeading = .{ .heading = simulation.heading, .position = rl.Vector2.init(actualCarPosition.x, actualCarPosition.y)};

        gui.carDistanceAndHeading = .{ .x =  controller.distance, .y = controller.heading };
        const measuredCarPosition: Position = track.distanceToPosition(controller.distance);
        gui.setCarPositionAndHeading(controller.heading, rl.Vector2.init(measuredCarPosition.x, measuredCarPosition.y));
        //std.debug.print("end\n", .{});
        std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
    }
}
