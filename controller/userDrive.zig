const Controller = @import("controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const pwm = @cImport(@cInclude("pwm.h"));

pub const UserDrive = struct {
    const Self = @This();

    controllerState: ControllerState,
    speed: f32,

    pub fn init() Self {
        return .{
            .controllerState = .{ .stepFn = step, .handleCommandFn = handleCommand },
            .speed = 0.0,
        };
    }

    pub fn step(controllerState: *ControllerState, _: *Controller) ControllerStateError!void {
        const self: *UserDrive = @fieldParentPtr("controllerState", controllerState);
        pwm.setDuty(@intFromFloat(self.speed));
    }

    pub fn handleCommand(controllerState: *ControllerState, _: *Controller, command: serverContract.command) ControllerStateError!void {
        const self: *UserDrive = @fieldParentPtr("controllerState", controllerState);
        switch (command) {
            .setSpeed => |s| {
                self.speed = s.speed;
            },
            else => {},
        }
    }
};
