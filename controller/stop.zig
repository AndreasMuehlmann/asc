const Controller = @import("controller.zig").Controller;
const ControllerState = @import("controllerState.zig").ControllerState;
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

    pub fn step(_: *ControllerState, _: *Controller) void {
        pwm.setDuty(0);
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) void {}
};
