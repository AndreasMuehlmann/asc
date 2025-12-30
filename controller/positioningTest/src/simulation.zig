const std = @import("std");
const t = @import("track.zig");
const Track = t.Track;
const TrackPoint = t.TrackPoint;

pub const Simulation = struct {
    const Self = @This();

    track: *Track,
    distance: f32,
    velocity: f32,
    measuredVelocity: f32,
    velocityNoise: f32,
    velocityBias: f32,
    heading: f32,
    angularRate: f32,
    measuredAngularRate: f32,
    angularRateNoise: f32,
    angularRateBias: f32,
    deltaTime: f32,
    time: f32,
    rng: *std.Random,

    pub fn init(track: *Track, initialDistance: f32, velocity: f32, deltaTime: f32, angularRateNoise: f32, angularRateBias: f32, velocityNoise: f32, velocityBias: f32, rng: *std.Random) Self {
        return .{
            .track = track,
            .distance = initialDistance,
            .velocity = velocity,
            .measuredVelocity = velocity,
            .velocityNoise = velocityNoise,
            .velocityBias = velocityBias,
            .deltaTime = deltaTime,
            .time = 0.0,
            .heading = track.distanceToHeading(initialDistance),
            .angularRate = 0.0,
            .measuredAngularRate = 0.0,
            .angularRateNoise = angularRateNoise,
            .angularRateBias = angularRateBias,
            .rng = rng,
        };
    }

    pub fn update(self: *Self) void {
        self.time += self.deltaTime;
        self.distance = @mod(self.distance + self.velocity * self.deltaTime, self.track.getTrackLength());
        const newHeading = self.track.distanceToHeading(self.distance);
        self.angularRate = Track.angularDelta(newHeading, self.heading) / self.deltaTime;
        self.heading = newHeading;
        self.measuredAngularRate = self.addNoise(self.angularRate, self.angularRateBias, self.angularRateNoise);
        self.measuredVelocity = self.addNoise(self.velocity, self.velocityBias, self.velocityNoise);
    }

    fn sampleNormal(self: Self, mean: f32, stddev: f32) f32 {
        const uniform1 = self.rng.float(f32);
        const uniform2 = self.rng.float(f32);

        const r = @sqrt(-2.0 * @log(uniform1));
        const theta = 2.0 * std.math.pi * uniform2;

        const z0 = r * @cos(theta);

        return mean + z0 * stddev;
    }

    fn addNoise(self: Self, value: f32, bias: f32, noiseStandardDeviation: f32) f32 {
        if (noiseStandardDeviation == 0.0) {
            return value + bias;
        }

        return value + bias + self.sampleNormal(0.0, noiseStandardDeviation);
    }
};
