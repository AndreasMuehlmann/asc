pub const Measurement = struct {
    time: f32,
    heading: f32,
    accelerationX: f32,
    accelerationY: f32,
    accelerationZ: f32,
};

pub const ClientContractEnum = enum(u8) {
    measurement,
};

pub const ClientContract = union(ClientContractEnum) {
    measurement: Measurement,
};
