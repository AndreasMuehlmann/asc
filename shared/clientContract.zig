pub const TrackPoint = @import("track").TrackPoint;

pub const Measurement = struct {
    time: f32,
    heading: f32,
    accelerationX: f32,
    accelerationY: f32,
    accelerationZ: f32,
    distance: f32,
    velocity: f32,
};

pub const LogLevel = enum(u8) {
    debug,
    info,
    warning,
    err,
};

pub const Log = struct {
    level: LogLevel,
    message: []const u8,
};

pub const CommandsEnum = enum(u8) {
    endMapping,
    resetMapping,
};


pub const command = union(CommandsEnum) {
    endMapping: endMapping,
    resetMapping: resetMapping,
};

pub const resetMapping = struct {};
pub const endMapping = struct {};

pub const CarTrackPoint = struct {
    distance: f32,   
    heading: f32,
};

pub const ClientContractEnum = enum(u8) {
    measurement,
    trackPoint,
    carTrackPoint,
    log,
    command,
};

pub const ClientContract = union(ClientContractEnum) {
    measurement: Measurement,
    trackPoint: TrackPoint,
    carTrackPoint: CarTrackPoint,
    log: Log,
    command: command,
};
