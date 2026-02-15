const std = @import("std");
const trackMod = @import("track");
const Track = trackMod.Track(true);
const TrackPoint = trackMod.TrackPoint;
const Controller = @import("controller.zig").Controller;
const mat = @import("matrixUtils.zig");


pub const KalmanFilter = struct {
    const Self = @This();

    controller: *Controller,
    track: *Track,
    distance: f32,
    velocity: f32,
    heading: f32,
    pMat: [2][2]f32,
    fMat: [2][2]f32,
    qMat: [2][2]f32,
    rMat: [2][2]f32,

    pub fn init(controller: *Controller, track: *Track) Self {
        const dtMs: f32 = @floatFromInt(controller.config.deltaTimeMs);
        return .{
            .controller = controller,
            .track = track,
            .distance = 0.0,
            .velocity = 0.0,
            .heading = 0.0,
            .pMat = [_][2]f32{
                .{ 0.0001, 0.0 },
                .{ 0.0, 0.0001 },
            },
            // with acceleration F = [1, dt, 1/2 dt*dt; 0, 1, dt]
            .fMat = [_][2]f32{
                .{ 1.0, dtMs / 1000 }, 
                .{ 0.0, 1.0 },
            },
            // TODO: tune
            .qMat = [_][2]f32{
                .{ 0.01, 0.0 },
                .{ 0.0, 0.01 },
            },
            .rMat = [_][2]f32{
                .{ 0.0001, 0.0 }, 
                .{ 0.0, 0.01 },
            },
        };
    }

    fn distanceMeasurementThroughHeading(self: *Self, xVecPred: [2]f32) f32 {
        const dtMs: f32 = @floatFromInt(self.controller.config.deltaTimeMs);
        const measuredHeading = @mod(self.heading + self.controller.bmi.prevGyro.z * dtMs / 1000 , 360);
        const trackPoint: TrackPoint = .{.distance = xVecPred[0], .heading = measuredHeading};
        const closest: TrackPoint = self.track.getClosestPoint(trackPoint);

        const direction: f32 = if (closest.distance >= xVecPred[0]) 1.0 else -1.0;
        return xVecPred[0] + direction * self.track.signedDifferenceDistance(self.distance, xVecPred[0]) * 0.5;
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

        const yVec: [2]f32 = [2]f32{ self.distanceMeasurementThroughHeading(xVecPred) - predictedMeasurements[0], self.controller.tacho.velocity - predictedMeasurements[1] };
        const adjustedYVec = mat.vectorMultiply(2, 2, kMat, yVec);
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
