const Controller = @import("../controller.zig").Controller;
const c = @import("controllerState.zig");
const ControllerState = c.ControllerState;
const ControllerStateError = c.ControllerStateError;
const serverContract = @import("serverContract");
const clientContract = @import("clientContract");
const pwm = @cImport(@cInclude("pwm.h"));
const KalmanFilter = @import("../kalmanFilter.zig").KalmanFilter;
const trackMod = @import("track");
const Track = trackMod.Track(true);
const TrackPoint = trackMod.TrackPoint;


pub const OptimalSelfDrive = struct {
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

    pub fn step(_: *ControllerState, controller: *Controller) ControllerStateError!void {
        if (controller.kalmanFilter == null or controller.track == null) {
            try controller.changeState(&controller.stop.controllerState);
            controller.netServer.send(clientContract.Log, clientContract.Log{.level = clientContract.LogLevel.warning, .message = "There is no track mapping, changing state to stop."}) catch return ControllerStateError.SendFailed;
            return;
        }
        pwm.setDuty(controller.config.dutyMapTrack);
        const kalmanFilter: *KalmanFilter = &controller.kalmanFilter.?;
        const track: *Track = &controller.track.?;
        const heading = track.distanceToHeading(kalmanFilter.distance);
        controller.netServer.send(clientContract.CarTrackPoint, clientContract.CarTrackPoint{.distance = kalmanFilter.distance, .heading = heading}) catch return ControllerStateError.SendFailed;
    }

    pub fn reset(controllerState: *ControllerState, _: *Controller) ControllerStateError!void {
        _ = controllerState;
    }

    pub fn handleCommand(_: *ControllerState, _: *Controller, _: serverContract.command) ControllerStateError!void {}
};
