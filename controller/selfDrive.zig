const Controller = @import("controller.zig").Controller;
const ControllerState = @import("controllerState.zig").ControllerState;
const serverContract = @import("serverContract");
const pwm = @cImport(@cInclude("pwm.h"));

pub const SelfDrive = struct {
    const Self = @This();

    controllerState: ControllerState,
    prevBrake: f32,

    pub fn init() Self {
        return .{
            .controllerState = .{ .stepFn = step, .handleCommandFn = handleCommand },
            .prevBrake = 0.0,
        };
    }

    pub fn step(controllerState: *ControllerState, controller: *Controller) void {
        const conf = controller.config;
        const self: *SelfDrive = @fieldParentPtr("controllerState", controllerState);

        const brake = @abs(controller.bmi.prevGyro.y) * conf.gyroBrakeMultiplier + @abs(controller.bmi.prevGyro.y) * conf.accelBrakeMultiplier;

        const iirFilterCoefficient = if (brake > self.prevBrake) conf.iirFilterRiseCoefficient else conf.iirFilterFallCoefficient;
        const filteredBrake = (1 - iirFilterCoefficient) * self.prevBrake + iirFilterCoefficient * brake;

        self.prevBrake = brake;

        pwm.setDuty(@intFromFloat(conf.maxPwm * filteredBrake));
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) void {}
};
