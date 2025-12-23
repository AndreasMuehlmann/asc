const Controller = @import("controller.zig").Controller;
const ControllerState = @import("controllerState.zig").ControllerState;
const serverContract = @import("serverContract");


pub const MapTrack = struct {
    const Self = @This();

    controllerState: ControllerState,


    pub fn init() Self {
        return .{ 
            .controllerState = .{ .stepFn = step, .handleCommandFn = handleCommand },
        };
    }

    pub fn step(controllerState: *ControllerState, controller: *Controller) void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        _ = self;
        _ = controller;
    }

    pub fn handleCommand(controllerState: *ControllerState, controller: *Controller, command: serverContract.command) void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        _ = self;
        _ = controller;
        _ = command;

    }
};
