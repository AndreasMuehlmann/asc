const CommandsEnum = enum {
    set,
    restart,
};

pub const command = union(CommandsEnum) {
    set: set,
    restart: restart,
};

const restart = struct {};

const set = struct {
    ssid: []const u8,
    password: []const u8,
};

pub const ServerContractEnum = enum(u8) {
    command,
};

pub const ServerContract = union(ServerContractEnum) {
    command: command,
};

