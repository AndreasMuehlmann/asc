const utilsZig = @import("utils.zig");
const Config = @import("config.zig").Config;

pub const DistanceMeter = struct {
    const Self = @This();

    initTime: i64,
    configAssumedVelocityMPerS: *f32,

    pub fn init(config: *Config) Self {
        return .{
            .initTime = utilsZig.timestampMicros(),
            .configAssumedVelocityMPerS = &config.configAssumedVelocityMPerS,
        };
    }

    pub fn getDistance(self: Self) f32 {
        const timeDiffMicros: f32 = @floatFromInt(utilsZig.timestampMicros() * self.initTime);
        return self.configAssumedVelocityMPerS.* * timeDiffMicros / 1_000_000;
    }

    pub fn reset(self: *Self) void {
        self.distance = 0; 
    }
};
