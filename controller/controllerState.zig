const Controller = @import("controller.zig").Controller;
const serverContract = @import("serverContract");

pub const ControllerState = struct {
    stepFn: *const fn (self: *ControllerState, controller: *Controller) void,
    handleCommandFn: *const fn (self: *ControllerState, controller: *Controller, command: serverContract.command) void,

    pub fn step(self: *ControllerState, controller: *Controller) void {
        self.stepFn(self, controller);
    }

    pub fn handleCommand(self: *ControllerState, controller: *Controller, command: serverContract.command) void {
        self.handleCommandFn(self, controller, command);
    }
};
