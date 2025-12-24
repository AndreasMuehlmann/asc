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
        const self: *SelfDrive = @fieldParentPtr("controllerState", controllerState);
        const conf = &controller.config;

        const brake = @abs(controller.bmi.prevGyro.y) * conf.gyroBrakeMultiplier + @abs(controller.bmi.prevAccel.y) * conf.accelBrakeMultiplier;
        const iirFilterCoefficient = if (brake > self.prevBrake) conf.iirFilterRiseCoefficient else conf.iirFilterFallCoefficient;
        const filteredBrakeUncapped = (1 - iirFilterCoefficient) * self.prevBrake + iirFilterCoefficient * brake;
        const filteredBrake = if (filteredBrakeUncapped > 100.0) 100.0 else filteredBrakeUncapped;
        const factor = 1 - (filteredBrake / 100.0);

        self.prevBrake = filteredBrake;

        pwm.setDuty(@intFromFloat(conf.maxPwm * factor));

        // TODO: remove
       //controller.bmi.update() catch unreachable;
       //const time: f32 = @floatFromInt(@divTrunc(utilsZig.timestampMicros(), 1000) - controller.initTime);
       //const measurement: clientContract.Measurement = .{
       //    .time = time / 1_000.0,
       //    .heading = conf.maxPwm * controller.bmi.heading,
       //    .accelerationX = factor,
       //    .accelerationY = 0,
       //    .accelerationZ = 0,
       //};
       //controller.netServer.send(clientContract.Measurement, measurement) catch unreachable;
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) ControllerStateError!void {}
};
