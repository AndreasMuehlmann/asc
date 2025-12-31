const std = @import("std");
const Simulation = @import("simulation.zig").Simulation;
const Track = @import("track.zig").Track;

fn matVecMul(
    comptime R: usize,
    comptime C: usize,
    a: [R][C]f32,
    x: [C]f32,
) [R]f32 {
    var y: [R]f32 = undefined;

    for (0..R) |i| {
        var sum: f32 = 0.0;
        for (0..C) |j| {
            sum += a[i][j] * x[j];
        }
        y[i] = sum;
    }
    return y;
}

fn matMul(
    comptime R: usize,
    comptime M: usize,
    comptime C: usize,
    a: [R][M]f32,
    b: [M][C]f32,
) [R][C]f32 {
    var result: [R][C]f32 = undefined;

    for (0..R) |i| {
        for (0..C) |j| {
            var sum: f32 = 0.0;
            for (0..M) |k| {
                sum += a[i][k] * b[k][j];
            }
            result[i][j] = sum;
        }
    }
    return result;
}

fn matAddWithCoefficients(
    comptime R: usize,
    comptime C: usize,
    aCoefficient: f32,
    bCoefficient: f32,
    a: [R][C]f32,
    b: [R][C]f32,
) [R][C]f32 {
    var result: [R][C]f32 = undefined;

    for (0..R) |i| {
        for (0..C) |j| {
            result[i][j] = aCoefficient * a[i][j] + bCoefficient * b[i][j];
        }
    }

    return result;
}

fn mat2Transpose(a: [2][2]f32) [2][2]f32 {
    return .{
        .{ a[0][0], a[1][0] },
        .{ a[0][1], a[1][1] },
    };
}

fn mat2Inv(a: [2][2]f32) [2][2]f32 {
    const det = a[0][0]*a[1][1] - a[0][1]*a[1][0];
    return .{
        .{  a[1][1]/det, -a[0][1]/det },
        .{ -a[1][0]/det,  a[0][0]/det },
    };
}

pub const Controller = struct {
    const Self = @This();

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
                .{ 0.000001, 0.0 },
                .{ 0.0, 0.000001 },
            },
            // with acceleration F = [1, dt, 1/2 dt*dt; 0, 1, dt]
            .fMat = [_][2]f32{
                .{ 1.0, simulation.deltaTime },
                .{ 0.0, 1.0 },
            },
            .qMat = [_][2]f32{
                .{ 0.000005, 0.0 },
                .{ 0.0, 0.00001 },
            },
            .rMat = [_][2]f32{
                .{ simulation.angularRateNoise * simulation.angularRateNoise, 0.0 },
                .{ 0.0, simulation.velocityNoise * simulation.velocityNoise},
            },
        };
    }

    pub fn stateVectorToMeasurements(self: *Self, xVecPred: [2]f32) [2]f32 {
        // measurement vector z = [angularRate, velocity]
        const heading = self.track.distanceToHeading(xVecPred[0]);
        std.debug.print("heading at prediction: {d}, estimated angularRate: {d}\n", .{heading, Track.angularDelta(self.heading, heading) / self.simulation.deltaTime});
        std.debug.print("angularDelta: {d}\n", .{Track.angularDelta(self.heading, heading)});
        return [2]f32{Track.angularDelta(self.heading, heading) / self.simulation.deltaTime, xVecPred[1]};
    }

    pub fn update(self: *Self) void {
        const prevXVec: [2]f32 = [2]f32{self.distance, self.velocity};
        var xVecPred: [2]f32 = matVecMul(2, 2, self.fMat, prevXVec);
        xVecPred[0] = @mod(xVecPred[0], self.track.getTrackLength());
        const pMatPrediction: [2][2]f32 = matAddWithCoefficients(2, 2, 1, 1, matMul(2, 2, 2, matMul(2, 2, 2, self.fMat, self.pMat), mat2Transpose(self.fMat)), self.qMat);

        std.debug.print("predicition: {d}, {d}\n", .{xVecPred[0], xVecPred[1]});

        const hMat: [2][2]f32 = .{
            .{self.track.distanceToHeadingDerivative(xVecPred[0]), 0},
            .{0, 1},
        };

        const sMat: [2][2]f32 = matAddWithCoefficients(2, 2, 1, 1, matMul(2, 2, 2, hMat, matMul(2, 2, 2, pMatPrediction, mat2Transpose(hMat))), self.rMat);
        const kMat = matMul(2, 2, 2, matMul(2, 2, 2, pMatPrediction, mat2Transpose(hMat)), mat2Inv(sMat));
        
        const predictedMeasurements: [2]f32 = self.stateVectorToMeasurements(xVecPred);
        const yVec: [2]f32 = [2]f32{self.simulation.measuredAngularRate - predictedMeasurements[0], self.simulation.measuredVelocity - predictedMeasurements[1]};

        const adjustedYVec = matVecMul(2, 2, kMat, yVec);
        std.debug.print("adjustedYVec: {d}, yVec: {d}\n", .{adjustedYVec[0], yVec[0]});
        self.distance = @mod(xVecPred[0] + adjustedYVec[0], self.track.getTrackLength());
        self.velocity = xVecPred[1] + adjustedYVec[1];

        const identity: [2][2]f32 = [2][2]f32{
            .{1.0, 0.0},
            .{0.0, 1.0},
        };
        self.pMat = matMul(2, 2, 2, matAddWithCoefficients(2, 2, 1, -1, identity, matMul(2, 2, 2, kMat, hMat)), pMatPrediction);
        self.heading = self.track.distanceToHeading(self.distance);
    }
};
