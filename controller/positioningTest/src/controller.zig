const std = @import("std");
const Simulation = @import("simulation.zig").Simulation;
const Track = @import("track.zig").Track;
const TrackPoint = @import("track.zig").TrackPoint;
const mat = @import("matrixUtils.zig");


pub const Controller = struct {
    const Self = @This();
    const icpPointCount: usize = 10;

    simulation: *Simulation,
    track: *Track,
    distance: f32,
    velocity: f32,
    heading: f32,
    pMat: [2][2]f32,
    fMat: [2][2]f32,
    qMat: [2][2]f32,
    rMat: [2][2]f32,

    pub fn init(simulation: *Simulation, track: *Track) Self {
        return .{
            .simulation = simulation,
            .track = track,
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

    fn distanceMeasurementThroughHeading(self: Self, xVecPred: [2]f32) f32 {
        const measuredHeading = @mod(self.heading + self.simulation.measuredAngularRate * self.simulation.deltaTime, 360);
        const trackPoint: TrackPoint = .{.distance = xVecPred[0], .heading = measuredHeading};
        const closest: TrackPoint = self.track.getClosestPoint(trackPoint);
        return closest.distance;
    }

    pub fn update(self: *Self) void {
        const prevXVec: [2]f32 = [2]f32{ self.distance, self.velocity };
        var xVecPred: [2]f32 = mat.vectorMultiply(2, 2, self.fMat, prevXVec);
        xVecPred[0] = @mod(xVecPred[0], self.track.getTrackLength());
        const pMatPrediction: [2][2]f32 = mat.addWithCoefficients(2, 2, 1, 1, mat.multiply(2, 2, 2, mat.multiply(2, 2, 2, self.fMat, self.pMat), mat.transpose2D(self.fMat)), self.qMat);

        // const headingDerivative = self.track.distanceToHeadingDerivative(xVecPred[0]);
        const hMat: [2][2]f32 = .{
            .{ 1.0, 0.0 },
            .{ 0.0, 1.0 },
        };

        const sMat: [2][2]f32 = mat.addWithCoefficients(2, 2, 1, 1, mat.multiply(2, 2, 2, hMat, mat.multiply(2, 2, 2, pMatPrediction, mat.transpose2D(hMat))), self.rMat);
        const kMat = mat.multiply(2, 2, 2, mat.multiply(2, 2, 2, pMatPrediction, mat.transpose2D(hMat)), mat.inverse2D(sMat));

        const predictedMeasurements: [2]f32 = xVecPred;

        // TODO: make this configurable
        //const deadzone = 0;
        //const deadzone = 30;
        //const measuredAngularRateWithDeadzone = if (@abs(self.simulation.measuredAngularRate) < deadzone) 0 else @abs(self.simulation.measuredAngularRate) - deadzone;
        //const trustInAngularRateCorrection = 1 - std.math.exp(-measuredAngularRateWithDeadzone / 20);

        //const yVec: [2]f32 = [2]f32{ trustInAngularRateCorrection * (self.simulation.measuredAngularRate - predictedMeasurements[0]), self.simulation.measuredVelocity - predictedMeasurements[1] };
        
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
    }
};
