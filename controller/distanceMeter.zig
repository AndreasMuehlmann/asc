const utilsZig = @import("utils.zig");
const pcnt = @cImport(@cInclude("pcnt.h"));
const Config = @import("config.zig").Config;

pub const DistanceMeter = struct {
    const Self = @This();

    pulsesPerRotation: *f32,
    tireCircumferenceMm: *f32,
    measurementTime: i64,
    degreesPerSecond: f32,
    distance: f32,

    pub fn init(config: *Config) Self {
        return .{
            .pulsesPerRotation = &config.pulsesPerRotation,
            .tireCircumferenceMm = &config.tireCircumferenceMm,
            .measurementTime = utilsZig.timestampMicros(),
            .degreesPerSecond = 0.0,
            .distance = 0.0,
        };
    }

    pub fn update(self: *Self) !void {
        const pulseCount: f32 = @floatFromInt(pcnt.pcntGetCount());
        pcnt.pcntReset();
        pcnt.pcntStart();

        const timeDiffMicros: f32 = @floatFromInt(utilsZig.timestampMicros() - self.measurementTime);
        self.degreesPerSecond = pulseCount / self.pulsesPerRotation.* * 360.0;
        self.distance += self.degreesPerSecond * timeDiffMicros / 1_000_000 / 360.0 * self.tireCircumferenceMm.* / 1_000;
    }

    pub fn reset(self: *Self) void {
        self.distance = 0.0;
    }
};
