const std = @import("std");

const Controller = @import("../controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const clientContract = @import("clientContract");
const trackMod = @import("track");
const Track = trackMod.Track(true);
const TrackPoint = trackMod.TrackPoint;

pub const MapTrack = struct {
    const Self = @This();

    controllerState: ControllerState,
    trackPoints: std.ArrayList(TrackPoint),
    initialTrackPoint: ?TrackPoint,

    pub fn init() Self {
        return .{
            .controllerState = .{ .startFn = start, .stepFn = step, .handleCommandFn = handleCommand, .resetFn = reset },
            .trackPoints = undefined,
            .initialTrackPoint = null
        };
    }

    pub fn start(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        if (controller.track) |*track| {
            track.deinit();
        }
        self.trackPoints = std.ArrayList(TrackPoint).initCapacity(controller.allocator, 100) catch return ControllerStateError.OutOfMemory;
        controller.netServer.send(clientContract.command, clientContract.command{.resetMapping = clientContract.resetMapping{}}) catch return ControllerStateError.SendFailed;
        self.initialTrackPoint = null;
    }

    pub fn step(controllerState: *ControllerState, controller: *Controller) ControllerStateError!void {
        const self: *MapTrack = @fieldParentPtr("controllerState", controllerState);
        var trackPoint: TrackPoint = undefined;

        if (self.initialTrackPoint) |initialTrackPoint| {
            if (controller.tacho.distance - initialTrackPoint.distance < controller.config.minTrackPointDistanceMm / 1_000_000 + self.trackPoints.items[self.trackPoints.items.len - 1].distance) {
                return;
            }

            trackPoint = TrackPoint{
                .distance = controller.tacho.distance - initialTrackPoint.distance,
                .heading = @mod(controller.bmi.heading - initialTrackPoint.heading, 360),
            };
        } else {
            self.initialTrackPoint = TrackPoint{
                .distance = controller.tacho.distance,
                .heading = controller.bmi.heading,
            };
            trackPoint = .{.distance = 0.0, .heading = 0.0};
        }
        
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
                if (self.trackPoints.items.len <= 3) {
                    controller.netServer.send(clientContract.Log, clientContract.Log{.level = clientContract.LogLevel.warning, .message = "There must be at least three trackPoints to create a track. The track mapping will be reset and the mode is set to stop."}) catch return ControllerStateError.SendFailed;
                    controller.netServer.send(clientContract.command, clientContract.command{.resetMapping = clientContract.resetMapping{}}) catch return ControllerStateError.SendFailed;
                    self.trackPoints.deinit(controller.allocator);
                } else {
                    controller.track = Track.init(controller.allocator, self.trackPoints.toOwnedSlice(controller.allocator) catch return ControllerStateError.OutOfMemory) catch return ControllerStateError.TrackCreationFailed;
                    controller.netServer.send(clientContract.command, clientContract.command{.endMapping = clientContract.endMapping{}}) catch return ControllerStateError.SendFailed;
                }
                try controller.changeState(&controller.stop.controllerState);
            },
            else => {},
        }
    }

    pub fn reset(_: *ControllerState, _: *Controller) ControllerStateError!void {}
};
