const std = @import("std");
const Simulation = @import("simulation.zig").Simulation;
const Track = @import("track").Track(true);
const TrackPoint = @import("track").TrackPoint;
const mat = @import("matrix");
const RingBuffer = @import("ringBuffer.zig").RingBuffer;



pub const Controller = struct {
    const Self = @This();
    const icpPointCount: usize = 100;

    allocator: std.mem.Allocator,
    simulation: *Simulation,
    track: *Track,
    icpSource: []TrackPoint,
    icpSourceLen: usize,
    icpOffset: f32,
    prevDistances: RingBuffer(f32),
    prevHeadings: RingBuffer(f32),
    distance: f32,
    velocity: f32,
    heading: f32,
    pMat: [2][2]f32,
    fMat: [2][2]f32,
    qMat: [2][2]f32,
    rMat: [2][2]f32,

    pub fn init(allocator: std.mem.Allocator, simulation: *Simulation, track: *Track) !Self {
        var prevDistances = try RingBuffer(f32).init(allocator, icpPointCount - 1);
        prevDistances.append(0.0);
        var prevHeadings = try RingBuffer(f32).init(allocator, icpPointCount - 1);
        prevHeadings.append(0.0);
        return .{
            .allocator = allocator,
            .simulation = simulation,
            .track = track,
            .icpSource = try allocator.alloc(TrackPoint, icpPointCount),
            .icpSourceLen = 0,
            .icpOffset = 0.0,
            .prevDistances = prevDistances,
            .prevHeadings = prevHeadings,
            .distance = simulation.distance,
            .velocity = simulation.velocity,
            .heading = simulation.heading,
            .pMat = [_][2]f32{
                .{ 0.5, 0.0 },
                .{ 0.0, 0.0001 },
            },
            // with acceleration F = [1, dt, 1/2 dt*dt; 0, 1, dt]
            .fMat = [_][2]f32{
                .{ 1.0, simulation.deltaTime },
                .{ 0.0, 1.0 },
            },
            .qMat = [_][2]f32{
                .{ 1.1, 0.0 },
                .{ 0.0, 0.01 },
            },
            .rMat = [_][2]f32{
                .{ 1.1, 0.0 },
                .{ 0.0, simulation.velocityNoise * simulation.velocityNoise },
            },
        };
    }

    fn updateIcpSource(self: *Self, distancePrediction: f32) void {
        const measuredHeading = @mod(self.heading + self.simulation.measuredAngularRate * self.simulation.deltaTime, 360);
        self.icpSource[self.prevDistances.len] = .{ .distance = distancePrediction, .heading = measuredHeading };
        for (0..self.prevDistances.len) |i| {
            self.icpSource[i] = .{.distance = self.prevDistances.get(i), .heading = self.prevHeadings.get(i)};
        }
        self.icpSourceLen = self.prevDistances.len + 1;
       //std.debug.print("TrackPoints: ", .{});
       //for (self.icpSource.items) |trackPoint| {
       //    std.debug.print("d {d:.2}, h {d:.2}; ", .{trackPoint.distance, trackPoint.heading});
       //}
       //std.debug.print("\n", .{});
    }

    fn updateRingBuffers(self: *Self) void {
        self.prevDistances.append(self.distance);
        self.prevHeadings.append(self.heading);
    }

    fn distanceMeasurementThroughHeading(self: *Self, xVecPred: [2]f32) f32 {
        self.icpOffset = self.track.getOffsetIcp(self.icpSource[0..self.icpSourceLen]);
        const measuredHeading = @mod(self.heading + self.simulation.measuredAngularRate * self.simulation.deltaTime, 360);
        const trackPoint: TrackPoint = .{.distance = xVecPred[0], .heading = measuredHeading};
        //const closest: TrackPoint = self.track.getClosestPoint(trackPoint);
        const icpDistanceGuess = @mod(xVecPred[0] + self.icpOffset, self.track.getTrackLength());
        _ = icpDistanceGuess;

        //std.debug.print("icpOffset: {d:.7}, icpDistanceGuess: {d:.2}, actualDistanceGuess: {d:2}, offset: {d:.6}\n", .{self.icpOffset, icpDistanceGuess, closest.distance, closest.distance - icpDistanceGuess});
       //if (self.prevDistances.len == self.prevDistances.capacity) {
       //    return 0.0 * icpDistanceGuess + 1.0 * closest.distance;
       //}

       //const direction: f32 = if (closest.distance >= xVecPred[0]) 1.0 else -1.0;
       //std.debug.print("{d}, {d}, {d}, {d}\n", .{closest.distance, xVecPred[0], direction, direction * self.track.minDifferenceDistances(self.distance, xVecPred[0]) * 0.5});
       //return xVecPred[0] + direction * self.track.minDifferenceDistances(self.distance, xVecPred[0]) * 0.5;
        
        const h = self.track.distanceToHeading(self.distance);
        const distanceGuessOld = self.track.getClosestPoint(trackPoint).distance;
        const distanceGuess = self.track.getClosestPointInterpolated(trackPoint).distance;
        std.debug.print("diffHeadingAtDistance {d}, diffInterpolated {d:.4}, diff {d:.4}\n", .{measuredHeading - h, distanceGuess - xVecPred[0], distanceGuessOld - xVecPred[0]});
        return distanceGuess;
        //return closest.distance;
    }

    pub fn update(self: *Self) void {
        const prevXVec: [2]f32 = [2]f32{ self.distance, self.velocity };
        var xVecPred: [2]f32 = mat.vectorMultiply(2, 2, self.fMat, prevXVec);
        xVecPred[0] = @mod(xVecPred[0], self.track.getTrackLength());
        const pMatPrediction: [2][2]f32 = mat.addWithCoefficients(2, 2, 1, 1, mat.multiply(2, 2, 2, mat.multiply(2, 2, 2, self.fMat, self.pMat), mat.transpose2D(self.fMat)), self.qMat);

        const hMat: [2][2]f32 = .{
            .{ 1.0, 0.0 },
            .{ 0.0, 1.0 },
        };

        const sMat: [2][2]f32 = mat.addWithCoefficients(2, 2, 1, 1, mat.multiply(2, 2, 2, hMat, mat.multiply(2, 2, 2, pMatPrediction, mat.transpose2D(hMat))), self.rMat);
        const kMat = mat.multiply(2, 2, 2, mat.multiply(2, 2, 2, pMatPrediction, mat.transpose2D(hMat)), mat.inverse2D(sMat));

        const predictedMeasurements: [2]f32 = xVecPred;

        self.updateIcpSource(xVecPred[0]);
        const yVec: [2]f32 = [2]f32{ self.distanceMeasurementThroughHeading(xVecPred) - predictedMeasurements[0], self.simulation.measuredVelocity - predictedMeasurements[1] };
        const adjustedYVec = mat.vectorMultiply(2, 2, kMat, yVec);

       //std.debug.print(
       //    "pMat:\n  [{d}, {d}]\n  [{d}, {d}]\n",
       //    .{
       //        self.pMat[0][0], self.pMat[0][1],
       //        self.pMat[1][0], self.pMat[1][1],
       //    },
       //);
        //std.debug.print("adjustedYVec: {d:.2}, {d:.2}; yVec: {d:.6}, {d:.2}\n", .{ adjustedYVec[0], adjustedYVec[1], yVec[0], yVec[1] });
        self.distance = @mod(xVecPred[0] + adjustedYVec[0], self.track.getTrackLength());
        self.velocity = xVecPred[1] + adjustedYVec[1];

        const identity: [2][2]f32 = [2][2]f32{
            .{ 1.0, 0.0 },
            .{ 0.0, 1.0 },
        };
        self.pMat = mat.multiply(2, 2, 2, mat.addWithCoefficients(2, 2, 1, -1, identity, mat.multiply(2, 2, 2, kMat, hMat)), pMatPrediction);
        self.heading = self.track.distanceToHeading(self.distance);

        self.updateRingBuffers();
    }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.icpSource);
        self.prevDistances.deinit(self.allocator);
        self.prevAngularRates.deinit(self.allocator);
    }
};
