const std = @import("std");
const Simulation = @import("simulation.zig").Simulation;
const Track = @import("track.zig").Track;
const TrackPoint = @import("trackPoint.zig").TrackPoint;
const mat = @import("matrixUtils.zig");
const RingBuffer = @import("ringBuffer.zig").RingBuffer;



pub const Controller = struct {
    const Self = @This();
    const icpPointCount: usize = 100;

    simulation: *Simulation,
    track: *Track,
    icpSource: std.ArrayListUnmanaged(TrackPoint),
    prevDistances: RingBuffer(f32, icpPointCount),
    prevAngularRates: RingBuffer(f32, icpPointCount - 1),
    distance: f32,
    velocity: f32,
    heading: f32,
    pMat: [2][2]f32,
    fMat: [2][2]f32,
    qMat: [2][2]f32,
    rMat: [2][2]f32,

    pub fn init(allocator: std.mem.Allocator, simulation: *Simulation, track: *Track) !Self {
        var prevDistances = RingBuffer(f32, icpPointCount).init();
        prevDistances.append(0.0);
        const prevAngularRates = RingBuffer(f32, icpPointCount - 1).init();

        var icpSource = try std.ArrayListUnmanaged(TrackPoint).initCapacity(allocator, icpPointCount);
        icpSource.appendAssumeCapacity(track.trackPoints.items[0]);
        return .{
            .simulation = simulation,
            .track = track,
            .icpSource = try std.ArrayListUnmanaged(TrackPoint).initCapacity(allocator, icpPointCount),
            .prevDistances = prevDistances,
            .prevAngularRates = prevAngularRates,
            .distance = simulation.distance,
            .velocity = simulation.velocity,
            .heading = simulation.heading,
            .pMat = [_][2]f32{
                .{ 0.0001, 0.0 },
                .{ 0.0, 0.0001 },
            },
            // with acceleration F = [1, dt, 1/2 dt*dt; 0, 1, dt]
            .fMat = [_][2]f32{
                .{ 1.0, simulation.deltaTime },
                .{ 0.0, 1.0 },
            },
            .qMat = [_][2]f32{
                .{ 0.1, 0.0 },
                .{ 0.0, 0.01 },
            },
            .rMat = [_][2]f32{
                .{ simulation.angularRateNoise * simulation.angularRateNoise, 0.0 },
                .{ 0.0, simulation.velocityNoise * simulation.velocityNoise },
            },
        };
    }

    fn updateIcpSource(self: *Self, distancePrediction: f32) void {
        // dont take an old distance and go forward because that causes delay, use the current distance and go backwards
        self.icpSource.clearRetainingCapacity();
        var prevHeading = self.track.distanceToHeading(self.prevDistances.get(0));
        for (0..self.prevDistances.items.len - 1) |i| {
            const distance = self.prevDistances.get(i + 1);
            const angularRate = self.prevAngularRates.get(i);
            const heading = prevHeading + angularRate * self.simulation.deltaTime;
            self.icpSource.appendAssumeCapacity(.{.distance = distance, .heading = heading});
            prevHeading = heading;
        }
        self.icpSource.appendAssumeCapacity(.{ .distance = distancePrediction, .heading = prevHeading + self.simulation.measuredAngularRate * self.simulation.deltaTime });
       //std.debug.print("TrackPoints: ", .{});
       //for (self.icpSource.items) |trackPoint| {
       //    std.debug.print("d {d:.2}, h {d:.2}; ", .{trackPoint.distance, trackPoint.heading});
       //}
       //std.debug.print("\n", .{});
    }

    fn updateRingBuffers(self: *Self) void {
        self.prevDistances.append(self.distance);
        self.prevAngularRates.append(self.simulation.measuredAngularRate);
    }

    fn distanceMeasurementThroughHeading(self: Self, xVecPred: [2]f32) f32 {
        const icpOffset = self.track.getOffsetIcp(self.icpSource.items);
        const icpDistanceGuess = xVecPred[0] + icpOffset;
        const measuredHeading = @mod(self.heading + self.simulation.measuredAngularRate * self.simulation.deltaTime, 360);
        const trackPoint: TrackPoint = .{.distance = xVecPred[0], .heading = measuredHeading};
        const closest: TrackPoint = self.track.getClosestPoint(trackPoint);
        std.debug.print("icpOffset: {d:.7}, icpDistanceGuess: {d:.2}, actualDistanceGuess: {d:2}, offset: {d:.6}\n", .{icpOffset, icpDistanceGuess, closest.distance, @abs(closest.distance - icpDistanceGuess)});
       //if (self.prevDistances.items.len == self.prevDistances.capacity) {
       //    return icpDistanceGuess;
       //}
        return closest.distance;
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
};
