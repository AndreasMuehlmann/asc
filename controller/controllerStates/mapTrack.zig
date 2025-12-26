const std = @import("std");

const Controller = @import("../controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const TrackPoint = @import("clientContract").TrackPoint;

pub const MapTrack = struct {
    const Self = @This();

    controllerState: ControllerState,
    trackPoints: std.ArrayList(TrackPoint),

    pub fn init() Self {
        return .{
            .controllerState = .{ .startFn = start, .stepFn = step, .handleCommandFn = handleCommand, .resetFn = reset },
            .trackPoints = undefined,
        };
    }

    pub fn start(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        if (controller.trackPoints) |*controllerTrackPoints| {
            controllerTrackPoints.deinit(controller.allocator);
        }
        self.trackPoints = std.ArrayList(TrackPoint).initCapacity(controller.allocator, 100) catch return ControllerStateError.OutOfMemory;
    }

    pub fn step(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        const trackPoint = TrackPoint{
            .distance = controller.distanceMeter.distance,
            .heading = controller.bmi.heading,
        };
        self.trackPoints.append(
            controller.allocator,
            trackPoint,
        ) catch return ControllerStateError.OutOfMemory;
        controller.netServer.send(TrackPoint, trackPoint) catch return ControllerStateError.SendFailed;
    }

    pub fn handleCommand(controllerState: *ControllerState, controller: *Controller, command: serverContract.command) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        switch (command) {
            .endMapping => {
                controller.trackPoints = self.trackPoints;
                try controller.changeState(&controller.stop.controllerState);
            },
            else => {},
        }
    }

    pub fn reset(_: *ControllerState, _: *Controller) ControllerStateError!void {}
};
