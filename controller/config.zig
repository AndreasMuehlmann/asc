pub const Config = struct {
    const Self = @This();

    maxPwm: f32,
    gyroBrakeMultiplier: f32,
    accelBrakeMultiplier: f32,
    iirFilterRiseCoefficient: f32,
    iirFilterFallCoefficient: f32,

    pub fn init() Self {
        return .{
            .maxPwm = 1000.0,
            .gyroBrakeMultiplier = 1.0,
            .accelBrakeMultiplier = 0.0,
            .iirFilterRiseCoefficient = 0.9,
            .iirFilterFallCoefficient = 0.5,
        };
    }
};
