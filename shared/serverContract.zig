const configMod = @import("config");

pub const CommandsEnum = enum(u8) {
    setWifi,
    setSpeed,
    setMode,
    restart,
    endMapping,
    config,
};

pub const command = union(CommandsEnum) {
    setWifi: setWifi,
    setSpeed: setSpeed,
    setMode: setMode,
    restart: restart,
    endMapping: endMapping,
    config: configMod.configCommand(),
};

pub const setWifi = struct {
    ssid: []const u8,
    password: []const u8,
};

pub const setSpeed = struct {
    speed: f32,
};

pub const setMode = struct {
    mode: []const u8,
};

pub const restart = struct {};
pub const endMapping = struct {};

pub const ServerContractEnum = enum(u8) {
    command,
};

pub const ServerContract = union(ServerContractEnum) {
    command: command,
};
