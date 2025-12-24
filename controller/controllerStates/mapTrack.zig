const Controller = @import("../controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");


pub const MapTrack = struct {
    const Self = @This();

    controllerState: ControllerState,


    pub fn init() Self {
        return .{ 
            .controllerState = .{ .startFn = start, .stepFn = step, .handleCommandFn = handleCommand, .resetFn = reset },
        };
    }

    pub fn start(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        _ = controllerState;
        _ = controller;
    }


    pub fn step(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        _ = self;
        _ = controller;
    }

    pub fn handleCommand(controllerState: *ControllerState, controller: *Controller, command: serverContract.command) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        _ = self;
        _ = controller;
        _ = command;

    }

    pub fn reset(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        _ = controllerState;
        _ = controller;
    }
};
