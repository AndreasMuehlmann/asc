const std = @import("std");

const clientContract = @import("clientContract");
const serverContract = @import("serverContract");
const encode = @import("encode");
const NetServer = @import("netServer.zig").NetServer;

const pwm = @cImport(@cInclude("pwm.h"));
const rtos = @cImport(@cInclude("rtos.h"));
const utils = @cImport(@cInclude("utils.h"));
const utilsZig = @import("utils.zig");
const i2c = @cImport(@cInclude("i2c.h"));

const Bmi = @import("bmi.zig").Bmi;
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


const ControllerState = @import("controllerStates/controllerState.zig").ControllerState;
const MapTrack = @import("controllerStates/mapTrack.zig").MapTrack;
const SelfDrive = @import("controllerStates/selfDrive.zig").SelfDrive;
const UserDrive = @import("controllerStates/userDrive.zig").UserDrive;
const Stop = @import("controllerStates/stop.zig").Stop;


const tag = "controller";

pub const Controller = struct {
    const Self = @This();
    const NetServerT = NetServer(serverContract.ServerContractEnum, serverContract.ServerContract, Controller, clientContract.ClientContract);

    var selfDrive = SelfDrive.init();
    var userDrive = UserDrive.init();
    var mapTrack = MapTrack.init();
    var stop = Stop.init();

    allocator: std.mem.Allocator,
    netServer: NetServerT,
    initTime: i64,
    i2cBusHandle: esp.i2c_master_bus_handle_t,
    bmi: Bmi,
    state: *ControllerState,
    config: Config,

    pub fn init(allocator: std.mem.Allocator, netServer: NetServerT) !Self {
        var i2cBusHandle: esp.i2c_master_bus_handle_t = null;
        i2c.i2c_bus_init(&i2cBusHandle);
        const bmi = try Bmi.init(&i2cBusHandle);

        return .{ 
            .allocator = allocator,
            .netServer = netServer,
            .initTime = @divTrunc(utilsZig.timestampMicros(), 1000),
            .i2cBusHandle = i2cBusHandle,
            .bmi = bmi,
            .state = &stop.controllerState,
            .config = Config.init(),
        };
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
        const time: f32 = @floatFromInt(@divTrunc(utilsZig.timestampMicros(), 1000) - self.initTime);
        const measurement: clientContract.Measurement = .{
            .time = time / 1_000.0,
            .heading = self.bmi.heading,
            .accelerationX = self.bmi.prevAccel.x,
            .accelerationY = self.bmi.prevAccel.y,
            .accelerationZ = self.bmi.prevAccel.z,
        };
        try self.netServer.send(clientContract.Measurement, measurement);

        try self.state.step(self);

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
                    try self.changeState(&stop.controllerState);
                    _ = c.printf("Setting mode to \"stop\"\n");
                } else if (std.mem.eql(u8, s.mode, "selfdrive")) {
                    try self.changeState(&selfDrive.controllerState);
                    _ = c.printf("Setting mode to \"selfdrive\"\n");
                } else if (std.mem.eql(u8, s.mode, "userdrive")) {
                    try self.changeState(&userDrive.controllerState);
                    _ = c.printf("Setting mode to \"userdrive\"\n");
                } else if (std.mem.eql(u8, s.mode, "maptrack")) {
                    try self.changeState(&mapTrack.controllerState);
                    _ = c.printf("Setting mode to \"maptrack\"\n");
                } else {
                    const buffer = std.fmt.bufPrintZ(&array, "{s}", .{s.mode}) catch unreachable;
                    utils.espLog(esp.ESP_LOG_WARN, tag, "Mode \"%s\"doesn't exist", buffer.ptr);
                }
            },
            .restart => |_| {
                _ = c.printf("restart\n");
            },
            else => {},
        }

        try self.state.handleCommand(self, command);
    }

    pub fn changeState(self: *Self, newState: *ControllerState) !void {
        try self.state.reset(self);
        self.state = newState;
        try self.state.start(self);
    }

    pub fn deinit(_: Self) void {}
};
