const utilsZig = @import("utils.zig");
const pt = @cImport(@cInclude("pt.h"));
const Config = @import("config.zig").Config;
const c = @cImport({
    @cInclude("stdio.h");
});

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
        if (!pt.ptUpdatedPeriod()) {
            return;
        }

        const timeDiffMicros: f32 = @floatFromInt(utilsZig.timestampMicros() - self.measurementTime);
        self.measurementTime = utilsZig.timestampMicros();
        const period: f32 = pt.ptGetPeriod();
        pt.ptResetPeriod();
        if (period == 0.0) {
            return;
        }
        self.degreesPerSecond = (360 / self.pulsesPerRotation.*) / period;
        self.distance += self.degreesPerSecond * timeDiffMicros / 1_000_000 / 360.0 * self.tireCircumferenceMm.* / 1_000;
    }

    pub fn reset(self: *Self) void {
        self.distance = 0.0;
    }
};
