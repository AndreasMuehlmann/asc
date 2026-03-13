const std = @import("std");

const Track = @import("track").Track(true);
const TrackPoint = @import("track").TrackPoint;
const Position = @import("track").Position;
const SimulationArtificial = @import("simulationArtificial.zig").SimulationArtificial;
const SimulationCsv = @import("simulationCsv.zig").SimulationCsv;
const Controller = @import("controller.zig").Controller;

const guiApi = @import("gui.zig");
const Gui = guiApi.Gui;
const rl = @import("raylib");

const DistancePosition = struct { distance: f32, position: rl.Vector2 };

fn trackPointsFromCsv(allocator: std.mem.Allocator, filePath: []const u8) ![]TrackPoint {
    const file = try std.fs.cwd().openFile(filePath, .{});
    defer file.close();

    var buf: [4096]u8 = undefined;
    var file_reader = file.reader(&buf);

    const reader = &file_reader.interface;

    var trackPoints = try std.ArrayList(TrackPoint).initCapacity(allocator, 10);
    _ = try reader.takeDelimiterExclusive('\n');
    reader.toss(1);
    while (reader.takeDelimiterExclusive('\n')) |line| {
        reader.toss(1);

        var iter = std.mem.tokenizeScalar(u8, line, ',');

        const trackPoint: TrackPoint = .{
            .distance = try std.fmt.parseFloat(f32, iter.next().?),
            .heading = try std.fmt.parseFloat(f32, iter.next().?),
        };
        try trackPoints.append(allocator, trackPoint);
    } else |err| {
        if (err != error.EndOfStream) return err;
    }

    return try trackPoints.toOwnedSlice(allocator);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

   //const pointCount: usize = 721;
   //const density: f32 = 1.0;
   //const densityUsize: usize = @intFromFloat(density);
   //var trackPointsArrayList = try std.ArrayList(TrackPoint).initCapacity(allocator, pointCount * densityUsize + 1);
   //for (0..pointCount * densityUsize + 1) |i| {
   //    const iF32: f32 = @floatFromInt(i);
   //    try trackPointsArrayList.append(allocator, .{
   //        .distance = iF32 * 0.01 / density,
   //        .heading = @mod(std.math.sin(iF32 / density / 360 * 2 * std.math.pi) * 150 + 360, 360),
   //    });
   //}
   //const trackPoints = try trackPointsArrayList.toOwnedSlice(allocator);
    
    const trackPoints = try trackPointsFromCsv(allocator, "../../data/trackFirstTry.csv");
    var track = try Track.init(allocator, trackPoints);
    defer track.deinit();

    //var prng: std.Random.DefaultPrng = std.Random.DefaultPrng.init(blk: {
    //    var seed: u64 = undefined;
    //    try std.posix.getrandom(std.mem.asBytes(&seed));
    //    break :blk seed;
    //});
    //var rng: std.Random = prng.random();
    //var simulation = SimulationArtificial.init(&track, 0.0, 1.0, 0.01, 0.01, 0.01, 0.001, 0.01, &rng);
    //const ControllerT = Controller(SimulationArtificial);


    var simulation = try SimulationCsv.init(allocator, "../../data/firstMapTrackAttempt.csv", track.getTrackLength());
    defer simulation.deinit(allocator);
    const ControllerT = Controller(SimulationCsv);

    var gui = try Gui.init(allocator);

    var positions = try allocator.alloc(rl.Vector2, track.distancePositions.len);
    for (track.distancePositions, 0..) |distancePosition, i| {
        positions[i] = rl.Vector2.init(distancePosition.position.x, distancePosition.position.y);
    }
    try gui.addPoints("Track", "Track", positions);

    var trackPointsGui = try allocator.alloc(rl.Vector2, track.trackPoints.len);
    for (track.trackPoints, 0..) |trackPoint, i| {
        trackPointsGui[i] = rl.Vector2.init(trackPoint.distance, trackPoint.heading);
    }
    try gui.addPoints("TrackDistance", "TrackDistance", trackPointsGui);

    var controller: ControllerT = try ControllerT.init(allocator, &simulation, &track);

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
        gui.actualCarPositionAndHeading = .{ .heading = simulation.heading + headingError, .position = rl.Vector2.init(actualCarPosition.x, actualCarPosition.y) };

        gui.carDistanceAndHeading = .{ .x = controller.distance, .y = controller.heading };
        const measuredCarPosition: Position = track.distanceToPosition(controller.distance);
        gui.setCarPositionAndHeading(controller.heading, rl.Vector2.init(measuredCarPosition.x, measuredCarPosition.y));
        std.Thread.sleep(@intFromFloat(simulation.deltaTime * 1_000_000_000));
    }
}
