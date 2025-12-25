pub const Measurement = struct {
    time: f32,
    heading: f32,
    accelerationX: f32,
    accelerationY: f32,
    accelerationZ: f32,
};

pub const TrackPoint = struct {
    distance: f32,
    heading: f32,
};

pub const ClientContractEnum = enum(u8) {
    measurement,
    trackPoint,
};

pub const ClientContract = union(ClientContractEnum) {
    measurement: Measurement,
    trackPoint: TrackPoint,
};
