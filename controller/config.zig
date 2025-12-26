pub const Config = struct {
    const Self = @This();

    maxPwm: f32,
    gyroBrakeMultiplier: f32,
    accelBrakeMultiplier: f32,
    iirFilterRiseCoefficient: f32,
    iirFilterFallCoefficient: f32,
    configAssumedVelocityMPerS: f32,
    pulsesPerRotation: f32,
    tireCircumferenceMm: f32,

    pub fn init() Self {
        return .{
            .maxPwm = 1000.0,
            .gyroBrakeMultiplier = 1.5,
            .accelBrakeMultiplier = 0.01,
            .iirFilterRiseCoefficient = 0.5,
            .iirFilterFallCoefficient = 0.01,
            .configAssumedVelocityMPerS = 1.0,
            .pulsesPerRotation = 5.0,
            .tireCircumferenceMm = 74.01,
        };
    }
};
