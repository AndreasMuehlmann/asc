const Controller = @import("controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const pwm = @cImport(@cInclude("pwm.h"));

// TODO: remove
const utilsZig = @import("utils.zig");
const clientContract = @import("clientContract");

const cc = @cImport({
    @cInclude("stdio.h");
});

const maxPwm: f32 = 1000.0;
const gyroBrakeMultiplier: f32 = 1.0;
const accelBrakeMultiplier: f32 = 0.0;
const iirFilterRiseCoefficient: f32 = 0.8;
const iirFilterFallCoefficient: f32 = 0.8;

pub const SelfDrive = struct {
    const Self = @This();

    controllerState: ControllerState,
    prevBrake: f32,

    pub fn init() Self {
        return .{
            .controllerState = .{ .stepFn = step, .handleCommandFn = handleCommand },
            .prevBrake = 1.0,
        };
    }

    pub fn step(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        _ = controller.config;
        const self: *SelfDrive = @fieldParentPtr("controllerState", controllerState);

        const brake = @abs(controller.bmi.prevGyro.y) * gyroBrakeMultiplier + @abs(controller.bmi.prevAccel.y) * accelBrakeMultiplier;

        const iirFilterCoefficient = if (brake > self.prevBrake) iirFilterRiseCoefficient else iirFilterFallCoefficient;
        const filteredBrake = (1 - iirFilterCoefficient) * self.prevBrake + iirFilterCoefficient * brake;
        const factor = if (filteredBrake > 100.0) 0.0 else 1 - (filteredBrake / 100.0);

        self.prevBrake = filteredBrake;

        
        pwm.setDuty(@intFromFloat(maxPwm * factor));

        _ = cc.printf("iirFilterCoefficient: %f\n", iirFilterCoefficient);
        _ = cc.printf("factor: %f\n", factor);
        _ = cc.printf("product: %f\n", maxPwm * factor);

        // TODO: remove
        controller.bmi.update() catch unreachable;
        const time: f32 = @floatFromInt(@divTrunc(utilsZig.timestampMicros(), 1000) - controller.initTime);
        const measurement: clientContract.Measurement = .{
            .time = time / 1_000.0,
            .heading = controller.bmi.heading,
            .accelerationX = factor,
            .accelerationY = 0,
            .accelerationZ = 0,
        };
        controller.netServer.send(clientContract.Measurement, measurement) catch unreachable;
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) ControllerStateError!void {}
};
