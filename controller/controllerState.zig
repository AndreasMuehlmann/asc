const Controller = @import("controller.zig").Controller;
const serverContract = @import("serverContract");


pub const ControllerStateError = error{};


pub const ControllerState = struct {
    stepFn: *const fn (self: *ControllerState, controller: *Controller) ControllerStateError!void,
    handleCommandFn: *const fn (self: *ControllerState, controller: *Controller, command: serverContract.command) ControllerStateError!void,

    pub fn step(self: *ControllerState, controller: *Controller) !void {
        try self.stepFn(self, controller);
    }

    pub fn handleCommand(self: *ControllerState, controller: *Controller, command: serverContract.command) !void {
        try self.handleCommandFn(self, controller, command);
    }
};
