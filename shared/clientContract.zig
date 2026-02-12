pub const Measurement = struct {
    time: f32,
    heading: f32,
    accelerationX: f32,
    accelerationY: f32,
    accelerationZ: f32,
    distance: f32,
    velocity: f32,
};

pub const TrackPoint = struct {
    distance: f32,
    heading: f32,
};

pub const LogLevel = enum(u8) {
    info,
    warning,
    err,
};

pub const Log = struct {
    level: LogLevel,
    message: []const u8,
};

pub const ClientContractEnum = enum(u8) {
    measurement,
    trackPoint,
    log,
};

pub const ClientContract = union(ClientContractEnum) {
    measurement: Measurement,
    trackPoint: TrackPoint,
    log: Log,
};
