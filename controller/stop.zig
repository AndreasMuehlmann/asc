const Controller = @import("controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const pwm = @cImport(@cInclude("pwm.h"));

pub const Stop = struct {
    const Self = @This();

    controllerState: ControllerState,

    pub fn init() Self {
        return .{
            .controllerState = .{ .stepFn = step, .handleCommandFn = handleCommand },
        };
    }

    pub fn step(_: *ControllerState, _: *Controller) ControllerStateError!void {
        pwm.setDuty(0);
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) ControllerStateError!void {}
};
