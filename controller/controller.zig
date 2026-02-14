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
const Tacho = @import("tacho.zig").Tacho;
const configMod = @import("config");
const Config = configMod.Config;
const trackMod = @import("track");
const Track = trackMod.Track(true);
const TrackPoint = trackMod.TrackPoint;

const c = @cImport({
    @cInclude("stdio.h");
    @cInclude("sys/time.h");
    @cInclude("unistd.h");
});

const esp = @cImport({
    @cInclude("nvs.h");
    @cInclude("nvs_flash.h");
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
    arena: std.heap.ArenaAllocator,

    config: *Config,
    bmi: Bmi,
    tacho: Tacho,
    netServer: NetServerT,

    state: *ControllerState,

    selfDrive: SelfDrive,
    userDrive: UserDrive,
    mapTrack: MapTrack,
    stop: Stop,

    initTime: i64,
    track: ?Track,

    pub fn init(allocator: std.mem.Allocator, config: *Config, bmi: Bmi, tacho: Tacho, netServer: NetServerT) !Self {
        return .{
            .allocator = allocator,
            .arena = std.heap.ArenaAllocator.init(allocator),

            .config = config,
            .bmi = bmi,
            .tacho = tacho,
            .netServer = netServer,

            .state = undefined,

            .selfDrive = SelfDrive.init(),
            .userDrive = UserDrive.init(),
            .mapTrack = MapTrack.init(),
            .stop = Stop.init(),

            .initTime = @divTrunc(utilsZig.timestampMicros(), 1000),
            .track = null,
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
            _ = self.arena.reset(.{ .retain_with_limit = 1000});
            rtos.rtosVTaskDelayUntil(&lastWake, rtos.rtosMillisToTicks(10));
        }
    }

    fn step(self: *Self) !void {
        try self.bmi.update();
        try self.tacho.update();
        try self.state.step(self);

        const time: f32 = @floatFromInt(@divTrunc(utilsZig.timestampMicros(), 1000) - self.initTime);
        const measurement: clientContract.Measurement = .{
            .time = time / 1_000.0,
            .heading = self.bmi.heading,
            .accelerationX = self.bmi.prevAccel.x,
            .accelerationY = self.bmi.prevAccel.y,
            .accelerationZ = self.bmi.prevAccel.z,
            .velocity = self.tacho.velocity,
            .distance = self.tacho.distance,
        };
        try self.netServer.send(clientContract.Measurement, measurement);
    }

    fn toMessage(comptime T: type, arenaAllocator: std.mem.Allocator, fieldName: []const u8, value: T) ![]u8 {
        const typeInfo = @typeInfo(T);
        const buf = try std.fmt.allocPrintSentinel(arenaAllocator, "{s}", .{fieldName}, 0);
        if (typeInfo == .@"float" or typeInfo == .@"int") {
            const length: usize = @intCast(c.snprintf(null, 0, "%s = %f", buf.ptr, value));
            var buffer = try arenaAllocator.alloc(u8, length);
            _ = c.snprintf(buffer.ptr, buffer.len, "%s = %f", buf.ptr, value);
            return buffer[0..length];
        } else {
            return error.NotSupportedDataTypeConvertingToString;
        }
    }

    pub fn handleConfigCommands(self: *Self, configCommands: @typeInfo(configMod.configCommand()).@"struct".fields[0].type) !void {
        const tagName = @tagName(configCommands);
        const typeInfo = @typeInfo(Config);
        if (std.mem.eql(u8, "get", tagName[0..3])) {
            inline for (typeInfo.@"struct".fields) |field| {
                const upperFirst: [1]u8 = comptime .{ std.ascii.toUpper(field.name[0]) };
                const getterName = "get" ++ upperFirst ++ field.name[1..];
                if (std.mem.eql(u8, tagName, getterName)) {
                    const log: clientContract.Log = .{
                        .level = clientContract.LogLevel.info,
                        .message = try toMessage(field.type, self.arena.allocator(), field.name, @field(self.config, field.name)),
                    };
                    try self.netServer.send(clientContract.Log, log);
                    return;
                }
            }
            return error.UnknownConfigField;
        } else if (std.mem.eql(u8, "set", tagName[0..3])) {
            inline for (typeInfo.@"struct".fields) |field| {
                const upperFirst: [1]u8 = comptime .{ std.ascii.toUpper(field.name[0]) };
                const setterName = "set" ++ upperFirst ++ field.name[1..];
                if (std.mem.eql(u8, tagName, setterName)) {
                    @field(self.config, field.name) = @field(@field(configCommands, setterName), field.name);
                    break;
                }
                return error.UnknownConfigField;
            }
        } else {
            @panic("config command has to start with \"set\" or \"get\".");
        }
    }


    pub fn handleCommand(self: *Self, command: serverContract.command) !void {
        switch (command) {
            .setWifi => |s| {
                var nvsHandle: esp.nvs_handle_t = undefined;
                const nvs_err = esp.nvs_open("storage", esp.NVS_READWRITE, &nvsHandle);
                if (nvs_err != esp.ESP_OK) {
                    utils.espLog(esp.ESP_LOG_ERROR, tag, "Error opening flash memory handle: %s", esp.esp_err_to_name(nvs_err));
                    @panic("Error while opening handle for flash memory in uart console.");
                }
                defer esp.nvs_close(nvsHandle);
                const nullTerminatedSsid = try std.fmt.allocPrintSentinel(self.arena.allocator(), "{s}", .{s.ssid}, 0);
                const nullTerminatedPassword = try std.fmt.allocPrintSentinel(self.arena.allocator(), "{s}", .{s.password}, 0);

                var err = esp.nvs_set_str(nvsHandle, "ssid", nullTerminatedSsid);
                if (err != esp.ESP_OK) {
                    utils.espLog(esp.ESP_LOG_ERROR, tag, "Error setting ssid: %s", esp.esp_err_to_name(err));
                    err = esp.nvs_set_str(nvsHandle, "password", nullTerminatedPassword);
                    if (err != esp.ESP_OK) {
                        utils.espLog(esp.ESP_LOG_ERROR, tag, "Error setting password: %s", esp.esp_err_to_name(err));
                        err = esp.nvs_commit(nvsHandle);
                        if (err != esp.ESP_OK) {
                            utils.espLog(esp.ESP_LOG_ERROR, tag, "Error commiting ssid and password to flash memory: %s", esp.esp_err_to_name(err));
                        }
                    }
                }
                self.allocator.free(s.ssid);
                self.allocator.free(s.password);
            },
            .setMode => |s| {
                if (std.mem.eql(u8, s.mode, "stop")) {
                    try self.changeState(&self.stop.controllerState);
                } else if (std.mem.eql(u8, s.mode, "selfdrive")) {
                    try self.changeState(&self.selfDrive.controllerState);
                } else if (std.mem.eql(u8, s.mode, "userdrive")) {
                    try self.changeState(&self.userDrive.controllerState);
                } else if (std.mem.eql(u8, s.mode, "maptrack")) {
                    try self.changeState(&self.mapTrack.controllerState);
                } else {
                    const buffer = try std.fmt.allocPrintSentinel(self.arena.allocator(), "{s}", .{s.mode}, 0);
                    utils.espLog(esp.ESP_LOG_WARN, tag, "Mode \"%s\"doesn't exist", buffer.ptr);
                }
                self.allocator.free(s.mode);
            },
            .restart => |_| {
                return error.RestartCommand;
            },
            .config => |configCommand| {
                switch (configCommand.configCommands) {
                    else => {
                        try self.handleConfigCommands(configCommand.configCommands);
                    },
                }
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
