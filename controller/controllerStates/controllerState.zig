const Controller = @import("../controller.zig").Controller;
const serverContract = @import("serverContract");


pub const ControllerStateError = error{};


pub const ControllerState = struct {
    startFn: *const fn (self: *ControllerState, controller: *Controller) ControllerStateError!void,
    stepFn: *const fn (self: *ControllerState, controller: *Controller) ControllerStateError!void,
    handleCommandFn: *const fn (self: *ControllerState, controller: *Controller, command: serverContract.command) ControllerStateError!void,
    resetFn: *const fn (self: *ControllerState, controller: *Controller) ControllerStateError!void,

    pub fn start(self: *ControllerState, controller: *Controller) !void {
        try self.startFn(self, controller);
    }

    pub fn step(self: *ControllerState, controller: *Controller) !void {
        try self.stepFn(self, controller);
    }

    pub fn handleCommand(self: *ControllerState, controller: *Controller, command: serverContract.command) !void {
        try self.handleCommandFn(self, controller, command);
    }

    pub fn reset(self: *ControllerState, controller: *Controller) !void {
        try self.resetFn(self, controller);
    }
};
