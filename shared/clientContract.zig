pub const Orientation = struct {
    time: i64,
    heading: f32,
    roll: f32,
    pitch: f32,
};

pub const ClientContractEnum = enum(u8) {
    orientation,
};

pub const ClientContract = union(ClientContractEnum) {
    orientation: Orientation,
};
