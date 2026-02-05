const utilsZig = @import("utils.zig");
const Config = @import("config").Config;

pub const Tacho = struct {
    const Self = @This();

    initTime: i64,
    velocity: f32,
    distance: f32,

    pub fn init(config: *Config) Self {
        return .{
            .initTime = utilsZig.timestampMicros(),
            .velocity = &config.configAssumedVelocityMPerS,
            .distance = 0.0,
        };
    }

    pub fn update(self: *Self) !void {
        const timeDiffMicros: f32 = @floatFromInt(utilsZig.timestampMicros() - self.initTime);
        self.distance = self.velocity.* * timeDiffMicros / 1_000_000;
    }

    pub fn reset(self: *Self) void {
        self.distance = 0;
    }
};
