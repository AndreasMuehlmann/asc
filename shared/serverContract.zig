const CommandsEnum = enum {
    setWifi,
    setSpeed,
    setMode,
    restart,
    endMapping,
};

pub const command = union(CommandsEnum) {
    setWifi: setWifi,
    setSpeed: setSpeed,
    setMode: setMode,
    restart: restart,
    endMapping: endMapping,
};


const setWifi = struct {
    ssid: []const u8,
    password: []const u8,
};

const setSpeed = struct {
    speed: f32,
};

const setMode = struct {
    mode: []const u8,
};

const restart = struct {};
const endMapping = struct {};

pub const ServerContractEnum = enum(u8) {
    command,
};

pub const ServerContract = union(ServerContractEnum) {
    command: command,
};

