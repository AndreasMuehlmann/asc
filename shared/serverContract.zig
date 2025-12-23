const CommandsEnum = enum {
    set,
    restart,
    setSpeed,
};

pub const command = union(CommandsEnum) {
    set: set,
    restart: restart,
    setSpeed: setSpeed,
};

const restart = struct {};


const set = struct {
    ssid: []const u8,
    password: []const u8,
};

const setSpeed = struct {
    speed: f32,
};

pub const ServerContractEnum = enum(u8) {
    command,
};

pub const ServerContract = union(ServerContractEnum) {
    command: command,
};

