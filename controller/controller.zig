const std = @import("std");

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const encode = @import("encode");
const NetServer = @import("netServer.zig").NetServer;

const pwm = @cImport(@cInclude("pwm.h"));
const rtos = @cImport(@cInclude("rtos.h"));
const utils = @cImport(@cInclude("utils.h"));
const utilsZig = @import("utils.zig");

const Bmi = @import("bmi.zig").Bmi;
const DistanceMeter = @import("distanceMeter.zig").DistanceMeter;
const Config = @import("config.zig").Config;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
    @cInclude("unistd.h");
});

const esp = @cImport({
    @cInclude("server.h");
    @cInclude("esp_system.h");
    @cInclude("esp_log.h");
    @cInclude("driver/i2c_master.h");
    @cInclude("driver/ledc.h");
});

const cont = @import("controllerStates/controllerState.zig");
const ControllerStateError = cont.ControllerStateError;
const ControllerState = cont.ControllerState;
const MapTrack = @import("controllerStates/mapTrack.zig").MapTrack;
const SelfDrive = @import("controllerStates/selfDrive.zig").SelfDrive;
const UserDrive = @import("controllerStates/userDrive.zig").UserDrive;
const Stop = @import("controllerStates/stop.zig").Stop;

const tag = "controller";

pub const Controller = struct {
    const Self = @This();
    const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    allocator: std.mem.Allocator,

    config: *Config,
    bmi: Bmi,
    distanceMeter: DistanceMeter,
    netServer: NetServerT,

    state: *ControllerState,

    selfDrive: SelfDrive,
    userDrive: UserDrive,
    mapTrack: MapTrack,
    stop: Stop,

    initTime: i64,
    trackPoints: ?std.ArrayList(clientContract.TrackPoint),

    pub fn init(allocator: std.mem.Allocator, config: *Config, bmi: Bmi, distanceMeter: DistanceMeter, netServer: NetServerT) !Self {
        return .{
            .allocator = allocator,

            .config = config,
            .bmi = bmi,
            .distanceMeter = distanceMeter,
            .netServer = netServer,

            .state = undefined,

            .selfDrive = SelfDrive.init(),
            .userDrive = UserDrive.init(),
            .mapTrack = MapTrack.init(),
            .stop = Stop.init(),

            .initTime = @divTrunc(utilsZig.timestampMicros(), 1000),
            .trackPoints = null,
        };
    }

    pub fn afterInit(self: *Self) void {
        self.state = &self.stop.controllerState;
    }

    pub fn run(self: *Self) !void {
        var lastWake = rtos.rtosXTaskGetTickCount();
        while (true) {
            self.netServer.recv() catch |err| switch (err) {
                error.ConnectionClosed => return,
                else => return err,
            };

            try self.step();

            rtos.rtosVTaskDelayUntil(&lastWake, rtos.rtosMillisToTicks(10));
        }
    }

    fn step(self: *Self) !void {
        try self.bmi.update();
        try self.distanceMeter.update();
        try self.state.step(self);

        const time: f32 = @floatFromInt(@divTrunc(utilsZig.timestampMicros(), 1000) - self.initTime);
        const measurement: clientContract.Measurement = .{
            .time = time / 1_000.0,
            .heading = self.bmi.heading,
            .accelerationX = self.distanceMeter.distance,
            .accelerationY = 0.0,
            .accelerationZ = 0.0,
        };
        try self.netServer.send(clientContract.Measurement, measurement);
    }

    pub fn handleCommand(self: *Self, command: serverContract.command) !void {
        var array: [250]u8 = undefined;

        switch (command) {
            .setWifi => |s| {
                const buffer = std.fmt.bufPrintZ(&array, "{s}", .{s.ssid}) catch unreachable;
                _ = c.printf("ssid: %s\n", buffer.ptr);
                self.allocator.free(s.ssid);
                self.allocator.free(s.password);
            },
            .setMode => |s| {
                if (std.mem.eql(u8, s.mode, "stop")) {
                    try self.changeState(&self.stop.controllerState);
                    _ = c.printf("Setting mode to \"stop\"\n");
                } else if (std.mem.eql(u8, s.mode, "selfdrive")) {
                    try self.changeState(&self.selfDrive.controllerState);
                    _ = c.printf("Setting mode to \"selfdrive\"\n");
                } else if (std.mem.eql(u8, s.mode, "userdrive")) {
                    try self.changeState(&self.userDrive.controllerState);
                    _ = c.printf("Setting mode to \"userdrive\"\n");
                } else if (std.mem.eql(u8, s.mode, "maptrack")) {
                    try self.changeState(&self.mapTrack.controllerState);
                    _ = c.printf("Setting mode to \"maptrack\"\n");
                } else {
                    const buffer = std.fmt.bufPrintZ(&array, "{s}", .{s.mode}) catch unreachable;
                    utils.espLog(esp.ESP_LOG_WARN, tag, "Mode \"%s\"doesn't exist", buffer.ptr);
                }
                self.allocator.free(s.mode);
            },
            .restart => |_| {
                _ = c.printf("restart\n");
            },
            else => {},
        }

        try self.state.handleCommand(self, command);
    }

    pub fn changeState(self: *Self, newState: *ControllerState) ControllerStateError!void {
        try self.state.reset(self);
        self.state = newState;
        try self.state.start(self);
    }

    pub fn deinit(_: Self) void {}
};
