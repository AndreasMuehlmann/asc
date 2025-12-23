const Controller = @import("controller.zig").Controller;
const ControllerState = @import("controllerState.zig").ControllerState;
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

    pub fn step(controllerState: *ControllerState, _: *Controller) void {
        const self: *UserDrive = @fieldParentPtr("controllerState", controllerState);
        pwm.setDuty(@intFromFloat(self.speed));
    }

    pub fn handleCommand(controllerState: *ControllerState, _: *Controller, command: serverContract.command) void {
        const self: *UserDrive = @fieldParentPtr("controllerState", controllerState);
        switch (command) {
            .setSpeed => |s| {
                self.speed = s.speed;
            },
            else => {},
        }
    }
};
